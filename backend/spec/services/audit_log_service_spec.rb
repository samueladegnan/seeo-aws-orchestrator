# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditLogService do
  describe '.record' do
    before do
      Current.user = User.new(email: 'test@example.com', role: 'admin')
      Current.team = nil
    end

    after do
      Current.reset
    end

    it 'builds a DynamoDB item with the correct fields' do
      item = described_class.send(:item_for, 'environment.create', 'demo-123', { project_name: 'demo' })

      expect(item['action']).to eq('environment.create')
      expect(item['target']).to eq('demo-123')
      expect(item['actor']).to eq('test@example.com')
      expect(item['details']).to eq('{"project_name":"demo"}')
      expect(item['team_id']).to eq('service')
      expect(item).to have_key('id')
      expect(item).to have_key('timestamp')
    end

    it 'uses the configured audit log table' do
      expect(described_class.send(:table_name)).to eq('seeo-audit-logs')
    end

    it 'falls back to the default audit log table when the env var is not set' do
      allow(ENV).to receive(:fetch).with('SEEO_AUDIT_LOG_TABLE', 'seeo-audit-logs').and_return('seeo-audit-logs')
      expect(described_class.send(:table_name)).to eq('seeo-audit-logs')
    end
  end
end
