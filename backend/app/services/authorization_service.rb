# frozen_string_literal: true

require 'jwt'

class AuthorizationService
  class AuthenticationError < StandardError; end

  DEFAULT_JWT_ALGORITHM = 'HS256'

  class << self
    def authenticate_api_key!(api_key)
      raise AuthenticationError, 'Invalid or missing API key' unless AuthService.verify_api_key(api_key)

      Current.user = User.new(email: 'service@seeo.local', role: 'admin')
      Current.team = nil
      Current.role = 'admin'
    end

    def authenticate_token!(token)
      payload = decode_jwt(token)
      user = User.find_by!(email: payload['email'])

      Current.user = user
      Current.team = user.team
      Current.role = user.role
    rescue ActiveRecord::RecordNotFound, JWT::DecodeError => e
      raise AuthenticationError, "Invalid tenant token: #{e.message}"
    end

    def issue_token(user)
      JWT.encode({ email: user.email, exp: 24.hours.from_now.to_i }, jwt_secret, DEFAULT_JWT_ALGORITHM)
    end

    def current_summary
      {
        user_id: Current.user&.id,
        team_id: Current.team&.id,
        role: Current.role
      }
    end

    private

    def decode_jwt(token)
      JWT.decode(token, jwt_secret, true, { algorithm: DEFAULT_JWT_ALGORITHM }).first
    end

    def jwt_secret
      ENV.fetch('SEEO_JWT_SECRET') do
        raise AuthenticationError, 'SEEO_JWT_SECRET must be set in production' if Rails.env.production?

        SeeoConfig.api_key
      end
    end

    # Intentionally left empty; service account is now a transient User object.
  end
end
