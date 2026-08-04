# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnvironmentChannel, type: :channel do
  let(:team) { Team.create!(name: 'Acme', slug: 'acme') }
  let(:user) { User.create!(team: team, email: 'operator@example.com', role: 'operator') }

  before do
    Current.user = user
    Current.team = team
    Current.role = user.role
    Current.session_id = 'browser-session'
    Current.service_account = false
  end

  it 'issues a signed token containing the tenant identity' do
    token = CableTokenService.issue
    payload = CableTokenService.verify!(token)

    expect(payload).to include(
      'email' => user.email,
      'team_id' => team.id,
      'role' => 'operator',
      'session_id' => 'browser-session',
      'service_account' => false
    )
  end

  it 'rejects a tampered token' do
    token = CableTokenService.issue
    tampered = "#{token}tampered"

    expect { CableTokenService.verify!(tampered) }
      .to raise_error(CableTokenService::InvalidToken)
  end

  it 'derives the team stream from the authenticated tenant' do
    expect(Environment.new(team_id: team.id, session_id: 'other').stream_key).to eq("team_#{team.id}")
  end

  describe 'subscription authorization' do
    before do
      stub_connection(
        current_user: user,
        current_team: team,
        current_session_id: 'browser-session',
        current_service_account: false
      )
    end

    it 'confirms a subscription to the authenticated team stream' do
      subscribe(stream_key: "team_#{team.id}")

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("team_#{team.id}")
    end

    it 'rejects a subscription to a different team stream' do
      subscribe(stream_key: 'team-other-tenant')

      expect(subscription).to be_rejected
    end
  end

  describe 'session subscription authorization' do
    before do
      service_user = User.new(email: 'service@seeo.local', role: 'admin')
      stub_connection(
        current_user: service_user,
        current_team: nil,
        current_session_id: 'browser-session',
        current_service_account: true
      )
    end

    it 'confirms a subscription to the authenticated session stream' do
      subscribe(stream_key: 'session_browser-session')

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from('session_browser-session')
    end

    it 'rejects a subscription to a different session stream' do
      subscribe(stream_key: 'session_other-browser')

      expect(subscription).to be_rejected
    end
  end
end
