# frozen_string_literal: true

class EnvironmentsController < ApplicationController
  before_action :authorize_action!
  before_action :set_project, only: %i[create]

  def index
    environments = cloud_service.list_environments(params[:status])
    render json: {
      environments: environments.map(&:to_summary),
      cost: CostTrackingService.summary(environments)
    }
  end

  def show
    environment = cloud_service.refresh_environment_state(params[:id])
    if environment
      render json: environment.to_h
    else
      render json: { error: "Environment #{params[:id]} not found" }, status: :not_found
    end
  rescue CloudAdapter::UnsupportedProviderError => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  def create
    environment = create_environment
    status = environment.reused ? :ok : :created
    render json: environment.to_h, status: status
  rescue PolicyService::PolicyViolation, CloudAdapter::UnsupportedProviderError => e
    render json: { error: e.message }, status: :unprocessable_content
  rescue ActionController::ParameterMissing
    render json: { error: 'project_name and ttl_minutes are required' }, status: :unprocessable_content
  rescue StandardError => e
    Rails.logger.error "[EnvironmentsController#create] #{e.class}: #{e.message}"
    render json: { error: 'Failed to create environment' }, status: :internal_server_error
  end

  def destroy
    environment = cloud_service.terminate_environment(params[:id])

    AuditLogService.record(
      action: 'environment.destroy',
      target: environment.id,
      details: environment.to_h
    )

    render json: environment.to_h
  rescue ArgumentError
    render json: { error: "Environment #{params[:id]} not found" }, status: :not_found
  rescue CloudAdapter::UnsupportedProviderError => e
    render json: { error: e.message }, status: :unprocessable_content
  rescue StandardError => e
    Rails.logger.error "[EnvironmentsController#destroy] #{e.class}: #{e.message}"
    render json: { error: 'Failed to terminate environment' }, status: :internal_server_error
  end

  def refresh
    environment = cloud_service.refresh_environment_state(params[:id])
    if environment
      render json: environment.to_h
    else
      render json: { error: "Environment #{params[:id]} not found" }, status: :not_found
    end
  rescue CloudAdapter::UnsupportedProviderError => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  private

  def create_environment
    project_name = @project&.name || environment_params.require(:project_name)
    ttl_minutes = environment_params.require(:ttl_minutes).to_i
    requested_compute = environment_params[:compute_tier].presence || environment_params[:instance_type].presence || 'small'
    provider = environment_params[:provider].presence || SeeoConfig.default_provider
    options = build_create_options.merge(provider: provider)

    service = CloudService.for(provider: provider)
    validate_create_policy!(service, project_name, ttl_minutes, provider, requested_compute, options)
    environment = service.create_environment(@project || project_name, ttl_minutes, requested_compute, options)

    record_create_audit(environment)
    environment
  end

  def record_create_audit(environment)
    return if environment.reused

    AuditLogService.record(
      action: 'environment.create',
      target: environment.id,
      details: environment.to_h
    )
  end

  def authorize_action!
    allowed = case action_name
              when 'index', 'show', 'refresh'
                Current.user&.viewer?
              when 'create', 'destroy'
                Current.user&.operator?
              end

    render(json: { error: 'Forbidden' }, status: :forbidden) unless allowed
  end

  def set_project
    project_name = environment_params.require(:project_name)

    @project = Project.find_by!(slug: project_name, team: Current.team) if Current.team
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Project #{environment_params[:project_name]} not found" }, status: :not_found
  end

  def environment_params
    @environment_params ||= params.permit(
      :project_name, :provider, :ttl_minutes, :compute_tier, :instance_type, :region, :volume_size,
      :storage_tier, :volume_type, :notes, :ssh_key_name, tags: {}
    )
  end

  def cloud_service
    @cloud_service ||= CloudService.for
  end

  def build_create_options
    {
      region: environment_params[:region],
      volume_size: environment_params[:volume_size]&.to_i,
      storage_tier: environment_params[:storage_tier].presence || legacy_storage_tier(environment_params[:volume_type]),
      tags: environment_params[:tags],
      notes: environment_params[:notes],
      ssh_key_name: environment_params[:ssh_key_name],
      idempotency_key: request.headers['X-Idempotency-Key'].presence
    }
  end

  def validate_create_policy!(service, project_name, ttl_minutes, provider, requested_compute, options)
    PolicyService.check_provision!(
      project_name: project_name,
      ttl_minutes: ttl_minutes,
      provider: provider,
      compute_tier: normalize_compute_tier(requested_compute),
      region: options[:region],
      volume_size: options[:volume_size],
      storage_tier: options[:storage_tier],
      active_environment_count: service.active_environment_count,
      team: Current.team
    )
  end

  def normalize_compute_tier(value)
    return value.to_s if CloudProvider::TIERS.include?(value.to_s)

    { 't3.micro' => 'small', 't3.small' => 'medium', 't3.medium' => 'large', 'm6i.large' => 'large',
      'm5.large' => 'large', 'm5.xlarge' => 'large', 'c5.large' => 'large' }.fetch(value.to_s, 'small')
  end

  def legacy_storage_tier(value)
    { 'gp3' => 'balanced', 'io2' => 'performance', 'st1' => 'throughput' }.fetch(value.to_s, 'balanced')
  end
end
