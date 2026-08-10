# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'provider adapter contracts' do
  FIXTURE_ROOT = Rails.root.join('spec/fixtures/provider_responses')

  def fixture(name)
    JSON.parse(File.read(FIXTURE_ROOT.join(name)))
  end

  def stub_command(output)
    allow(Open3).to receive(:capture3).and_return([
      JSON.generate(output),
      '',
      instance_double(Process::Status, success?: true)
    ])
  end

  def stub_persistence
    record = instance_double(
      EnvironmentRecord,
      assign_attributes: nil,
      save!: true
    )
    allow(EnvironmentRecord).to receive(:find_or_initialize_by).and_return(record)
  end

  around do |example|
    original = ENV.to_h
    example.run
  ensure
    ENV.replace(original)
  end

  it 'executes the AWS create contract with argv and normalizes the response' do
    service = AwsService.new(provider: 'aws')
    ENV.update(
      'SEEO_AWS_SUBNET_ID' => 'subnet-demo',
      'SEEO_AWS_SECURITY_GROUP_ID' => 'sg-demo',
      'SEEO_AWS_IMAGE_ID' => 'ami-demo'
    )
    stub_command(fixture('aws_describe_instances.json'))
    stub_persistence

    environment = service.create_environment('contract-demo', 60, 'small', region: 'us-east-1', volume_size: 10)

    expect(environment.provider_resource_id).to eq('i-0123456789abcdef0')
    expect(environment.public_ip).to eq('198.51.100.10')
    expect(environment.status).to eq('ready')
    expect(Open3).to have_received(:capture3).with(
      'aws', 'ec2', 'run-instances', '--image-id', 'ami-demo',
      '--instance-type', 't3.micro', '--subnet-id', 'subnet-demo',
      '--security-group-ids', 'sg-demo', '--min-count', '1', '--max-count', '1', '--output', 'json'
    )
  end

  it 'executes the Azure create contract with argv and normalizes the response' do
    service = AzureService.new(provider: 'azure')
    ENV.update('SEEO_AZURE_RESOURCE_GROUP' => 'rg-demo', 'SEEO_AZURE_SUBNET_ID' => 'subnet-demo')
    stub_command(fixture('azure_instance_view.json'))
    stub_persistence

    environment = service.create_environment('contract-demo', 60, 'small', region: 'eastus', volume_size: 10)

    expect(environment.provider_resource_id).to eq('azure-vm-0123')
    expect(environment.status).to eq('ready')
    expect(Open3).to have_received(:capture3).with(
      'az', 'vm', 'create', '--resource-group', 'rg-demo',
      '--name', environment.id, '--image', 'Ubuntu2204', '--size', 'Standard_B1s',
      '--location', 'eastus', '--subnet', 'subnet-demo', '--os-disk-size-gb', '10',
      '--storage-sku', 'StandardSSD_LRS', '--output', 'json'
    )
  end

  it 'executes the GCP create contract with argv and normalizes the response' do
    service = GcpService.new(provider: 'gcp')
    ENV.update('SEEO_GCP_PROJECT' => 'project-demo', 'SEEO_GCP_SUBNET_ID' => 'subnet-demo', 'SEEO_GCP_ZONE' => 'us-central1-a')
    stub_command(fixture('gcp_instance.json'))
    stub_persistence

    environment = service.create_environment('contract-demo', 60, 'small', region: 'us-central1', volume_size: 10)

    expect(environment.provider_resource_id).to eq('1234567890')
    expect(environment.public_ip).to eq('198.51.100.20')
    expect(environment.status).to eq('ready')
    expect(Open3).to have_received(:capture3).with(
      'gcloud', 'compute', 'instances', 'create', environment.id,
      '--project', 'project-demo', '--zone', 'us-central1-a', '--machine-type', 'e2-micro',
      '--subnet', 'subnet-demo', '--boot-disk-size', '10', '--boot-disk-type', 'pd-balanced', '--format=json'
    )
  end

  it 'executes the OCI create contract with argv and normalizes the response' do
    service = OciService.new(provider: 'oci')
    ENV.update(
      'SEEO_OCI_COMPARTMENT_ID' => 'ocid-compartment-demo',
      'SEEO_OCI_SUBNET_ID' => 'ocid-subnet-demo',
      'SEEO_OCI_AVAILABILITY_DOMAIN' => 'AD-1',
      'SEEO_OCI_IMAGE_ID' => 'ocid-image-demo'
    )
    stub_command(fixture('oci_instance.json'))
    stub_persistence

    environment = service.create_environment('contract-demo', 60, 'small', region: 'us-ashburn-1', volume_size: 10)

    expect(environment.provider_resource_id).to eq('ocid1.instance.oc1.iad.example')
    expect(environment.private_ip).to eq('10.40.1.10')
    expect(environment.status).to eq('ready')
    expect(Open3).to have_received(:capture3).with(
      'oci', 'compute', 'instance', 'launch', '--compartment-id', 'ocid-compartment-demo',
      '--display-name', environment.id, '--shape', 'VM.Standard.E4.Flex',
      '--subnet-id', 'ocid-subnet-demo', '--availability-domain', 'AD-1', '--image-id', 'ocid-image-demo',
      '--boot-volume-size-in-gbs', '10', '--shape-config', '{"ocpus":1,"memoryInGBs":4}',
      '--wait-for-state', 'RUNNING', '--output', 'json'
    )
  end

  it 'passes provider commands as argv arrays without shell interpolation' do
    service = GcpService.new(provider: 'gcp')
    stub_command('status' => 'RUNNING')

    expect(service.send(:run_command, 'gcloud', 'compute', 'instances', 'describe', 'demo; echo unsafe'))
      .to eq(JSON.generate('status' => 'RUNNING'))
    expect(Open3).to have_received(:capture3).with('gcloud', 'compute', 'instances', 'describe', 'demo; echo unsafe')
  end
end
