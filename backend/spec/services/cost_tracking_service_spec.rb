# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CostTrackingService do
  describe '.estimate' do
    it 'estimates provider-specific compute and storage' do
      aws = described_class.estimate(provider: 'aws', compute_tier: 'small', ttl_minutes: 60, volume_size: 10, storage_tier: 'balanced')
      gcp = described_class.estimate(provider: 'gcp', compute_tier: 'small', ttl_minutes: 60, volume_size: 10, storage_tier: 'balanced')

      expect(aws).to be > gcp
      expect(aws).to be > 0
    end
  end

  describe '.summary' do
    it 'summarizes environments across providers' do
      environments = [
        Environment.new(provider: 'aws', compute_tier: 'small', storage_tier: 'balanced', ttl_minutes: 60),
        Environment.new(provider: 'oci', compute_tier: 'medium', storage_tier: 'performance', ttl_minutes: 120)
      ]

      summary = described_class.summary(environments)
      expect(summary[:currency]).to eq('USD')
      expect(summary[:environments_count]).to eq(2)
      expect(summary[:total]).to be > 0
    end
  end
end
