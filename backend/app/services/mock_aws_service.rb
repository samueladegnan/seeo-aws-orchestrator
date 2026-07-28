# frozen_string_literal: true

class MockAwsService
  # In-memory store so environments persist across requests in dev/test.
  # Production should never use this; SeeoConfig.mock_aws? defaults to false there.
  STORE = [] # rubocop:disable Style/MutableConstant
  MUTEX = Mutex.new

  class << self
    def reset!
      MUTEX.synchronize { STORE.clear }
    end
  end

  def create_environment(project, ttl_minutes, instance_type = nil)
    project_name = project.is_a?(Project) ? project.name : project
    environment_id = generate_id(project_name)
    created_at = Time.current.utc
    expires_at = created_at + ttl_minutes.to_i.minutes

    environment = Environment.new(
      id: environment_id,
      project_name: project_name,
      status: 'ready',
      created_at: created_at,
      expires_at: expires_at,
      instance_id: "i-mock#{SecureRandom.hex(4)}",
      public_ip: "203.0.113.#{rand(1..254)}",
      private_ip: "10.0.#{rand(0..255)}.#{rand(1..254)}",
      volume_id: "vol-mock#{SecureRandom.hex(4)}",
      ttl_minutes: ttl_minutes.to_i,
      instance_type: instance_type || SeeoConfig.ec2_instance_type
    )

    MUTEX.synchronize { STORE << environment }
    EnvironmentChannel.broadcast(environment)
    environment
  end

  def get_environment(environment_id)
    MUTEX.synchronize { STORE.find { |env| env.id == environment_id } }
  end

  def list_environments(status_filter = nil)
    environments = MUTEX.synchronize { STORE.dup }
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
      original = STORE.find { |env| env.id == environment_id }
      raise ArgumentError, "Environment #{environment_id} not found" unless original

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
        instance_type: original.instance_type
      )
      STORE.delete_if { |env| env.id == environment_id }
      environment
    end
  end

  private

  def generate_id(project_name)
    timestamp = Time.current.utc.strftime('%Y%m%d%H%M%S')
    unique = SecureRandom.hex(4)
    "#{project_name}-#{timestamp}-#{unique}"
  end
end
