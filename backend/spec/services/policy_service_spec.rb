# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PolicyService do
  let(:team) { Team.create!(name: 'Acme', slug: 'acme') }

  def valid_request(overrides = {})
    {
      project_name: 'my-api', provider: 'gcp', ttl_minutes: 60, compute_tier: 'small',
      region: 'us-central1', storage_tier: 'balanced', volume_size: 10, team: team,
      active_environment_count: 0
    }.merge(overrides)
  end

  it 'allows a valid provider-specific request' do
    expect { described_class.check_provision!(**valid_request) }.not_to raise_error
  end

  it 'rejects TTLs that exceed the maximum' do
    expect { described_class.check_provision!(**valid_request(ttl_minutes: 1441)) }
      .to raise_error(PolicyService::PolicyViolation, /TTL exceeds maximum/)
  end

  it 'rejects a region belonging to another provider' do
    expect { described_class.check_provision!(**valid_request(provider: 'azure', region: 'us-central1')) }
      .to raise_error(PolicyService::PolicyViolation, /not allowed for azure/)
  end

  it 'rejects unsupported compute tiers' do
    expect { described_class.check_provision!(**valid_request(compute_tier: 'xlarge')) }
      .to raise_error(PolicyService::PolicyViolation, /not allowed/)
  end
end
