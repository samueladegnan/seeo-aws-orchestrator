# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthorizationService do
  let(:team) { Team.create!(name: 'Acme', slug: 'acme') }
  let(:user) { User.create!(team: team, email: 'admin@example.com', role: 'admin') }

  after do
    Current.reset
  end

  describe '.authenticate_api_key!' do
    it 'sets the current user to a service admin for a valid key' do
      described_class.authenticate_api_key!(SeeoConfig.api_key)
      expect(Current.user.email).to eq('service@seeo.local')
      expect(Current.role).to eq('admin')
    end

    it 'raises an error for an invalid key' do
      expect do
        described_class.authenticate_api_key!('wrong-key')
      end.to raise_error(AuthorizationService::AuthenticationError)
    end
  end

  describe '.issue_token and .authenticate_token!' do
    it 'issues a token that authenticates the user' do
      token = described_class.issue_token(user)
      expect(token).to be_a(String)

      described_class.authenticate_token!(token)
      expect(Current.user.email).to eq('admin@example.com')
      expect(Current.team).to eq(team)
      expect(Current.role).to eq('admin')
    end

    it 'rejects an invalid token' do
      expect do
        described_class.authenticate_token!('not-a-token')
      end.to raise_error(AuthorizationService::AuthenticationError)
    end
  end

  describe '.current_summary' do
    it 'returns a hash of the current context' do
      Current.user = user
      Current.team = team
      Current.role = 'admin'

      summary = described_class.current_summary
      expect(summary).to include(:user_id, :team_id, :role)
      expect(summary[:role]).to eq('admin')
    end
  end
end
