# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_team, :current_role, :current_session_id, :current_service_account

    def connect
      authenticate_connection!
    rescue CableTokenService::InvalidToken, AuthorizationService::AuthenticationError
      reject_unauthorized_connection
    end

    private

    def authenticate_connection!
      payload = CableTokenService.verify!(request.params['token'])
      assign_connection_identity(payload)
      validate_connection_identity!(payload)
    end

    def assign_connection_identity(payload)
      self.current_session_id = payload['session_id'].presence || 'default'
      self.current_role = payload['role']
      self.current_service_account = payload['service_account'] == true
      self.current_team = find_team(payload)
      self.current_user = find_user(payload)
    end

    def find_team(payload)
      return if payload['team_id'].blank?

      Team.find_by(id: payload['team_id'])
    end

    def find_user(payload)
      return User.new(email: payload['email'] || 'service@seeo.local', role: 'admin') if current_service_account
      return if payload['email'].blank?

      User.find_by(email: payload['email'])
    end

    def validate_connection_identity!(payload)
      raise AuthorizationService::AuthenticationError, 'Unknown channel identity' if current_user.blank?
      if payload['team_id'].present? && current_team.blank?
        raise AuthorizationService::AuthenticationError, 'Unknown tenant'
      end
      return unless current_team && !current_service_account
      return if current_user.team_id == current_team.id

      raise AuthorizationService::AuthenticationError, 'Tenant identity mismatch'
    end
  end
end
