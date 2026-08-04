# frozen_string_literal: true

class EnvironmentsController < ApplicationController
  before_action :authorize_action!
  before_action :set_project, only: %i[create]

  def index
    environments = aws_service.list_environments(params[:status])
    render json: {
      environments: environments.map(&:to_summary),
      cost: CostTrackingService.summary(environments)
    }
  end

  def show
    environment = aws_service.refresh_environment_state(params[:id])
    if environment
      render json: environment.to_h
    else
      render json: { error: "Environment #{params[:id]} not found" }, status: :not_found
    end
  end

  def create
    environment = create_environment
    status = environment.reused ? :ok : :created
    render json: environment.to_h, status: status
  rescue PolicyService::PolicyViolation => e
    render json: { error: e.message }, status: :unprocessable_content
  rescue ActionController::ParameterMissing
    render json: { error: 'project_name and ttl_minutes are required' }, status: :unprocessable_content
  rescue StandardError => e
    Rails.logger.error "[EnvironmentsController#create] #{e.class}: #{e.message}"
    render json: { error: 'Failed to create environment' }, status: :internal_server_error
  end

  def destroy
    environment = aws_service.terminate_environment(params[:id])

    AuditLogService.record(
      action: 'environment.destroy',
      target: environment.id,
      details: environment.to_h
    )

    render json: environment.to_h
  rescue ArgumentError
    render json: { error: "Environment #{params[:id]} not found" }, status: :not_found
  rescue StandardError => e
    Rails.logger.error "[EnvironmentsController#destroy] #{e.class}: #{e.message}"
    render json: { error: 'Failed to terminate environment' }, status: :internal_server_error
  end

  def refresh
    environment = aws_service.refresh_environment_state(params[:id])
    if environment
      render json: environment.to_h
    else
      render json: { error: "Environment #{params[:id]} not found" }, status: :not_found
    end
  end

  private

  def create_environment
    project_name = @project&.name || environment_params.require(:project_name)
    ttl_minutes = environment_params.require(:ttl_minutes).to_i
    instance_type = environment_params[:instance_type] || SeeoConfig.ec2_instance_type
    options = build_create_options

    validate_create_policy!(project_name, ttl_minutes, instance_type, options)
    environment = aws_service.create_environment(@project || project_name, ttl_minutes, instance_type, options)

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
      :project_name, :ttl_minutes, :instance_type, :region, :volume_size,
      :volume_type, :notes, :ssh_key_name, tags: {}
    )
  end

  def aws_service
    @aws_service ||= SeeoConfig.mock_aws? ? MockAwsService.new : AwsService.new
  end

  def build_create_options
    {
      region: environment_params[:region],
      volume_size: environment_params[:volume_size]&.to_i,
      volume_type: environment_params[:volume_type],
      tags: environment_params[:tags],
      notes: environment_params[:notes],
      ssh_key_name: environment_params[:ssh_key_name],
      idempotency_key: request.headers['X-Idempotency-Key'].presence
    }
  end

  def validate_create_policy!(project_name, ttl_minutes, instance_type, options)
    PolicyService.check_provision!(
      project_name: project_name,
      ttl_minutes: ttl_minutes,
      instance_type: instance_type,
      region: options[:region],
      volume_size: options[:volume_size],
      volume_type: options[:volume_type],
      active_environment_count: aws_service.active_environment_count,
      team: Current.team
    )
  end
end
