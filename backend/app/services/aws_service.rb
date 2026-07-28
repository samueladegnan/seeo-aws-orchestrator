# frozen_string_literal: true

require 'base64'
require 'securerandom'
require 'time'

class AwsService
  attr_reader :settings

  def initialize
    @settings = SeeoConfig
  end

  # ------------------------------------------------------------------
  # Public API
  # ------------------------------------------------------------------

  def create_environment(project, ttl_minutes, instance_type = nil)
    project_name = project.is_a?(Project) ? project.name : project
    team = project.is_a?(Project) ? project.team : Current.team

    environment_id = generate_id(project_name)
    created_at = Time.current.utc
    expires_at = created_at + ttl_minutes.to_i.minutes

    ami_id = settings.ec2_ami_id || latest_amazon_linux_ami
    selected_instance_type = instance_type || settings.ec2_instance_type

    user_data = encode_user_data(environment_id, settings.secrets_secret_name)

    base_tags = [
      { key: 'Name', value: "seeo-#{environment_id}" },
      { key: 'Project', value: project_name },
      { key: 'seeo:environment_id', value: environment_id },
      { key: 'seeo:ttl_minutes', value: ttl_minutes.to_s },
      { key: 'seeo:managed_by', value: 'seeo' },
      { key: 'seeo:team_id', value: team&.id.to_s },
      { key: 'seeo:project_id', value: project.is_a?(Project) ? project.id.to_s : 'unknown' }
    ]

    run_args = build_run_args(ami_id, selected_instance_type, user_data, base_tags)
    response = ec2_client.run_instances(run_args)
    instance_id = response.instances.first.instance_id
    volume_id = attach_volume_for(instance_id, base_tags)

    environment = build_environment(
      id: environment_id,
      project_name: project_name,
      created_at: created_at,
      expires_at: expires_at,
      instance_id: instance_id,
      volume_id: volume_id,
      ttl_minutes: ttl_minutes,
      instance_type: selected_instance_type
    )
    persist_environment(environment)
    environment
  end

  def get_environment(environment_id)
    response = dynamodb_client.get_item(table_name: settings.environments_table, key: { 'id' => environment_id })
    item = response.item
    return nil unless item

    item_to_environment(item)
  rescue Aws::DynamoDB::Errors::ServiceError => e
    raise "Failed to read environment: #{e.message}"
  end

  def list_environments(status_filter = nil)
    response = if status_filter
                 dynamodb_client.scan(
                   table_name: settings.environments_table,
                   filter_expression: '#s = :status',
                   expression_attribute_names: { '#s' => 'status' },
                   expression_attribute_values: { ':status' => status_filter }
                 )
               else
                 dynamodb_client.scan(table_name: settings.environments_table)
               end

    response.items.map { |item| item_to_environment(item) }
  rescue Aws::DynamoDB::Errors::ServiceError => e
    raise "Failed to list environments: #{e.message}"
  end

  def list_expired_environments
    now = Time.current.utc.iso8601
    response = dynamodb_client.scan(
      table_name: settings.environments_table,
      filter_expression: 'expires_at < :now AND #s IN (:pending, :provisioning, :ready)',
      expression_attribute_names: { '#s' => 'status' },
      expression_attribute_values: {
        ':now' => now,
        ':pending' => 'pending',
        ':provisioning' => 'provisioning',
        ':ready' => 'ready'
      }
    )
    response.items.map { |item| item_to_environment(item) }
  rescue Aws::DynamoDB::Errors::ServiceError => e
    raise "Failed to list expired environments: #{e.message}"
  end

  def terminate_environment(environment_id)
    environment = get_environment(environment_id)
    raise ArgumentError, "Environment #{environment_id} not found" unless environment

    environment.status = 'terminating'
    persist_environment(environment)

    if environment.instance_id
      begin
        ec2_client.terminate_instances(instance_ids: [environment.instance_id])
      rescue Aws::EC2::Errors::InvalidInstanceIDNotFound
        # Instance may already be gone
      end
      wait_for_instance_termination(environment.instance_id)
    end

    if environment.volume_id
      begin
        ec2_client.delete_volume(volume_id: environment.volume_id)
      rescue Aws::EC2::Errors::InvalidVolumeNotFound, Aws::EC2::Errors::VolumeInUse
        # Already gone or still in use
      end
    end

    environment.status = 'terminated'
    persist_environment(environment)
    environment
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
      # Instance may already be gone
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

  # ------------------------------------------------------------------
  # Private helpers
  # ------------------------------------------------------------------

  private

  def ec2_client
    @ec2_client ||= Aws::EC2::Client.new(client_options)
  end

  def dynamodb_client
    @dynamodb_client ||= Aws::DynamoDB::Client.new(client_options)
  end

  def secrets_manager_client
    @secrets_manager_client ||= Aws::SecretsManager::Client.new(client_options)
  end

  def client_options
    opts = { region: settings.aws_region }
    opts[:profile] = settings.aws_profile if settings.aws_profile
    opts
  end

  def build_run_args(ami_id, selected_instance_type, user_data, base_tags)
    {
      image_id: ami_id,
      instance_type: selected_instance_type,
      min_count: 1,
      max_count: 1,
      user_data: Base64.strict_encode64(user_data),
      tag_specifications: [
        {
          resource_type: 'instance',
          tags: base_tags
        }
      ]
    }.tap do |args|
      args[:iam_instance_profile] = { name: settings.iam_instance_profile } if settings.iam_instance_profile
      args[:key_name] = settings.ec2_key_pair if settings.ec2_key_pair
      args[:security_group_ids] = [settings.ec2_security_group_id] if settings.ec2_security_group_id
      args[:subnet_id] = settings.ec2_subnet_id if settings.ec2_subnet_id
    end
  end

  def attach_volume_for(instance_id, base_tags)
    volume_id = nil
    volume_tags = base_tags.map { |tag| { key: tag[:key], value: tag[:value] } }
    volume_resp = ec2_client.create_volume(
      size: 10,
      volume_type: 'gp3',
      availability_zone: availability_zone_for_subnet,
      tag_specifications: [
        {
          resource_type: 'volume',
          tags: volume_tags
        }
      ]
    )
    volume_id = volume_resp.volume_id
    ec2_client.attach_volume(instance_id: instance_id, volume_id: volume_id, device: '/dev/sdf')
    volume_id
  rescue Aws::EC2::Errors::ServiceError => e
    Rails.logger.warn "EBS volume creation/attachment failed: #{e.message}"
    volume_id
  end

  def build_environment(attrs)
    Environment.new(
      id: attrs[:id],
      project_name: attrs[:project_name],
      status: 'provisioning',
      created_at: attrs[:created_at],
      expires_at: attrs[:expires_at],
      instance_id: attrs[:instance_id],
      volume_id: attrs[:volume_id],
      ttl_minutes: attrs[:ttl_minutes].to_i,
      instance_type: attrs[:instance_type]
    )
  end

  def generate_id(project_name)
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

      # Fetch runtime credentials from Secrets Manager at startup using IAM role.
      aws secretsmanager get-secret-value \\
        --region "$REGION" \\
        --secret-id "$SECRET_NAME" \\
        --query SecretString --output text > "$SECRET_FILE"
      chmod 600 "$SECRET_FILE"

      # Persist non-secret environment metadata in a separate config file.
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
        # Fallback below
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
        # Instance may already be gone
        return
      end
      sleep 5
    end
  end

  def environment_to_item(environment)
    {
      'id' => environment.id,
      'project_name' => environment.project_name,
      'status' => environment.status,
      'created_at' => environment.created_at.iso8601,
      'expires_at' => environment.expires_at.iso8601,
      'instance_id' => environment.instance_id,
      'public_ip' => environment.public_ip,
      'private_ip' => environment.private_ip,
      'volume_id' => environment.volume_id,
      'ttl_minutes' => environment.ttl_minutes,
      'instance_type' => environment.instance_type,
      'message' => environment.message
    }
  end

  def item_to_environment(item)
    Environment.new(
      id: item['id'],
      project_name: item['project_name'],
      status: item['status'],
      created_at: Time.zone.parse(item['created_at']),
      expires_at: Time.zone.parse(item['expires_at']),
      instance_id: item['instance_id'],
      public_ip: item['public_ip'],
      private_ip: item['private_ip'],
      volume_id: item['volume_id'],
      ttl_minutes: item['ttl_minutes'].to_i,
      instance_type: item['instance_type'],
      message: item['message']
    )
  end
end
