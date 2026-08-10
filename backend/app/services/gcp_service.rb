# frozen_string_literal: true

class GcpService < CliCloudService
  def initialize(provider: 'gcp')
    super
  end

  protected

  def required_environment_variables
    %w[SEEO_GCP_PROJECT SEEO_GCP_SUBNET_ID SEEO_GCP_ZONE]
  end

  def launch_command(environment)
    ['gcloud', 'compute', 'instances', 'create', environment.id,
     '--project', ENV.fetch('SEEO_GCP_PROJECT'), '--zone', zone_for(environment),
     '--machine-type', environment.instance_type, '--subnet', ENV.fetch('SEEO_GCP_SUBNET_ID'),
     '--boot-disk-size', environment.volume_size.to_i.to_s, '--boot-disk-type', environment.volume_type,
     '--format=json']
  end

  def inspect_command(environment)
    ['gcloud', 'compute', 'instances', 'describe', environment.id, '--project', ENV.fetch('SEEO_GCP_PROJECT'), '--zone', ENV.fetch('SEEO_GCP_ZONE'), '--format=json']
  end

  def terminate_command(environment)
    ['gcloud', 'compute', 'instances', 'delete', environment.id, '--project', ENV.fetch('SEEO_GCP_PROJECT'), '--zone', ENV.fetch('SEEO_GCP_ZONE'), '--delete-disks=all', '--quiet', '--format=json']
  end

  def normalize_result(result)
    result = result.first if result.is_a?(Array)
    network = result.dig('networkInterfaces', 0) || {}
    {
      'id' => result['id'] || result['name'],
      'state' => result['status'],
      'publicIpAddress' => network.dig('accessConfigs', 0, 'natIP'),
      'privateIpAddress' => network['networkIP']
    }
  end

  def zone_for(_environment)
    ENV.fetch('SEEO_GCP_ZONE')
  end
end
