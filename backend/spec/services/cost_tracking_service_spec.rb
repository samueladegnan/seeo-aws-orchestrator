# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CostTrackingService do
  describe '.estimate' do
    it 'calculates the cost for a t3.micro instance running one hour' do
      expect(described_class.estimate(instance_type: 't3.micro', ttl_minutes: 60)).to eq(0.0104)
    end

    it 'uses the default rate for unknown instance types' do
      expect(described_class.estimate(instance_type: 'z1.large', ttl_minutes: 60)).to eq(0.05)
    end

    it 'returns a value proportional to TTL' do
      expect(described_class.estimate(instance_type: 't3.micro', ttl_minutes: 30)).to eq(0.0052)
    end

    it 'adds storage cost when volume options are provided' do
      cost = described_class.estimate(instance_type: 't3.micro', ttl_minutes: 730, volume_size: 100, volume_type: 'gp3')
      # 730 minutes = ~12.33 hours. compute = 0.0104 * 12.333 = ~0.1283. storage = 0.08 * 100 * 12.333 / 730 = ~0.1352. total ~0.2635
      expect(cost).to be > 0.13
    end
  end

  describe '.summary' do
    let(:envs) do
      [
        Environment.new(id: 'a', instance_type: 't3.micro', ttl_minutes: 60, volume_size: 10, volume_type: 'gp3'),
        Environment.new(id: 'b', instance_type: 't3.small', ttl_minutes: 60, volume_size: 10, volume_type: 'gp3')
      ]
    end

    it 'returns the total estimated cost and count' do
      summary = described_class.summary(envs)
      expect(summary[:currency]).to eq('USD')
      expect(summary[:environments_count]).to eq(2)
      expect(summary[:total]).to be > 0.0312
    end

    it 'returns zero for an empty list' do
      summary = described_class.summary([])
      expect(summary[:total]).to eq(0.0)
      expect(summary[:environments_count]).to eq(0)
    end
  end

  describe '.environment_cost' do
    it 'returns the per-environment cost' do
      env = Environment.new(id: 'a', instance_type: 't3.micro', ttl_minutes: 60, volume_size: 20, volume_type: 'gp3')
      expect(described_class.environment_cost(env)).to be_a(Numeric)
    end
  end
end
