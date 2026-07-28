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
    project_name = @project&.name || environment_params.require(:project_name)
    ttl_minutes = environment_params.require(:ttl_minutes).to_i
    instance_type = environment_params[:instance_type] || SeeoConfig.ec2_instance_type
    options = {
      region: environment_params[:region],
      volume_size: environment_params[:volume_size]&.to_i,
      volume_type: environment_params[:volume_type],
      tags: environment_params[:tags],
      notes: environment_params[:notes],
      ssh_key_name: environment_params[:ssh_key_name]
    }

    PolicyService.check_provision!(
      project_name: project_name,
      ttl_minutes: ttl_minutes,
      instance_type: instance_type,
      region: options[:region],
      volume_size: options[:volume_size],
      volume_type: options[:volume_type],
      team: Current.team
    )

    environment = aws_service.create_environment(@project || project_name, ttl_minutes, instance_type, options)

    AuditLogService.record(
      action: 'environment.create',
      target: environment.id,
      details: environment.to_h
    )

    render json: environment.to_h, status: :created
  rescue PolicyService::PolicyViolation => e
    render json: { error: e.message }, status: :unprocessable_content
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
  rescue ArgumentError => e
    render json: { error: e.message }, status: :not_found
  rescue StandardError => e
    render json: { error: "Failed to terminate environment: #{e.message}" }, status: :internal_server_error
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
    params.permit(:project_name, :ttl_minutes, :instance_type, :region, :volume_size,
                    :volume_type, :notes, :ssh_key_name, tags: {})
  end

  def aws_service
    @aws_service ||= SeeoConfig.mock_aws? ? MockAwsService.new : AwsService.new
  end
end
