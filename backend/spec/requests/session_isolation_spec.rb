# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Session isolation', type: :request do
  let(:api_key) { 'local-development-only' }

  before do
    allow(SeeoConfig).to receive(:mock_mode?).and_return(true)
    MockCloudService.reset!
    Current.reset
  end

  def headers_for(session)
    { 'X-API-Key' => api_key, 'X-Session-Token' => session[:token] }
  end

  it 'does not allow the demo API key to reach real mode' do
    allow(SeeoConfig).to receive(:mock_mode?).and_return(false)
    session = SessionTokenService.issue

    get '/environments', headers: headers_for(session)
    expect(response).to have_http_status(:forbidden)
  end

  it 'scopes created environments to server-issued session tokens' do
    session_a = SessionTokenService.issue
    session_b = SessionTokenService.issue

    post '/environments', params: { project_name: 'alpha', provider: 'aws', ttl_minutes: 60, compute_tier: 'small' },
                          headers: headers_for(session_a)
    expect(response).to have_http_status(:created)
    alpha_id = response.parsed_body['id']

    post '/environments',
         params: {
           project_name: 'beta', provider: 'gcp', region: 'us-central1',
           ttl_minutes: 60, compute_tier: 'small'
         }, headers: headers_for(session_b)
    expect(response).to have_http_status(:created)

    get '/environments', headers: headers_for(session_a)
    expect(response.parsed_body['environments'].pluck('id')).to eq([alpha_id])

    get '/environments', headers: headers_for(session_b)
    expect(response.parsed_body['environments'].pluck('project_name')).to eq(['beta'])
  end

  it 'rejects a missing or forged session token' do
    get '/environments', headers: { 'X-API-Key' => api_key }
    expect(response).to have_http_status(:unauthorized)

    get '/environments', headers: { 'X-API-Key' => api_key, 'X-Session-Token' => 'forged-token' }
    expect(response).to have_http_status(:unauthorized)
  end
end
