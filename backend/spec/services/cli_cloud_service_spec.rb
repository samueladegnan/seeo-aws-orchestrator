# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CliCloudService do
  let(:service) { described_class.new(provider: 'gcp') }

  it 'requires provider configuration before real lifecycle calls' do
    expect { service.create_environment('demo', 60, 'small', region: 'us-central1') }
      .to raise_error(CloudAdapter::UnsupportedProviderError, /missing configuration/)
  end
end
