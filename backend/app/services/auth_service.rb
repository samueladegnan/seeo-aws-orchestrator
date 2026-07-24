# frozen_string_literal: true

class AuthService
  class << self
    def verify_api_key(provided_key)
      return false if provided_key.blank?

      ActiveSupport::SecurityUtils.secure_compare(provided_key.strip, SeeoConfig.api_key.strip)
    end
  end
end
