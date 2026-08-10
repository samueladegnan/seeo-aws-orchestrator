# frozen_string_literal: true

class OciService < CliCloudService
  def initialize(provider: 'oci')
    super
  end

  protected

  def required_environment_variables
    %w[SEEO_OCI_COMPARTMENT_ID SEEO_OCI_SUBNET_ID SEEO_OCI_AVAILABILITY_DOMAIN SEEO_OCI_IMAGE_ID]
  end

  def launch_command(environment)
    ['oci', 'compute', 'instance', 'launch', '--compartment-id', ENV.fetch('SEEO_OCI_COMPARTMENT_ID'),
     '--display-name', environment.id, '--shape', environment.instance_type,
     '--subnet-id', ENV.fetch('SEEO_OCI_SUBNET_ID'), '--availability-domain', ENV.fetch('SEEO_OCI_AVAILABILITY_DOMAIN'),
     '--image-id', ENV.fetch('SEEO_OCI_IMAGE_ID'), '--boot-volume-size-in-gbs', environment.volume_size.to_i.to_s,
     '--shape-config', shape_config_for(environment),
     '--wait-for-state', 'RUNNING', '--output', 'json']
  end

  def inspect_command(environment)
    ['oci', 'compute', 'instance', 'get', '--instance-id', environment.provider_resource_id, '--output', 'json']
  end

  def terminate_command(environment)
    ['oci', 'compute', 'instance', 'terminate', '--instance-id', environment.provider_resource_id,
     '--preserve-boot-volume', 'false', '--force', '--output', 'json']
  end

  def shape_config_for(environment)
    ocpus = { 'small' => 1, 'medium' => 2, 'large' => 4 }.fetch(environment.compute_tier, 1)
    JSON.generate({ ocpus: ocpus, memoryInGBs: ocpus * 4 })
  end

  def normalize_result(result)
    instance = result['data'] || result
    {
      'id' => instance['id'],
      'state' => instance['lifecycle-state'],
      'publicIpAddress' => instance['public-ip'],
      'privateIpAddress' => instance['private-ip']
    }
  end
end
