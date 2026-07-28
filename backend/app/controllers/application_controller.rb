# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :authenticate_request!
  around_action :set_current_context

  private

  def authenticate_request!
    if request.headers['Authorization'].present?
      token = request.headers['Authorization'].to_s[/Bearer (.+)/, 1]
      raise AuthorizationService::AuthenticationError, 'Invalid token format' if token.blank?

      AuthorizationService.authenticate_token!(token)
    elsif request.headers['X-API-Key'].present?
      AuthorizationService.authenticate_api_key!(request.headers['X-API-Key'])
    else
      raise AuthorizationService::AuthenticationError, 'Missing credentials'
    end
  rescue AuthorizationService::AuthenticationError => e
    render json: { error: e.message }, status: :unauthorized
  end

  def set_current_context
    Thread.current[:request_user_agent] = request.user_agent
    Current.session_id = request.headers['X-Session-ID'].presence || 'default'
    yield
  ensure
    Current.reset
    Thread.current[:request_user_agent] = nil
  end
end
