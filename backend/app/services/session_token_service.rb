# frozen_string_literal: true

class SessionTokenService
  PURPOSE = 'seeo-demo-session'
  TTL = 30.days

  class InvalidToken < StandardError; end

  class << self
    def issue
      session_id = SecureRandom.uuid
      token = verifier.generate({ 'session_id' => session_id, 'issued_at' => Time.current.to_i }, expires_in: TTL)
      { token: token, session_id: session_id }
    end

    def verify!(token)
      payload = verifier.verify(token)
      raise InvalidToken, 'Invalid session token' unless payload.is_a?(Hash) && payload['session_id'].present?

      payload
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError => e
      raise InvalidToken, "Invalid session token: #{e.message}"
    end

    private

    def verifier
      Rails.application.message_verifier(PURPOSE)
    end
  end
end
