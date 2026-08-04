# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AwsService do
  let(:service) { described_class.new }
  let(:ec2_client) { instance_double(Aws::EC2::Client) }
  let(:dynamodb_client) { instance_double(Aws::DynamoDB::Client) }

  before do
    allow(Aws::EC2::Client).to receive(:new).and_return(ec2_client)
    allow(Aws::DynamoDB::Client).to receive(:new).and_return(dynamodb_client)
    allow(dynamodb_client).to receive(:put_item)
  end

  describe '#get_environment' do
    it 'returns an environment when found' do
      allow(dynamodb_client).to receive(:get_item).and_return(
        Aws::DynamoDB::Types::GetItemOutput.new(
          item: {
            'id' => 'demo-123',
            'project_name' => 'my-api',
            'status' => 'ready',
            'created_at' => Time.current.iso8601,
            'expires_at' => 1.hour.from_now.iso8601,
            'ttl_minutes' => 60
          }
        )
      )

      env = service.get_environment('demo-123')
      expect(env).to be_a(Environment)
      expect(env.project_name).to eq('my-api')
    end

    it 'returns nil when not found' do
      allow(dynamodb_client).to receive(:get_item).and_return(
        Aws::DynamoDB::Types::GetItemOutput.new(item: nil)
      )

      expect(service.get_environment('missing')).to be_nil
    end
  end

  describe '#list_expired_environments' do
    it 'requires the internal cleanup context' do
      expect { service.list_expired_environments }
        .to raise_error(AuthorizationService::AuthenticationError, /Cleanup context required/)
    end

    it 'returns only expired records for the cleanup worker' do
      Current.internal_cleanup = true
      allow(dynamodb_client).to receive(:scan).and_return(
        Aws::DynamoDB::Types::ScanOutput.new(items: [])
      )

      expect(service.list_expired_environments).to eq([])
    end
  end

  describe '#list_environments' do
    it 'returns a list of environments' do
      allow(dynamodb_client).to receive(:scan).and_return(
        Aws::DynamoDB::Types::ScanOutput.new(items: [])
      )

      expect(service.list_environments).to eq([])
    end
  end

  describe 'partial provisioning cleanup' do
    it 'terminates an instance when volume attachment fails' do
      allow(SeeoConfig).to receive_messages(ec2_ami_id: 'ami-test', ec2_instance_type: 't3.micro')
      run_instances_output = Struct.new(:instances).new(
        [Struct.new(:instance_id).new('i-partial')]
      )
      allow(ec2_client).to receive_messages(
        run_instances: run_instances_output,
        describe_availability_zones: Aws::EC2::Types::DescribeAvailabilityZonesResult.new(
          availability_zones: [Aws::EC2::Types::AvailabilityZone.new(zone_name: 'us-east-1a')]
        )
      )
      allow(ec2_client).to receive(:create_volume).and_raise(StandardError, 'volume failure')
      allow(ec2_client).to receive(:terminate_instances)

      expect do
        service.send(
          :provision_resources,
          Environment.new(
            id: 'demo-1', project_name: 'demo', status: 'provisioning',
            created_at: Time.current, expires_at: 1.hour.from_now,
            ttl_minutes: 60, region: 'us-east-1'
          ), [], {
            ami_id: 'ami-test', instance_type: 't3.micro', volume_size: 10, volume_type: 'gp3'
          }
        )
      end.to raise_error(StandardError, 'volume failure')

      expect(ec2_client).to have_received(:terminate_instances).with(instance_ids: ['i-partial'])
    end
  end
end
