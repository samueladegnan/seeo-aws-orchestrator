# frozen_string_literal: true

class AuditLogService
  class << self
    def record(action:, target:, details: {})
      if SeeoConfig.mock_aws?
        log_to_rails(action, target, details)
        return
      end

      client.put_item(
        table_name: table_name,
        item: item_for(action, target, details)
      )
    rescue Aws::DynamoDB::Errors::ServiceError => e
      Rails.logger.warn "[AuditLog] Failed to write #{action}: #{e.message}"
    end

    private

    def log_to_rails(action, target, details)
      actor = Current.user&.email || 'anonymous'
      Rails.logger.info "[AuditLog] #{action} target=#{target} actor=#{actor} details=#{details.to_json}"
    end

    def client
      @client ||= Aws::DynamoDB::Client.new(region: SeeoConfig.aws_region)
    end

    def table_name
      ENV.fetch('SEEO_AUDIT_LOG_TABLE', 'seeo-audit-logs')
    end

    def item_for(action, target, details)
      {
        'id' => SecureRandom.uuid,
        'timestamp' => Time.current.utc.iso8601,
        'actor' => Current.user&.email || 'anonymous',
        'team_id' => Current.team&.id&.to_s || 'service',
        'action' => action,
        'target' => target,
        'details' => details.to_json,
        'user_agent' => Thread.current[:request_user_agent]
      }
    end
  end
end
