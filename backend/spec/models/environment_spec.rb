# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Environment, type: :model do
  let(:valid_attributes) do
    {
      id: 'demo-123', project_name: 'my-api', provider: 'azure', status: 'ready',
      created_at: Time.current, expires_at: 1.hour.from_now, ttl_minutes: 60,
      compute_tier: 'small', storage_tier: 'balanced', region: 'eastus'
    }
  end

  it 'is valid with required attributes' do
    expect(described_class.new(valid_attributes)).to be_valid
  end

  it 'is invalid without required attributes' do
    expect(described_class.new).not_to be_valid
  end

  it 'rejects an unsupported provider' do
    expect(described_class.new(valid_attributes.merge(provider: 'unknown'))).not_to be_valid
  end

  it 'maps normalized tiers to provider-native shapes' do
    environment = described_class.new(valid_attributes)
    expect(environment.compute_shape).to eq('Standard_B1s')
    expect(environment.storage_shape).to eq('StandardSSD_LRS')
  end

  describe '#expired?' do
    it 'returns true when expires_at is in the past' do
      expect(described_class.new(valid_attributes.merge(expires_at: 1.minute.ago)).expired?).to be true
    end

    it 'returns false when expires_at is in the future' do
      expect(described_class.new(valid_attributes).expired?).to be false
    end
  end
end
