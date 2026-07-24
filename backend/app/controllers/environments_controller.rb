# frozen_string_literal: true

class EnvironmentsController < ApplicationController
  def index
    environments = AwsService.new.list_environments(params[:status])
    render json: environments.map(&:to_summary)
  end

  def show
    environment = AwsService.new.refresh_environment_state(params[:id])
    if environment
      render json: environment.to_h
    else
      render json: { error: "Environment #{params[:id]} not found" }, status: :not_found
    end
  end

  def create
    aws = AwsService.new
    environment = aws.create_environment(
      params.require(:project_name),
      params.require(:ttl_minutes).to_i,
      params[:instance_type]
    )
    render json: environment.to_h, status: :created
  rescue StandardError => e
    render json: { error: "Failed to create environment: #{e.message}" }, status: :internal_server_error
  end

  def destroy
    environment = AwsService.new.terminate_environment(params[:id])
    render json: environment.to_h
  rescue ArgumentError => e
    render json: { error: e.message }, status: :not_found
  rescue StandardError => e
    render json: { error: "Failed to terminate environment: #{e.message}" }, status: :internal_server_error
  end

  def refresh
    environment = AwsService.new.refresh_environment_state(params[:id])
    if environment
      render json: environment.to_h
    else
      render json: { error: "Environment #{params[:id]} not found" }, status: :not_found
    end
  end
end
