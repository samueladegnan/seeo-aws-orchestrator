# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PolicyService do
  let(:team) { Team.create!(name: 'Acme', slug: 'acme') }

  describe '.check_provision!' do
    it 'allows valid provisioning requests' do
      expect do
        described_class.check_provision!(
          project_name: 'my-api',
          ttl_minutes: 60,
          instance_type: 't3.micro',
          team: team
        )
      end.not_to raise_error
    end

    it 'rejects TTLs that exceed the maximum' do
      expect do
        described_class.check_provision!(
          project_name: 'my-api',
          ttl_minutes: (24 * 60) + 1,
          instance_type: 't3.micro',
          team: team
        )
      end.to raise_error(PolicyService::PolicyViolation, /TTL exceeds maximum/)
    end

    it 'rejects instance types that are not on the allow list' do
      expect do
        described_class.check_provision!(
          project_name: 'my-api',
          ttl_minutes: 60,
          instance_type: 'x1.large',
          team: team
        )
      end.to raise_error(PolicyService::PolicyViolation, /not allowed/)
    end

    it 'rejects requests that violate both TTL and instance type policies' do
      expect do
        described_class.check_provision!(
          project_name: 'my-api',
          ttl_minutes: 99_999,
          instance_type: 'x1.large',
          team: team
        )
      end.to raise_error(PolicyService::PolicyViolation)
    end
  end
end
