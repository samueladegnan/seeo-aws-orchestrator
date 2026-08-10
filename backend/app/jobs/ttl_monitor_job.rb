# frozen_string_literal: true

class TtlMonitorJob < ApplicationJob
  def perform
    Current.internal_cleanup = true
    Rails.logger.info '[TTL] Scanning all configured cloud providers for expired environments...'

    SeeoConfig.allowed_providers.each do |provider|
      service = CloudService.for(provider: provider)
      service.list_expired_environments.each do |environment|
        Rails.logger.info "[TTL] #{provider} environment #{environment.id} expired; terminating..."
        begin
          service.force_terminate_environment(environment.id)
        rescue StandardError => e
          Rails.logger.error "[TTL] Failed to terminate #{environment.id}: #{e.message}"
        end
      end
    rescue CloudAdapter::UnsupportedProviderError => e
      Rails.logger.warn "[TTL] #{provider} is not configured: #{e.message}"
    end
  ensure
    Current.reset
  end
end
