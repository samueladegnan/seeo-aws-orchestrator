# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditLogService do
  describe '.record' do
    before do
      Current.user = User.new(email: 'test@example.com', role: 'admin')
      Current.team = nil
    end

    after { Current.reset }

    it 'writes a provider-neutral audit event' do
      expect do
        described_class.record(action: 'environment.create', target: 'demo-123', details: { provider: 'gcp' })
      end.not_to raise_error

      event = AuditEvent.order(:id).last
      expect(event.action).to eq('environment.create')
      expect(event.target).to eq('demo-123')
      expect(event.actor).to eq('test@example.com')
      expect(event.details).to eq('provider' => 'gcp')
    end
  end
end
