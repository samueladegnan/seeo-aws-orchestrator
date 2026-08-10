# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnvironmentsController, type: :controller do
  let(:api_key) { 'local-development-only' }
  let(:session_token) { SessionTokenService.issue[:token] }
  let(:headers) { { 'X-API-Key' => api_key, 'X-Session-Token' => session_token } }

  before do
    allow(SeeoConfig).to receive(:mock_mode?).and_return(true)
    request.headers.merge!(headers)
  end

  it 'returns unauthorized when the API key is missing' do
    request.headers['X-API-Key'] = nil
    get :index
    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns a list of provider-neutral environments' do
    service = instance_double(MockCloudService, list_environments: [])
    allow(CloudService).to receive(:for).and_return(service)

    get :index

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('environments', 'cost')
  end

  it 'passes provider and normalized tiers to the adapter' do
    environment = Environment.new(
      id: 'demo-123', project_name: 'my-api', provider: 'gcp', status: 'provisioning',
      created_at: Time.current, expires_at: 1.hour.from_now, ttl_minutes: 60,
      compute_tier: 'small', region: 'us-central1'
    )
    service = instance_double(MockCloudService, active_environment_count: 0)
    allow(CloudService).to receive(:for).with(provider: 'gcp').and_return(service)
    allow(service).to receive(:create_environment).with(
      'my-api', 60, 'small', hash_including(provider: 'gcp', region: 'us-central1')
    ).and_return(environment)

    post :create, params: {
      project_name: 'my-api', provider: 'gcp', ttl_minutes: 60,
      compute_tier: 'small', region: 'us-central1'
    }

    expect(response).to have_http_status(:created)
    expect(response.parsed_body['provider']).to eq('gcp')
  end
end
