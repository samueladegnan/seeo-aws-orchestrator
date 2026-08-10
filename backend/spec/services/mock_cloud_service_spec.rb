# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MockCloudService do
  let(:service) { described_class.new(provider: 'gcp') }

  before do
    Current.reset
    Current.session_id = 'test-session'
    described_class.reset!
  end

  after { Current.reset }

  it 'creates and terminates a provider-neutral environment' do
    environment = service.create_environment('demo', 60, 'small', region: 'us-central1')

    expect(environment).to be_a(Environment)
    expect(environment.provider).to eq('gcp')
    expect(environment.provider_resource_type).to eq('virtual_machine')
    expect(environment.compute_tier).to eq('small')
    expect(environment.instance_type).to eq('e2-micro')
    expect(environment.region).to eq('us-central1')

    terminated = service.terminate_environment(environment.id)
    expect(terminated.status).to eq('terminated')
    expect(service.get_environment(environment.id)).to be_nil
  end

  it 'isolates environments by provider' do
    aws = described_class.new(provider: 'aws')
    azure = described_class.new(provider: 'azure')
    aws_environment = aws.create_environment('aws-demo', 60, 'small', region: 'us-east-1')
    azure_environment = azure.create_environment('azure-demo', 60, 'small', region: 'eastus')

    expect(aws.list_environments.map(&:id)).to eq([aws_environment.id])
    expect(azure.list_environments.map(&:id)).to eq([azure_environment.id])
    expect(aws.get_environment(azure_environment.id)).to be_nil
  end

  it 'supports idempotency per provider and request shape' do
    first = service.create_environment('demo', 60, 'small', region: 'us-central1', idempotency_key: 'request-1')
    reused = service.create_environment('demo', 60, 'small', region: 'us-central1', idempotency_key: 'request-1')

    expect(reused.id).to eq(first.id)
    expect(reused.reused).to be(true)
    expect do
      service.create_environment('other', 60, 'small', region: 'us-central1', idempotency_key: 'request-1')
    end.to raise_error(ArgumentError, /different request parameters/)
  end

  it 'creates every supported provider in mock mode' do
    CloudProvider.provider_names.each do |provider|
      definition = CloudProvider.definition(provider)
      environment = described_class.new(provider: provider).create_environment(
        provider,
        60,
        'medium',
        region: definition[:default_region]
      )
      expect(environment.provider).to eq(provider)
      expect(environment.instance_type).to eq(definition[:compute]['medium'])
    end
  end
end
