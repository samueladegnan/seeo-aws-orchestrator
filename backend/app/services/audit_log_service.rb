# frozen_string_literal: true

class AuditLogService
  class << self
    def record(action:, target:, details: {})
      AuditEvent.create!(
        action: action,
        target: target,
        actor: Current.user&.email || 'anonymous',
        team_id: Current.team&.id,
        details: details,
        user_agent: Thread.current[:request_user_agent]
      )
    rescue ActiveRecord::StatementInvalid, ActiveRecord::RecordInvalid => e
      Rails.logger.warn "[AuditLog] Failed to write #{action}: #{e.message}"
      log_to_rails(action, target, details)
    end

    private

    def log_to_rails(action, target, details)
      actor = Current.user&.email || 'anonymous'
      Rails.logger.info "[AuditLog] #{action} target=#{target} actor=#{actor} details=#{details.to_json}"
    end
  end
end
