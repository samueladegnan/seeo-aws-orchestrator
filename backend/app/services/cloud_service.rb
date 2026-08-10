# frozen_string_literal: true

class CloudService
  def self.for(provider: nil)
    new(provider: provider)
  end

  def initialize(provider: nil)
    @provider = provider.presence
  end

  def create_environment(project, ttl_minutes, compute_tier = nil, options = {})
    adapter_for(options[:provider].presence || @provider).create_environment(project, ttl_minutes, compute_tier,
                                                                             options)
  end

  def list_environments(status_filter = nil)
    adapters_for_read.flat_map { |adapter| adapter.list_environments(status_filter) }
  end

  def active_environment_count
    adapters_for_read.sum(&:active_environment_count)
  end

  def get_environment(environment_id)
    adapters_for_read.lazy.map { |adapter| adapter.get_environment(environment_id) }.find(&:present?)
  end

  def refresh_environment_state(environment_id)
    adapter_for_environment(environment_id).refresh_environment_state(environment_id)
  end

  def terminate_environment(environment_id)
    adapter_for_environment(environment_id).terminate_environment(environment_id)
  end

  def list_expired_environments
    adapters_for_cleanup.flat_map(&:list_expired_environments)
  end

  def force_terminate_environment(environment_id)
    adapter_for_environment(environment_id).force_terminate_environment(environment_id)
  end

  private

  def adapter_for(provider)
    CloudAdapter.for(provider: provider, mock: SeeoConfig.mock_mode?)
  end

  def adapters_for_read
    providers = @provider ? [@provider] : SeeoConfig.allowed_providers
    providers.map { |provider| adapter_for(provider) }
  end

  def adapters_for_cleanup
    adapters_for_read
  end

  def adapter_for_environment(environment_id)
    if defined?(EnvironmentRecord) && (record = EnvironmentRecord.find_by(id: environment_id))
      return adapter_for(record.provider)
    end

    adapters_for_read.find do |adapter|
      adapter.get_environment(environment_id)
    end || adapter_for(@provider || SeeoConfig.default_provider)
  end
end
