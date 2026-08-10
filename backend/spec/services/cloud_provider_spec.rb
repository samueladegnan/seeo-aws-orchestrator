# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CloudProvider do
  it 'contains all day-one providers' do
    expect(described_class.provider_names).to match_array(%w[aws azure gcp oci])
  end

  it 'rejects a region from another provider' do
    expect { described_class.region('aws', 'eastus') }.to raise_error(ArgumentError, /not available in aws/)
  end

  it 'maps normalized tiers to native resource names' do
    expect(described_class.compute_shape('gcp', 'medium')).to eq('e2-small')
    expect(described_class.storage_shape('oci', 'performance')).to eq('higher_performance')
  end
end
