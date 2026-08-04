# frozen_string_literal: true

class CableTokenService
  PURPOSE = 'seeo-action-cable'
  TTL = 15.minutes

  class InvalidToken < StandardError; end

  class << self
    def issue
      Rails.application.message_verifier(PURPOSE).generate(
        {
          'email' => Current.user&.email,
          'team_id' => Current.team&.id,
          'role' => Current.role,
          'service_account' => Current.service_account == true,
          'session_id' => Current.session_id,
          'issued_at' => Time.current.to_i
        },
        expires_in: TTL
      )
    end

    def verify!(token)
      payload = Rails.application.message_verifier(PURPOSE).verify(token)
      raise InvalidToken, 'Invalid channel token' unless payload.is_a?(Hash)

      payload
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError => e
      raise InvalidToken, "Invalid channel token: #{e.message}"
    end
  end
end
