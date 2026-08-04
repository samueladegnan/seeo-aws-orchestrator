# frozen_string_literal: true

class TtlMonitorJob < ApplicationJob
  def perform
    Current.internal_cleanup = true
    Rails.logger.info '[TTL] Scanning for expired environments...'
    expired = service.list_expired_environments
    expired.each do |environment|
      Rails.logger.info "[TTL] Environment #{environment.id} expired; terminating..."
      begin
        service.force_terminate_environment(environment.id)
      rescue StandardError => e
        Rails.logger.error "[TTL] Failed to terminate #{environment.id}: #{e.message}"
      end
    end
  ensure
    Current.reset
  end

  private

  def service
    SeeoConfig.mock_aws? ? MockAwsService.new : AwsService.new
  end
end
