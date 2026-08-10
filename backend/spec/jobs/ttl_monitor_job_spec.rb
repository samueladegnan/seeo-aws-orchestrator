# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TtlMonitorJob, type: :job do
  it 'scans and terminates expired environments for every enabled provider' do
    expired = Environment.new(
      id: 'expired-123', project_name: 'stale-api', provider: 'gcp', status: 'ready',
      created_at: 2.hours.ago, expires_at: 5.minutes.ago, ttl_minutes: 60,
      compute_tier: 'small', region: 'us-central1'
    )
    service = instance_double(MockCloudService, list_expired_environments: [expired])
    allow(SeeoConfig).to receive(:allowed_providers).and_return(%w[aws gcp])
    allow(CloudService).to receive(:for).with(provider: 'aws').and_return(instance_double(MockCloudService, list_expired_environments: []))
    allow(CloudService).to receive(:for).with(provider: 'gcp').and_return(service)
    allow(service).to receive(:force_terminate_environment).with(expired.id)

    described_class.new.perform

    expect(service).to have_received(:force_terminate_environment).with(expired.id)
  end

  it 'continues when a configured provider is unavailable' do
    allow(SeeoConfig).to receive(:allowed_providers).and_return(%w[azure])
    allow(CloudService).to receive(:for).with(provider: 'azure').and_raise(CloudAdapter::UnsupportedProviderError, 'not configured')

    expect { described_class.new.perform }.not_to raise_error
  end
end
