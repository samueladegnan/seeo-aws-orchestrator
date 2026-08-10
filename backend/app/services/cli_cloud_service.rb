# frozen_string_literal: true

require 'json'
require 'open3'
require 'digest'
require 'securerandom'

class CliCloudService < CloudAdapter
  def create_environment(project, ttl_minutes, compute_tier = nil, options = {})
    tier = normalize_compute_tier(compute_tier)
    validate_configuration!
    fingerprint = request_fingerprint(project, ttl_minutes, tier, options)
    existing = find_by_idempotency(options[:idempotency_key])
    return mark_reused(existing, fingerprint) if existing

    environment = build_environment(project, ttl_minutes, tier, options, fingerprint)
    persist_environment(environment)
    result = normalize_result(parse_output(run_command(*launch_command(environment))))
    apply_provider_result(environment, result)
    environment.status = provider_state(result) == 'running' ? 'ready' : 'provisioning'
    persist_environment(environment)
    environment
  rescue ActiveRecord::RecordNotUnique
    existing = find_by_idempotency(options[:idempotency_key])
    raise unless existing

    mark_reused(existing, fingerprint)
  rescue StandardError => e
    mark_provisioning_error(environment)
    raise e
  end

  def get_environment(environment_id)
    record = EnvironmentRecord.find_by(id: environment_id, provider: @provider)
    environment = record&.to_environment
    environment if environment && accessible?(environment)
  end

  def list_environments(status_filter = nil)
    scope = EnvironmentRecord.where(provider: @provider)
    scope = scope.where(status: status_filter) if status_filter.present?
    scope.map(&:to_environment).select { |environment| accessible?(environment) }
  end

  def active_environment_count
    list_environments.count { |environment| environment.status != 'terminated' }
  end

  def list_expired_environments
    raise AuthorizationService::AuthenticationError, 'Cleanup context required' unless Current.internal_cleanup

    EnvironmentRecord.where(provider: @provider).where(expires_at: ..Time.current)
                     .where(status: %w[pending provisioning ready error terminating])
                     .map(&:to_environment)
  end

  def terminate_environment(environment_id)
    environment = get_environment(environment_id)
    raise ArgumentError, "Environment #{environment_id} not found" unless environment

    terminate_existing_environment(environment)
  end

  def force_terminate_environment(environment_id)
    raise AuthorizationService::AuthenticationError, 'Cleanup context required' unless Current.internal_cleanup

    environment = EnvironmentRecord.find_by(id: environment_id, provider: @provider)&.to_environment
    raise ArgumentError, "Environment #{environment_id} not found" unless environment

    terminate_existing_environment(environment)
  end

  def refresh_environment_state(environment_id)
    environment = get_environment(environment_id)
    return nil unless environment
    return environment unless environment.provider_resource_id

    validate_configuration!
    result = normalize_result(parse_output(run_command(*inspect_command(environment))))
    apply_provider_result(environment, result)
    environment.status = provider_state(result) == 'running' ? 'ready' : environment.status
    environment.status = 'terminated' if provider_state(result) == 'terminated'
    persist_environment(environment)
    environment
  end

  protected

  def validate_configuration!
    missing = required_environment_variables.reject { |key| ENV[key].present? }
    return if missing.empty?

    raise CloudAdapter::UnsupportedProviderError, "#{@provider} adapter is missing configuration: #{missing.join(', ')}"
  end

  def required_environment_variables
    {
      'aws' => %w[SEEO_AWS_SUBNET_ID SEEO_AWS_SECURITY_GROUP_ID SEEO_AWS_IMAGE_ID],
      'azure' => %w[SEEO_AZURE_RESOURCE_GROUP SEEO_AZURE_SUBNET_ID],
      'gcp' => %w[SEEO_GCP_PROJECT SEEO_GCP_SUBNET_ID SEEO_GCP_ZONE],
      'oci' => %w[SEEO_OCI_COMPARTMENT_ID SEEO_OCI_SUBNET_ID SEEO_OCI_AVAILABILITY_DOMAIN SEEO_OCI_IMAGE_ID]
    }.fetch(@provider, [])
  end

  def launch_command(_) = raise(NotImplementedError)
  def inspect_command(_) = raise(NotImplementedError)
  def terminate_command(_) = raise(NotImplementedError)

  def normalize_result(result)
    result.is_a?(Hash) && result['data'].is_a?(Hash) ? result['data'] : result
  end

  def provider_state(result)
    state = %w[state status lifecycle-state powerState].filter_map { |key| result[key] }.first
    state ||= result.dig('instanceView', 'statuses')&.last&.fetch('code', nil)
    normalized_state = state.to_s.downcase
    normalized_state.match?(/running|succeeded/) ? 'running' : normalized_state
  end

  def provider_resource_id(result)
    result['id'] || result['instanceId'] || result['selfLink'] || result['ocid']
  end

  def apply_provider_result(environment, result)
    environment.provider_resource_id = provider_resource_id(result) || environment.provider_resource_id
    environment.public_ip = provider_ip(
      result, 'publicIpAddress', 'public_ip', 'primaryPublicIp', 'publicIp'
    )
    environment.private_ip = provider_ip(result, 'privateIpAddress', 'private_ip', 'primaryPrivateIp', 'privateIp')
  end

  def provider_ip(result, *keys)
    keys.filter_map { |key| result[key] }.first ||
      result.dig('network', keys.first == 'publicIpAddress' ? 'publicIp' : 'privateIp')
  end

  def run_command(*)
    stdout, stderr, status = Open3.capture3(*)
    raise "#{@provider} command failed: #{stderr.presence || stdout}" unless status.success?

    stdout
  end

  def parse_output(output)
    JSON.parse(output.presence || '{}')
  rescue JSON::ParserError => e
    raise "#{@provider} command returned invalid JSON: #{e.message}"
  end

  # The normalized environment is intentionally assembled in one place so every
  # provider adapter persists the same control-plane shape.
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def build_environment(project, ttl_minutes, tier, options, fingerprint)
    project_name = project.is_a?(Project) ? project.name : project
    created_at = Time.current.utc
    storage_tier = options[:storage_tier].presence || 'balanced'

    Environment.new(
      id: generate_id(project_name, options), project_name: project_name,
      project_id: project.is_a?(Project) ? project.id : nil, team_id: resolve_team(project)&.id,
      owner_user_id: Current.user&.id, provider: @provider, provider_resource_type: 'virtual_machine',
      status: 'provisioning', created_at: created_at, expires_at: created_at + ttl_minutes.to_i.minutes,
      ttl_minutes: ttl_minutes.to_i, compute_tier: tier, instance_type: CloudProvider.compute_shape(@provider, tier),
      session_id: Current.session_id.presence || 'default', idempotency_key: options[:idempotency_key],
      request_fingerprint: fingerprint, region: CloudProvider.region(@provider, options[:region]),
      volume_size: options[:volume_size].presence || 10,
      storage_tier: storage_tier,
      volume_type: CloudProvider.storage_shape(@provider, storage_tier),
      tags: options[:tags] || {},
      notes: options[:notes].presence || '',
      ssh_key_name: options[:ssh_key_name].presence
    )
  end

  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def terminate_existing_environment(environment)
    environment.status = 'terminating'
    persist_environment(environment)
    run_command(*terminate_command(environment))
    environment.status = 'terminated'
    environment.message = 'Environment terminated'
    persist_environment(environment)
    environment
  rescue StandardError => e
    environment.status = 'error'
    environment.message = e.message
    persist_environment(environment)
    raise
  end

  def persist_environment(environment)
    record = EnvironmentRecord.find_or_initialize_by(id: environment.id)
    record.assign_attributes(
      project_name: environment.project_name, project_id: environment.project_id, team_id: environment.team_id,
      owner_user_id: environment.owner_user_id,
      session_id: environment.session_id,
      provider: environment.provider,
      provider_resource_id: environment.provider_resource_id,
      provider_resource_type: environment.provider_resource_type || 'virtual_machine',
      status: environment.status, created_at: environment.created_at, expires_at: environment.expires_at,
      instance_id: environment.instance_id, public_ip: environment.public_ip, private_ip: environment.private_ip,
      volume_id: environment.volume_id, ttl_minutes: environment.ttl_minutes, compute_tier: environment.compute_tier,
      instance_type: environment.instance_type, message: environment.message, region: environment.region,
      volume_size: environment.volume_size,
      storage_tier: environment.storage_tier,
      volume_type: environment.volume_type,
      tags: environment.tags || {}, notes: environment.notes, ssh_key_name: environment.ssh_key_name,
      idempotency_key: environment.idempotency_key, request_fingerprint: environment.request_fingerprint
    )
    record.save!
    EnvironmentChannel.broadcast(environment)
    environment
  end

  def find_by_idempotency(key)
    return nil if key.blank?

    record = EnvironmentRecord.find_by(idempotency_key: key, provider: @provider)
    environment = record&.to_environment
    environment if environment && accessible?(environment) && environment.status != 'terminated'
  end

  def mark_reused(environment, fingerprint)
    if environment.request_fingerprint.present? && environment.request_fingerprint != fingerprint
      raise ArgumentError, 'Idempotency key was already used with different request parameters'
    end

    environment.reused = true
    environment
  end

  def mark_provisioning_error(environment)
    return unless environment&.status == 'provisioning'

    environment.status = 'error'
    environment.message = 'Provisioning failed. Review provider command output.'
    persist_environment(environment)
  rescue StandardError => e
    Rails.logger.error "[#{@provider}] Could not persist provisioning error: #{e.message}"
  end

  def normalize_compute_tier(value)
    return value.to_s if CloudProvider::TIERS.include?(value.to_s)

    'small'
  end

  def request_fingerprint(project, ttl_minutes, tier, options)
    Digest::SHA256.hexdigest({ provider: @provider, project_name: project.is_a?(Project) ? project.name : project,
                               ttl_minutes: ttl_minutes.to_i, compute_tier: tier, region: options[:region],
                               volume_size: options[:volume_size], storage_tier: options[:storage_tier],
                               tags: options[:tags], notes: options[:notes] }.to_json)
  end

  def generate_id(project_name, options)
    suffix = if options[:idempotency_key].present?
               Digest::SHA256.hexdigest(options[:idempotency_key])[0,
                                                                   16]
             else
               SecureRandom.hex(4)
             end
    "#{project_name}-#{Time.current.utc.strftime('%Y%m%d%H%M%S')}-#{suffix}"
  end

  def resolve_team(project)
    project.is_a?(Project) ? project.team : Current.team
  end

  def accessible?(environment)
    environment.owned_by?(team_id: Current.team&.id, session_id: Current.session_id)
  end
end
