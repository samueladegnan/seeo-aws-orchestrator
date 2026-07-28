# frozen_string_literal: true

class TtlMonitorJob < ApplicationJob
  def perform
    Rails.logger.info '[TTL] Scanning for expired environments...'
    expired = AwsService.new.list_expired_environments
    expired.each do |environment|
      Rails.logger.info "[TTL] Environment #{environment.id} expired; terminating..."
      begin
        AwsService.new.terminate_environment(environment.id)
      rescue StandardError => e
        Rails.logger.error "[TTL] Failed to terminate #{environment.id}: #{e.message}"
      end
    end
  end
end
