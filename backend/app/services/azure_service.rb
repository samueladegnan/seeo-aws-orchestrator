# frozen_string_literal: true

class AzureService < CliCloudService
  def initialize(provider: 'azure')
    super
  end

  protected

  def required_environment_variables
    %w[SEEO_AZURE_RESOURCE_GROUP SEEO_AZURE_SUBNET_ID]
  end

  def launch_command(environment)
    ['az', 'vm', 'create', '--resource-group', ENV.fetch('SEEO_AZURE_RESOURCE_GROUP'),
     '--name', environment.id, '--image', ENV.fetch('SEEO_AZURE_IMAGE', 'Ubuntu2204'),
     '--size', environment.instance_type, '--location', environment.region,
     '--subnet', ENV.fetch('SEEO_AZURE_SUBNET_ID'), '--os-disk-size-gb', environment.volume_size.to_i.to_s,
     '--storage-sku', environment.volume_type, '--output', 'json']
  end

  def inspect_command(environment)
    ['az', 'vm', 'get-instance-view', '--resource-group', ENV.fetch('SEEO_AZURE_RESOURCE_GROUP'), '--name',
     environment.id, '--output', 'json']
  end

  def terminate_command(environment)
    ['az', 'vm', 'delete', '--resource-group', ENV.fetch('SEEO_AZURE_RESOURCE_GROUP'), '--name', environment.id,
     '--yes', '--output', 'json']
  end

  def normalize_result(result)
    statuses = result.dig('instanceView', 'statuses') || []
    state = statuses.reverse.find { |status| status['code'].to_s.start_with?('PowerState/') }
    {
      'id' => result['vmId'] || result['id'],
      'state' => state && state['code'].to_s.sub('PowerState/', '').downcase
    }
  end
end
