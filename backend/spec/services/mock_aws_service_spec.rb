# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MockAwsService do
  let(:service) { described_class.new(provider: 'aws') }

  before do
    Current.reset
    Current.session_id = 'test-session'
    described_class.reset!
  end

  it 'preserves the AWS wrapper while returning normalized fields' do
    environment = service.create_environment('demo', 60, 't3.micro', region: 'us-east-1', volume_type: 'gp3')

    expect(environment.provider).to eq('aws')
    expect(environment.compute_tier).to eq('small')
    expect(environment.storage_tier).to eq('balanced')
    expect(environment.instance_type).to eq('t3.micro')
    expect(environment.volume_type).to eq('gp3')
  end
end
