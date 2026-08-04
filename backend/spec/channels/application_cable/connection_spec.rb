# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:team) { Team.create!(name: 'Acme', slug: 'acme') }
  let(:user) { User.create!(team: team, email: 'operator@example.com', role: 'operator') }

  it 'rejects a forged connection token' do
    expect { connect '/cable', params: { token: 'forged-token' } }
      .to have_rejected_connection
  end

  it 'rejects a token for an unknown tenant' do
    token = Rails.application.message_verifier(CableTokenService::PURPOSE).generate(
      {
        'email' => user.email,
        'team_id' => 'missing-team',
        'role' => user.role,
        'service_account' => false,
        'session_id' => 'browser-session'
      },
      expires_in: CableTokenService::TTL
    )

    expect { connect '/cable', params: { token: token } }
      .to have_rejected_connection
  end

  it 'accepts a valid tenant token' do
    Current.user = user
    Current.team = team
    Current.role = user.role
    Current.session_id = 'browser-session'
    Current.service_account = false
    token = CableTokenService.issue

    connect '/cable', params: { token: token }

    expect(connection.current_user).to eq(user)
    expect(connection.current_team).to eq(team)
    expect(connection.current_session_id).to eq('browser-session')
  end
end
