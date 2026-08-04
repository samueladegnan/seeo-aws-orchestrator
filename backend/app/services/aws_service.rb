# frozen_string_literal: true

require 'base64'
require 'digest'
require 'securerandom'
require 'time'

# This adapter intentionally owns the provider lifecycle boundary.
# rubocop:disable Metrics/ClassLength
class AwsService
  class PartialResourceError < StandardError
    attr_reader :volume_id

    def initialize(message, volume_id)
      @volume_id = volume_id
      super(message)
    end
  end

  attr_reader :settings

  def initialize
    @settings = SeeoConfig
  end

  # The lifecycle includes reservation, provider calls, persistence, and retry recovery.
  def create_environment(project, ttl_minutes, instance_type = nil, options = {})
    existing = find_by_idempotency(options[:idempotency_key])
    expected_fingerprint = request_fingerprint_for(project, ttl_minutes, instance_type, options)
    return mark_reused(existing, expected_fingerprint) if existing

    attrs = build_creation_attrs(project, ttl_minutes, instance_type, options)
    environment = build_environment(attrs)
    reserve_environment!(environment)

    base_tags = build_base_tags(attrs[:id], attrs[:project_name], attrs[:team], ttl_minutes, project)
    instance_id, volume_id = provision_resources(environment, base_tags, attrs)

    environment.instance_id = instance_id
    environment.volume_id = volume_id
    persist_environment(environment)
    environment
  rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
    existing = get_environment(environment.id)
    raise unless existing

    mark_reused(existing, expected_fingerprint)
  rescue StandardError => e
    mark_provisioning_error(environment)
    raise e
  end

  def get_environment(environment_id)
    response = dynamodb_client.get_item(table_name: settings.environments_table, key: { 'id' => environment_id })
    item = response.item
    return nil unless item

    environment = item_to_environment(item)
    environment if accessible?(environment)
  rescue Aws::DynamoDB::Errors::ServiceError => e
    raise "Failed to read environment: #{e.message}"
  end

  def list_environments(status_filter = nil)
    items = dynamodb_client.scan(table_name: settings.environments_table).items
    environments = items.map { |item| item_to_environment(item) }.select { |env| accessible?(env) }
    status_filter ? environments.select { |env| env.status == status_filter } : environments
  rescue Aws::DynamoDB::Errors::ServiceError => e
    raise "Failed to list environments: #{e.message}"
  end

  def active_environment_count
    list_environments.count { |environment| environment.status != 'terminated' }
  end

  def list_expired_environments
    raise AuthorizationService::AuthenticationError, 'Cleanup context required' unless Current.internal_cleanup

    now = Time.current.utc.iso8601
    response = dynamodb_client.scan(
      table_name: settings.environments_table,
      filter_expression: 'expires_at < :now',
      expression_attribute_values: { ':now' => now }
    )
    environments = response.items.map { |item| item_to_environment(item) }
    environments = environments.select { |environment| accessible_to_cleanup?(environment) }
    environments.select { |environment| %w[pending provisioning ready error terminating].include?(environment.status) }
  rescue Aws::DynamoDB::Errors::ServiceError => e
    raise "Failed to list expired environments: #{e.message}"
  end

  def terminate_environment(environment_id)
    environment = get_environment(environment_id)
    raise ArgumentError, "Environment #{environment_id} not found" unless environment
    return environment if environment.status == 'terminated'

    terminate_existing_environment(environment)
  end

  def force_terminate_environment(environment_id)
    raise AuthorizationService::AuthenticationError, 'Cleanup context required' unless Current.internal_cleanup

    environment = get_environment_for_cleanup(environment_id)
    raise ArgumentError, "Environment #{environment_id} not found" unless environment
    return environment if environment.status == 'terminated'

    terminate_existing_environment(environment)
  end

  def refresh_environment_state(environment_id)
    environment = get_environment(environment_id)
    return nil unless environment
    return environment unless environment.instance_id

    begin
      response = ec2_client.describe_instances(instance_ids: [environment.instance_id])
      instance = response.reservations.first.instances.first
      environment.public_ip = instance.public_ip_address
      environment.private_ip = instance.private_ip_address
      state = instance.state.name

      if state == 'running' && environment.status == 'provisioning'
        environment.status = 'ready'
      elsif state == 'terminated'
        environment.status = 'terminated'
      end
    rescue Aws::EC2::Errors::ServiceError
      Rails.logger.info "[AWS] Instance #{environment.instance_id} is no longer available"
    end

    persist_environment(environment)
    environment
  end

  def persist_environment(environment)
    dynamodb_client.put_item(
      table_name: settings.environments_table,
      item: environment_to_item(environment)
    )

    EnvironmentChannel.broadcast(environment)
  end

  def reserve_environment!(environment)
    dynamodb_client.put_item(
      table_name: settings.environments_table,
      item: environment_to_item(environment),
      condition_expression: 'attribute_not_exists(id)'
    )
    EnvironmentChannel.broadcast(environment)
  end

  private

  def terminate_existing_environment(environment)
    environment.status = 'terminating'
    persist_environment(environment)
    failures = [cleanup_instance(environment), cleanup_volume(environment)].compact

    if failures.empty?
      environment.status = 'terminated'
      environment.message = 'Environment terminated'
      persist_environment(environment)
      environment
    else
      environment.status = 'error'
      environment.message = failures.join(', ')
      persist_environment(environment)
      raise "Environment cleanup incomplete: #{environment.message}"
    end
  end

  def ec2_client
    @ec2_client ||= Aws::EC2::Client.new(client_options)
  end

  def dynamodb_client
    @dynamodb_client ||= Aws::DynamoDB::Client.new(client_options)
  end

  def client_options
    opts = { region: settings.aws_region }
    opts[:profile] = settings.aws_profile if settings.aws_profile
    opts
  end

  def request_fingerprint_for(project, ttl_minutes, instance_type, options)
    request_fingerprint(resolve_project_name(project), ttl_minutes, instance_type, options)
  end

  def request_fingerprint(project_name, ttl_minutes, instance_type, options)
    Digest::SHA256.hexdigest({
      project_name: project_name,
      ttl_minutes: ttl_minutes.to_i,
      instance_type: instance_type || settings.ec2_instance_type,
      region: options[:region],
      volume_size: options[:volume_size],
      volume_type: options[:volume_type],
      tags: options[:tags],
      notes: options[:notes],
      ssh_key_name: options[:ssh_key_name]
    }.to_json)
  end

  def build_creation_attrs(project, ttl_minutes, instance_type, options)
    project_name = resolve_project_name(project)

    {
      id: generate_id(project_name, options),
      project_name: project_name,
      team: resolve_team(project),
      project_id: project.is_a?(Project) ? project.id : nil,
      owner_user_id: Current.user&.id,
      session_id: Current.session_id.presence || 'default',
      idempotency_key: options[:idempotency_key],
      request_fingerprint: request_fingerprint(project_name, ttl_minutes, instance_type, options),
      created_at: Time.current.utc,
      expires_at: Time.current.utc + ttl_minutes.to_i.minutes,
      ami_id: settings.ec2_ami_id || latest_amazon_linux_ami,
      instance_type: instance_type || settings.ec2_instance_type,
      region: resolve_option(options, :region, settings.aws_region),
      volume_size: resolve_option(options, :volume_size, 10),
      volume_type: resolve_option(options, :volume_type, 'gp3'),
      tags: resolve_option(options, :tags, {}),
      notes: resolve_option(options, :notes, ''),
      ssh_key_name: resolve_option(options, :ssh_key_name, settings.ec2_key_pair),
      ttl_minutes: ttl_minutes
    }
  end

  def mark_reused(environment, expected_fingerprint = nil)
    if expected_fingerprint && environment.request_fingerprint.present? &&
       environment.request_fingerprint != expected_fingerprint
      raise ArgumentError, 'Idempotency key was already used with different request parameters'
    end

    environment.reused = true
    environment
  end

  def mark_provisioning_error(environment)
    return unless environment && environment.status == 'provisioning'

    environment.status = 'error'
    environment.message = 'Provisioning failed. Review the logs before retrying.'
    persist_environment(environment)
  end

  def resolve_option(options, key, fallback)
    options[key].presence || fallback
  end

  def resolve_project_name(project)
    project.is_a?(Project) ? project.name : project
  end

  def resolve_team(project)
    project.is_a?(Project) ? project.team : Current.team
  end

  def build_base_tags(environment_id, project_name, team, ttl_minutes, project)
    [
      { key: 'Name', value: "seeo-#{environment_id}" },
      { key: 'Project', value: project_name },
      { key: 'seeo:environment_id', value: environment_id },
      { key: 'seeo:ttl_minutes', value: ttl_minutes.to_s },
      { key: 'seeo:managed_by', value: 'seeo' },
      { key: 'seeo:team_id', value: team&.id.to_s },
      { key: 'seeo:project_id', value: project.is_a?(Project) ? project.id.to_s : 'unknown' }
    ]
  end

  # Persisting each acquired provider ID is intentional. It gives the TTL worker
  # enough state to retry cleanup after a partial provisioning failure.
  # rubocop:disable Metrics/AbcSize
  def provision_resources(environment, base_tags, attrs)
    user_data = encode_user_data(environment.id, settings.secrets_secret_name)
    run_args = build_run_args(attrs[:ami_id], attrs[:instance_type], user_data, base_tags)
    instance_id = nil
    volume_id = nil

    begin
      response = ec2_client.run_instances(run_args)
      instance_id = response.instances.first.instance_id
      environment.instance_id = instance_id
      persist_environment(environment)
      volume_id = attach_volume_for(instance_id, base_tags, attrs[:volume_size], attrs[:volume_type])
      environment.volume_id = volume_id
      persist_environment(environment)
      [instance_id, volume_id]
    rescue PartialResourceError => e
      volume_id ||= e.volume_id
      environment.instance_id = instance_id
      environment.volume_id = volume_id
      begin
        persist_environment(environment)
      rescue StandardError => persist_error
        Rails.logger.error "[AWS] Could not persist partial environment #{environment.id}: #{persist_error.class}"
      end
      cleanup_partial_resources(instance_id, volume_id)
      raise
    rescue StandardError
      environment.instance_id = instance_id
      environment.volume_id = volume_id
      begin
        persist_environment(environment)
      rescue StandardError => persist_error
        Rails.logger.error "[AWS] Could not persist partial environment #{environment.id}: #{persist_error.class}"
      end
      cleanup_partial_resources(instance_id, volume_id)
      raise
    end
  end
  # rubocop:enable Metrics/AbcSize

  def build_run_args(ami_id, selected_instance_type, user_data, base_tags)
    {
      image_id: ami_id,
      instance_type: selected_instance_type,
      min_count: 1,
      max_count: 1,
      user_data: Base64.strict_encode64(user_data),
      tag_specifications: [{ resource_type: 'instance', tags: base_tags }]
    }.tap do |args|
      args[:iam_instance_profile] = { name: settings.iam_instance_profile } if settings.iam_instance_profile
      args[:key_name] = settings.ec2_key_pair if settings.ec2_key_pair
      args[:security_group_ids] = [settings.ec2_security_group_id] if settings.ec2_security_group_id
      args[:subnet_id] = settings.ec2_subnet_id if settings.ec2_subnet_id
    end
  end

  def attach_volume_for(instance_id, base_tags, volume_size, volume_type = 'gp3')
    volume_tags = base_tags.map { |tag| { key: tag[:key], value: tag[:value] } }
    volume_resp = ec2_client.create_volume(
      size: volume_size || 10,
      volume_type: volume_type || 'gp3',
      availability_zone: availability_zone_for_subnet,
      tag_specifications: [{ resource_type: 'volume', tags: volume_tags }]
    )
    volume_id = volume_resp.volume_id
    begin
      ec2_client.attach_volume(instance_id: instance_id, volume_id: volume_id, device: '/dev/sdf')
      volume_id
    rescue StandardError => e
      raise PartialResourceError.new(e.message, volume_id)
    end
  end

  def build_environment(attrs)
    Environment.new(
      id: attrs[:id],
      project_name: attrs[:project_name],
      project_id: attrs[:project_id],
      team_id: attrs[:team]&.id,
      owner_user_id: attrs[:owner_user_id],
      status: 'provisioning',
      created_at: attrs[:created_at],
      expires_at: attrs[:expires_at],
      instance_id: attrs[:instance_id],
      volume_id: attrs[:volume_id],
      ttl_minutes: attrs[:ttl_minutes].to_i,
      instance_type: attrs[:instance_type],
      session_id: attrs[:session_id],
      idempotency_key: attrs[:idempotency_key],
      request_fingerprint: attrs[:request_fingerprint],
      region: attrs[:region],
      volume_size: attrs[:volume_size],
      volume_type: attrs[:volume_type],
      tags: attrs[:tags],
      notes: attrs[:notes],
      ssh_key_name: attrs[:ssh_key_name]
    )
  end

  def generate_id(project_name, options = {})
    if options[:idempotency_key].present?
      scope = [project_name, Current.team&.id, Current.session_id, options[:idempotency_key]].join(':')
      return "#{project_name}-#{Digest::SHA256.hexdigest(scope)[0, 16]}"
    end

    timestamp = Time.current.utc.strftime('%Y%m%d%H%M%S')
    unique = SecureRandom.hex(4)
    "#{project_name}-#{timestamp}-#{unique}"
  end

  def encode_user_data(environment_id, secret_name)
    <<~BASH
      #!/bin/bash
      set -euo pipefail
      exec > >(tee /var/log/seeo-bootstrap.log) 2>&1

      REGION="#{settings.aws_region}"
      SECRET_NAME="#{secret_name}"
      CONFIG_FILE="/etc/seeo-config.json"
      SECRET_FILE="/etc/seeo-secret.json"

      aws secretsmanager get-secret-value \\
        --region "$REGION" \\
        --secret-id "$SECRET_NAME" \\
        --query SecretString --output text > "$SECRET_FILE"
      chmod 600 "$SECRET_FILE"

      printf '%s' "{\\"environment_id\\": \\"#{environment_id}\\"}" > "$CONFIG_FILE"
      chmod 600 "$CONFIG_FILE"

      echo "SEEO bootstrap complete for #{environment_id}"
    BASH
  end

  def latest_amazon_linux_ami
    response = ec2_client.describe_images(
      owners: ['amazon'],
      filters: [
        { name: 'name', values: ['al2023-ami-*'] },
        { name: 'virtualization-type', values: ['hvm'] },
        { name: 'architecture', values: ['x86_64'] }
      ]
    )
    images = response.images.sort_by(&:creation_date).reverse
    raise 'No Amazon Linux 2023 AMI found' if images.empty?

    images.first.image_id
  rescue Aws::EC2::Errors::ServiceError => e
    raise "Unable to resolve latest AMI: #{e.message}"
  end

  def availability_zone_for_subnet
    if settings.ec2_subnet_id
      begin
        response = ec2_client.describe_subnets(subnet_ids: [settings.ec2_subnet_id])
        return response.subnets.first.availability_zone
      rescue Aws::EC2::Errors::ServiceError
        Rails.logger.warn '[AWS] Could not resolve subnet availability zone'
      end
    end

    response = ec2_client.describe_availability_zones
    response.availability_zones.first.zone_name
  end

  def wait_for_instance_termination(instance_id, timeout: 120)
    start = Time.current
    while (Time.current - start) < timeout
      begin
        response = ec2_client.describe_instances(instance_ids: [instance_id])
        state = response.reservations.first.instances.first.state.name
        return if %w[terminated terminating].include?(state)
      rescue Aws::EC2::Errors::ServiceError
        return
      end
      sleep 5
    end
  end

  def environment_to_item(environment)
    {
      'id' => environment.id,
      'project_name' => environment.project_name,
      'project_id' => environment.project_id,
      'team_id' => environment.team_id,
      'owner_user_id' => environment.owner_user_id,
      'session_id' => environment.session_id,
      'idempotency_key' => environment.idempotency_key,
      'request_fingerprint' => environment.request_fingerprint,
      'status' => environment.status,
      'created_at' => environment.created_at.iso8601,
      'expires_at' => environment.expires_at.iso8601,
      'instance_id' => environment.instance_id,
      'public_ip' => environment.public_ip,
      'private_ip' => environment.private_ip,
      'volume_id' => environment.volume_id,
      'ttl_minutes' => environment.ttl_minutes,
      'instance_type' => environment.instance_type,
      'message' => environment.message,
      'region' => environment.region,
      'volume_size' => environment.volume_size,
      'volume_type' => environment.volume_type,
      'tags' => environment.tags,
      'notes' => environment.notes,
      'ssh_key_name' => environment.ssh_key_name
    }
  end

  def item_to_environment(item)
    Environment.new(
      id: item['id'],
      project_name: item['project_name'],
      project_id: item['project_id'],
      team_id: item['team_id'],
      owner_user_id: item['owner_user_id'],
      session_id: item['session_id'],
      idempotency_key: item['idempotency_key'],
      request_fingerprint: item['request_fingerprint'],
      status: item['status'],
      created_at: Time.zone.parse(item['created_at']),
      expires_at: Time.zone.parse(item['expires_at']),
      instance_id: item['instance_id'],
      public_ip: item['public_ip'],
      private_ip: item['private_ip'],
      volume_id: item['volume_id'],
      ttl_minutes: item['ttl_minutes'].to_i,
      instance_type: item['instance_type'],
      message: item['message'],
      region: item['region'],
      volume_size: item['volume_size'],
      volume_type: item['volume_type'],
      tags: item['tags'],
      notes: item['notes'],
      ssh_key_name: item['ssh_key_name']
    )
  end

  def cleanup_instance(environment)
    return unless environment.instance_id

    ec2_client.terminate_instances(instance_ids: [environment.instance_id])
    wait_for_instance_termination(environment.instance_id)
    nil
  rescue Aws::EC2::Errors::InvalidInstanceIDNotFound
    Rails.logger.info "[AWS] Instance #{environment.instance_id} already terminated"
    nil
  rescue StandardError => e
    Rails.logger.error "[AWS] Instance cleanup failed for #{environment.id}: #{e.class}"
    'instance cleanup failed'
  end

  def cleanup_volume(environment)
    return unless environment.volume_id

    ec2_client.delete_volume(volume_id: environment.volume_id)
    nil
  rescue Aws::EC2::Errors::InvalidVolumeNotFound
    Rails.logger.info "[AWS] Volume #{environment.volume_id} already deleted"
    nil
  rescue Aws::EC2::Errors::VolumeInUse => e
    Rails.logger.warn "[AWS] Volume #{environment.volume_id} is still in use: #{e.message}"
    'volume is still in use'
  rescue StandardError => e
    Rails.logger.error "[AWS] Volume cleanup failed for #{environment.id}: #{e.class}"
    'volume cleanup failed'
  end

  def find_by_idempotency(key)
    return nil if key.blank?

    response = dynamodb_client.scan(
      table_name: settings.environments_table,
      filter_expression: 'idempotency_key = :key',
      expression_attribute_values: { ':key' => key }
    )
    environments = response.items.map { |item| item_to_environment(item) }
    environments.find { |environment| accessible?(environment) && environment.status != 'terminated' }
  rescue Aws::DynamoDB::Errors::ServiceError => e
    Rails.logger.warn "[AWS] Idempotency lookup failed: #{e.class}"
    nil
  end

  def get_environment_for_cleanup(environment_id)
    response = dynamodb_client.get_item(table_name: settings.environments_table, key: { 'id' => environment_id })
    item = response.item
    item && item_to_environment(item)
  end

  def accessible?(environment)
    environment.owned_by?(team_id: Current.team&.id, session_id: Current.session_id)
  end

  def accessible_to_cleanup?(environment)
    Current.internal_cleanup || accessible?(environment)
  end

  def cleanup_partial_resources(instance_id, volume_id)
    if volume_id
      begin
        ec2_client.delete_volume(volume_id: volume_id)
      rescue StandardError => e
        Rails.logger.error "[AWS] Partial volume cleanup failed: #{e.class}"
      end
    end

    return unless instance_id

    begin
      ec2_client.terminate_instances(instance_ids: [instance_id])
    rescue StandardError => e
      Rails.logger.error "[AWS] Partial instance cleanup failed: #{e.class}"
    end
  end
end
# rubocop:enable Metrics/ClassLength
