# frozen_string_literal: true

require 'digest'

class MockAwsService
  # In-memory store for the public demo and local development.
  STORE = [] # rubocop:disable Style/MutableConstant
  MUTEX = Mutex.new

  class << self
    def reset!
      MUTEX.synchronize { STORE.clear }
    end
  end

  def create_environment(project, ttl_minutes, instance_type = nil, options = {})
    fingerprint = request_fingerprint(project, ttl_minutes, instance_type, options)
    environment = nil
    reused = false

    MUTEX.synchronize do
      existing = find_by_idempotency_locked(options[:idempotency_key])
      if existing
        if existing.request_fingerprint != fingerprint
          raise ArgumentError, 'Idempotency key was already used with different request parameters'
        end

        existing.reused = true
        environment = existing
        reused = true
      else
        PolicyService.check_concurrency!(active_environment_count_locked)
        environment = build_environment(project, ttl_minutes, instance_type, options)
        STORE << environment
      end
    end

    return environment if reused

    EnvironmentChannel.broadcast(environment)
    schedule_ready_transition(environment)
    environment
  end

  def get_environment(environment_id)
    MUTEX.synchronize do
      STORE.find { |env| env.id == environment_id && owned_by_current_context?(env) }
    end
  end

  def list_environments(status_filter = nil)
    environments = MUTEX.synchronize { STORE.select { |env| owned_by_current_context?(env) }.dup }
    environments = environments.select { |env| env.status == status_filter } if status_filter
    environments
  end

  def active_environment_count
    MUTEX.synchronize { active_environment_count_locked }
  end

  def list_expired_environments
    raise AuthorizationService::AuthenticationError, 'Cleanup context required' unless Current.internal_cleanup

    MUTEX.synchronize do
      STORE.select { |env| env.expired? && %w[pending provisioning ready error terminating].include?(env.status) }
    end
  end

  def refresh_environment_state(environment_id)
    environment = get_environment(environment_id)
    return nil unless environment
    return environment if environment.status == 'terminated'

    environment
  end

  def terminate_environment(environment_id)
    MUTEX.synchronize do
      original = STORE.find { |env| env.id == environment_id && owned_by_current_context?(env) }
      raise ArgumentError, "Environment #{environment_id} not found" unless original

      delete_environment(original)
    end
  end

  # The TTL monitor is trusted to clean up across demo sessions.
  def force_terminate_environment(environment_id)
    raise AuthorizationService::AuthenticationError, 'Cleanup context required' unless Current.internal_cleanup

    MUTEX.synchronize do
      original = STORE.find { |env| env.id == environment_id }
      raise ArgumentError, "Environment #{environment_id} not found" unless original

      delete_environment(original)
    end
  end

  private

  def schedule_ready_transition(environment)
    delay = SeeoConfig.mock_provisioning_delay_seconds
    if delay <= 0
      transition_to_ready(environment)
      return
    end

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

  def build_environment(project, ttl_minutes, instance_type, options)
    project_name = project.is_a?(Project) ? project.name : project
    project_id = project.is_a?(Project) ? project.id : nil
    environment_id = generate_id(project_name)
    created_at = Time.current.utc
    expires_at = created_at + ttl_minutes.to_i.minutes

    Environment.new(
      id: environment_id,
      project_name: project_name,
      project_id: project_id,
      team_id: Current.team&.id,
      owner_user_id: Current.user&.id,
      status: 'provisioning',
      created_at: created_at,
      expires_at: expires_at,
      instance_id: mock_instance_id,
      public_ip: mock_public_ip,
      private_ip: mock_private_ip,
      volume_id: "vol-mock#{SecureRandom.hex(4)}",
      ttl_minutes: ttl_minutes.to_i,
      instance_type: instance_type || SeeoConfig.ec2_instance_type,
      session_id: Current.session_id.presence || 'default',
      idempotency_key: options[:idempotency_key],
      request_fingerprint: request_fingerprint(project_name, ttl_minutes, instance_type, options),
      region: resolve_option(options, :region, 'us-east-1'),
      volume_size: resolve_option(options, :volume_size, 10),
      volume_type: resolve_option(options, :volume_type, 'gp3'),
      tags: stringify_tags(options[:tags]),
      notes: resolve_option(options, :notes, ''),
      ssh_key_name: resolve_option(options, :ssh_key_name, 'seeo-demo-key')
    )
  end

  def request_fingerprint(project, ttl_minutes, instance_type, options)
    Digest::SHA256.hexdigest({
      project_name: project.is_a?(Project) ? project.name : project,
      ttl_minutes: ttl_minutes.to_i,
      instance_type: instance_type || SeeoConfig.ec2_instance_type,
      region: options[:region],
      volume_size: options[:volume_size],
      volume_type: options[:volume_type],
      tags: options[:tags],
      notes: options[:notes],
      ssh_key_name: options[:ssh_key_name]
    }.to_json)
  end

  def find_by_idempotency_locked(key)
    return nil if key.blank?

    STORE.find do |env|
      env.idempotency_key == key && owned_by_current_context?(env) && env.status != 'terminated'
    end
  end

  def active_environment_count_locked
    STORE.count { |env| owned_by_current_context?(env) && env.status != 'terminated' }
  end

  def owned_by_current_context?(environment)
    environment.owned_by?(team_id: Current.team&.id, session_id: Current.session_id)
  end

  def resolve_option(options, key, fallback)
    options[key].presence || fallback
  end

  def mock_instance_id
    "i-mock#{SecureRandom.hex(4)}"
  end

  def mock_public_ip
    "203.0.113.#{rand(1..254)}"
  end

  def mock_private_ip
    "10.0.#{rand(0..255)}.#{rand(1..254)}"
  end

  def stringify_tags(tags)
    return {} unless tags.is_a?(Hash)

    tags.each_with_object({}) { |(k, v), memo| memo[k.to_s] = v.to_s }
  end

  def delete_environment(original)
    environment = Environment.new(
      id: original.id,
      project_name: original.project_name,
      project_id: original.project_id,
      team_id: original.team_id,
      owner_user_id: original.owner_user_id,
      status: 'terminated',
      created_at: original.created_at,
      expires_at: original.expires_at,
      instance_id: original.instance_id,
      public_ip: nil,
      private_ip: original.private_ip,
      volume_id: original.volume_id,
      ttl_minutes: original.ttl_minutes,
      instance_type: original.instance_type,
      session_id: original.session_id,
      idempotency_key: original.idempotency_key,
      request_fingerprint: original.request_fingerprint,
      region: original.region,
      volume_size: original.volume_size,
      volume_type: original.volume_type,
      tags: original.tags,
      notes: original.notes,
      ssh_key_name: original.ssh_key_name
    )
    STORE.delete_if { |env| env.id == environment.id }
    EnvironmentChannel.broadcast(environment)
    environment
  end

  def generate_id(project_name)
    timestamp = Time.current.utc.strftime('%Y%m%d%H%M%S')
    unique = SecureRandom.hex(4)
    "#{project_name}-#{timestamp}-#{unique}"
  end
end
