# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :authenticate_request!

  private

  def authenticate_request!
    api_key = request.headers["X-API-Key"]
    return if AuthService.verify_api_key(api_key)

    render json: { error: "Invalid or missing API key" }, status: :unauthorized
  end
end
