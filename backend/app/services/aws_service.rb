# frozen_string_literal: true

class AwsService < CliCloudService
  def initialize(provider: 'aws')
    super
  end

  protected

  def required_environment_variables
    %w[SEEO_AWS_SUBNET_ID SEEO_AWS_SECURITY_GROUP_ID SEEO_AWS_IMAGE_ID]
  end

  def launch_command(environment)
    ['aws', 'ec2', 'run-instances', '--image-id', ENV.fetch('SEEO_AWS_IMAGE_ID'),
     '--instance-type', environment.instance_type, '--subnet-id', ENV.fetch('SEEO_AWS_SUBNET_ID'),
     '--security-group-ids', ENV.fetch('SEEO_AWS_SECURITY_GROUP_ID'), '--min-count', '1', '--max-count', '1', '--output', 'json']
  end

  def inspect_command(environment)
    ['aws', 'ec2', 'describe-instances', '--instance-ids', environment.provider_resource_id, '--output', 'json']
  end

  def terminate_command(environment)
    ['aws', 'ec2', 'terminate-instances', '--instance-ids', environment.provider_resource_id, '--output', 'json']
  end

  def normalize_result(result)
    instance = result['Instances']&.first || result.dig('Reservations', 0, 'Instances', 0) || {}
    {
      'id' => instance['InstanceId'],
      'state' => instance.dig('State', 'Name'),
      'publicIpAddress' => instance['PublicIpAddress'],
      'privateIpAddress' => instance['PrivateIpAddress']
    }
  end
end
