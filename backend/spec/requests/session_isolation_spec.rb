# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Session isolation', type: :request do
  let(:api_key) { 'dev-change-me-in-production' }

  before do
    allow(SeeoConfig).to receive(:mock_aws?).and_return(true)
    MockAwsService.reset!
    Current.reset
  end

  def headers_for(session_id)
    {
      'X-API-Key' => api_key,
      'X-Session-ID' => session_id
    }
  end

  describe 'POST /environments' do
    it 'scopes created environments to the session id' do
      post '/environments', params: { project_name: 'alpha', ttl_minutes: 60, instance_type: 't3.micro' },
                            headers: headers_for('session-a')
      expect(response).to have_http_status(:created)
      alpha_id = response.parsed_body['id']

      post '/environments', params: { project_name: 'beta', ttl_minutes: 60, instance_type: 't3.micro' },
                            headers: headers_for('session-b')
      expect(response).to have_http_status(:created)

      get '/environments', headers: headers_for('session-a')
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['environments'].map { |e| e['id'] }).to eq([alpha_id])

      get '/environments', headers: headers_for('session-b')
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['environments'].map { |e| e['project_name'] }).to eq(['beta'])
    end

    it 'does not allow one session to terminate another session environment' do
      post '/environments', params: { project_name: 'alpha', ttl_minutes: 60, instance_type: 't3.micro' },
                            headers: headers_for('session-a')
      alpha_id = response.parsed_body['id']

      delete "/environments/#{alpha_id}", headers: headers_for('session-b')
      expect(response).to have_http_status(:not_found)

      get '/environments', headers: headers_for('session-a')
      expect(response.parsed_body['environments']).not_to be_empty
    end
  end
end
