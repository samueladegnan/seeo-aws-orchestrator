# frozen_string_literal: true

require 'digest'
require 'securerandom'

class MockCloudService < CloudAdapter
  STORE = [] # rubocop:disable Style/MutableConstant
  MUTEX = Mutex.new

  class << self
    def reset!
      MUTEX.synchronize { STORE.clear }
    end
  end

  def create_environment(project, ttl_minutes, compute_tier = nil, options = {})
    provider = options[:provider].presence || @provider
    fingerprint = request_fingerprint(project, ttl_minutes, compute_tier, options.merge(provider: provider))
    reused = false

    MUTEX.synchronize do
      existing = find_by_idempotency_locked(options[:idempotency_key], provider)
      if existing
        raise ArgumentError, 'Idempotency key was already used with different request parameters' if existing.request_fingerprint != fingerprint

        existing.reused = true
        environment = existing
        reused = true
      else
        PolicyService.check_concurrency!(active_environment_count_locked)
        environment = build_environment(project, ttl_minutes, compute_tier, options.merge(provider: provider))
        STORE << environment
      end
    end

    return environment if reused

    EnvironmentChannel.broadcast(environment)
    schedule_ready_transition(environment)
    environment
  end

  def get_environment(environment_id)
    MUTEX.synchronize { STORE.find { |env| env.id == environment_id && env.provider == @provider && owned_by_current_context?(env) } }
  end

  def list_environments(status_filter = nil)
    environments = MUTEX.synchronize { STORE.select { |env| env.provider == @provider && owned_by_current_context?(env) }.dup }
    status_filter ? environments.select { |env| env.status == status_filter } : environments
  end

  def active_environment_count
    MUTEX.synchronize { active_environment_count_locked }
  end

  def list_expired_environments
    raise AuthorizationService::AuthenticationError, 'Cleanup context required' unless Current.internal_cleanup

    MUTEX.synchronize { STORE.select { |env| env.expired? && env.provider == @provider && active_status?(env.status) } }
  end

  def refresh_environment_state(environment_id)
    environment = get_environment(environment_id)
    return nil unless environment
    return environment if environment.status == 'terminated'

    environment
  end

  def terminate_environment(environment_id)
    MUTEX.synchronize do
      original = STORE.find { |env| env.id == environment_id && env.provider == @provider && owned_by_current_context?(env) }
      raise ArgumentError, "Environment #{environment_id} not found" unless original

      delete_environment(original)
    end
  end

  def force_terminate_environment(environment_id)
    raise AuthorizationService::AuthenticationError, 'Cleanup context required' unless Current.internal_cleanup

    MUTEX.synchronize do
      original = STORE.find { |env| env.id == environment_id && env.provider == @provider }
      raise ArgumentError, "Environment #{environment_id} not found" unless original

      delete_environment(original)
    end
  end

  private

  def build_environment(project, ttl_minutes, compute_tier, options)
    provider = options[:provider].presence || @provider
    project_name = project.is_a?(Project) ? project.name : project
    project_id = project.is_a?(Project) ? project.id : nil
    region = CloudProvider.region(provider, options[:region])
    storage_tier = options[:storage_tier].presence || legacy_storage_tier(options[:volume_type])
    compute_tier = normalize_compute_tier(compute_tier)
    created_at = Time.current.utc

    Environment.new(
      id: generate_id(project_name),
      project_name: project_name,
      project_id: project_id,
      team_id: Current.team&.id,
      owner_user_id: Current.user&.id,
      provider: provider,
      provider_resource_id: "#{provider}-vm-#{SecureRandom.hex(4)}",
      provider_resource_type: 'virtual_machine',
      status: 'provisioning',
      created_at: created_at,
      expires_at: created_at + ttl_minutes.to_i.minutes,
      instance_id: "#{provider}-vm-#{SecureRandom.hex(4)}",
      public_ip: mock_public_ip,
      private_ip: mock_private_ip,
      volume_id: "#{provider}-disk-#{SecureRandom.hex(4)}",
      ttl_minutes: ttl_minutes.to_i,
      compute_tier: compute_tier,
      instance_type: CloudProvider.compute_shape(provider, compute_tier),
      session_id: Current.session_id.presence || 'default',
      idempotency_key: options[:idempotency_key],
      request_fingerprint: request_fingerprint(project_name, ttl_minutes, compute_tier, options),
      region: region,
      volume_size: options[:volume_size].presence || 10,
      storage_tier: storage_tier,
      volume_type: CloudProvider.storage_shape(provider, storage_tier),
      tags: stringify_tags(options[:tags]),
      notes: options[:notes].presence || '',
      ssh_key_name: options[:ssh_key_name].presence,
      message: "Mock #{CloudProvider.definition(provider)[:short_label]} environment"
    )
  end

  def request_fingerprint(project, ttl_minutes, compute_tier, options)
    Digest::SHA256.hexdigest({
      provider: options[:provider].presence || @provider,
      project_name: project.is_a?(Project) ? project.name : project,
      ttl_minutes: ttl_minutes.to_i,
      compute_tier: normalize_compute_tier(compute_tier),
      region: options[:region],
      volume_size: options[:volume_size],
      storage_tier: options[:storage_tier].presence || legacy_storage_tier(options[:volume_type]),
      tags: options[:tags],
      notes: options[:notes],
      ssh_key_name: options[:ssh_key_name]
    }.to_json)
  end

  def find_by_idempotency_locked(key, provider)
    return nil if key.blank?

    STORE.find { |env| env.idempotency_key == key && env.provider == provider && owned_by_current_context?(env) && env.status != 'terminated' }
  end

  def active_environment_count_locked
    STORE.count { |env| env.provider == @provider && owned_by_current_context?(env) && env.status != 'terminated' }
  end

  def active_status?(status)
    %w[pending provisioning ready error terminating].include?(status)
  end

  def owned_by_current_context?(environment)
    environment.owned_by?(team_id: Current.team&.id, session_id: Current.session_id)
  end

  def schedule_ready_transition(environment)
    delay = SeeoConfig.mock_provisioning_delay_seconds
    return transition_to_ready(environment) if delay <= 0

    Thread.new do
      sleep(delay)
      transition_to_ready(environment)
    end
  end

  def transition_to_ready(environment)
    MUTEX.synchronize do
      stored = STORE.find { |env| env.id == environment.id }
      return unless stored&.status == 'provisioning'

      stored.status = 'ready'
      EnvironmentChannel.broadcast(stored)
    end
  end

  def delete_environment(original)
    original.status = 'terminated'
    original.public_ip = nil
    original.message = 'Environment terminated'
    STORE.delete_if { |env| env.id == original.id }
    EnvironmentChannel.broadcast(original)
    original
  end

  def stringify_tags(tags)
    return {} unless tags.is_a?(Hash)

    tags.each_with_object({}) { |(key, value), memo| memo[key.to_s] = value.to_s }
  end

  def mock_public_ip
    "203.0.113.#{rand(1..254)}"
  end

  def mock_private_ip
    "10.#{rand(0..255)}.#{rand(0..255)}.#{rand(1..254)}"
  end

  def normalize_compute_tier(value)
    return value.to_s if CloudProvider::TIERS.include?(value.to_s)

    { 't3.micro' => 'small', 't3.small' => 'medium', 't3.medium' => 'large' }.fetch(value.to_s, 'small')
  end

  def legacy_storage_tier(value)
    { 'gp3' => 'balanced', 'io2' => 'performance', 'st1' => 'throughput' }.fetch(value.to_s, 'balanced')
  end

  def generate_id(project_name)
    "#{project_name}-#{Time.current.utc.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(4)}"
  end
end
