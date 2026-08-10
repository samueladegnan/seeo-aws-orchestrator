# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AwsService do
  let(:service) { described_class.new(provider: 'aws') }

  it 'uses the AWS provider catalog for normalized shapes' do
    expect(service.provider).to eq('aws')
    expect(CloudProvider.compute_shape('aws', 'small')).to eq('t3.micro')
    expect(CloudProvider.storage_shape('aws', 'balanced')).to eq('gp3')
  end

  it 'requires cleanup context before scanning expired AWS records' do
    expect { service.list_expired_environments }
      .to raise_error(AuthorizationService::AuthenticationError, /Cleanup context required/)
  end
end
