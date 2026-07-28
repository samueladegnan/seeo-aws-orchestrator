# frozen_string_literal: true

class MockAwsService
  # In-memory store so environments persist across requests in dev/test.
  # Production should never use this; SeeoConfig.mock_aws? defaults to false there.
  # Each environment carries the Current.session_id so every demo visitor has their own sandbox.
  STORE = [] # rubocop:disable Style/MutableConstant
  MUTEX = Mutex.new

  class << self
    def reset!
      MUTEX.synchronize { STORE.clear }
    end
  end

  def create_environment(project, ttl_minutes, instance_type = nil, options = {})
    environment = build_environment(project, ttl_minutes, instance_type, options)

    MUTEX.synchronize do
      if session_env_count >= SeeoConfig.mock_env_limit
        raise PolicyService::PolicyViolation, 'Too many demo environments for this session'
      end

      STORE << environment
    end
    EnvironmentChannel.broadcast(environment, environment.session_id)
    schedule_ready_transition(environment)
    environment
  end

  def get_environment(environment_id)
    MUTEX.synchronize { STORE.find { |env| env.id == environment_id && env.session_id == session_key } }
  end

  def list_environments(status_filter = nil)
    environments = MUTEX.synchronize { STORE.select { |env| env.session_id == session_key }.dup }
    environments = environments.select { |env| env.status == status_filter } if status_filter
    environments
  end

  def list_expired_environments
    MUTEX.synchronize do
      STORE.select { |env| env.expired? && %w[pending provisioning ready].include?(env.status) }
    end
  end

  def refresh_environment_state(environment_id)
    environment = get_environment(environment_id)
    return nil unless environment
    return environment if environment.status == 'terminated'

    # In mock mode, refresh is a no-op beyond returning the current state.
    environment
  end

  def terminate_environment(environment_id)
    MUTEX.synchronize do
      original = STORE.find { |env| env.id == environment_id && env.session_id == session_key }
      raise ArgumentError, "Environment #{environment_id} not found" unless original

      delete_environment(original)
    end
  end

  # Used by the TTL monitor to terminate expired environments across all sessions.
  def force_terminate_environment(environment_id)
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
      stored = STORE.find { |env| env.id == environment.id && env.session_id == environment.session_id }
      return unless stored
      return unless stored.status == 'provisioning'

      stored.status = 'ready'
      EnvironmentChannel.broadcast(stored, stored.session_id)
    end
  end

  def build_environment(project, ttl_minutes, instance_type, options)
    project_name = project.is_a?(Project) ? project.name : project
    environment_id = generate_id(project_name)
    created_at = Time.current.utc
    expires_at = created_at + ttl_minutes.to_i.minutes

    Environment.new(
      id: environment_id,
      project_name: project_name,
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
      region: resolve_option(options, :region, 'us-east-1'),
      volume_size: resolve_option(options, :volume_size, 10),
      volume_type: resolve_option(options, :volume_type, 'gp3'),
      tags: stringify_tags(options[:tags]),
      notes: resolve_option(options, :notes, ''),
      ssh_key_name: resolve_option(options, :ssh_key_name, 'seeo-demo-key')
    )
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

  def session_key
    Current.session_id.presence || 'default'
  end

  def session_env_count
    STORE.count { |env| env.session_id == session_key && env.status != 'terminated' }
  end

  def stringify_tags(tags)
    return {} unless tags.is_a?(Hash)

    tags.each_with_object({}) { |(k, v), memo| memo[k.to_s] = v.to_s }
  end

  def delete_environment(original)
    environment = Environment.new(
      id: original.id,
      project_name: original.project_name,
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
      region: original.region,
      volume_size: original.volume_size,
      volume_type: original.volume_type,
      tags: original.tags,
      notes: original.notes,
      ssh_key_name: original.ssh_key_name
    )
    STORE.delete_if { |env| env.id == environment.id && env.session_id == environment.session_id }
    prune_terminated!
    EnvironmentChannel.broadcast(environment, environment.session_id)
    environment
  end

  def prune_terminated!
    cutoff = 1.hour.ago
    STORE.delete_if { |env| env.status == 'terminated' && env.expires_at && env.expires_at < cutoff }
  end

  def generate_id(project_name)
    timestamp = Time.current.utc.strftime('%Y%m%d%H%M%S')
    unique = SecureRandom.hex(4)
    "#{project_name}-#{timestamp}-#{unique}"
  end
end
