# frozen_string_literal: true

class ApplicationController < ActionController::API
  around_action :set_current_context
  before_action :authenticate_request!
  before_action :require_session_token!

  private

  def require_session_token!
    return unless Current.service_account == true
    unless SeeoConfig.mock_aws?
      return render json: { error: 'API-key lifecycle access is limited to mock mode' }, status: :forbidden
    end

    payload = SessionTokenService.verify!(request.headers['X-Session-Token'])
    Current.session_id = payload['session_id']
  rescue SessionTokenService::InvalidToken => e
    render json: { error: e.message }, status: :unauthorized
  end

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
    Current.session_id = 'default'
    yield
  ensure
    Current.reset
    Thread.current[:request_user_agent] = nil
  end
end
