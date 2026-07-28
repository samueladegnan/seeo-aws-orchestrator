# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnvironmentsController, type: :controller do
  let(:api_key) { 'dev-change-me-in-production' }
  let(:headers) { { 'X-API-Key' => api_key } }

  before do
    request.headers.merge!(headers)
  end

  describe 'authentication' do
    it 'returns unauthorized when the API key is missing' do
      request.headers['X-API-Key'] = nil
      get :index
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized when the API key is invalid' do
      request.headers['X-API-Key'] = 'not-the-right-key'
      get :index
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET #index' do
    it 'returns a list of environments' do
      allow_any_instance_of(AwsService).to receive(:list_environments).and_return([])
      get :index
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({ 'environments' => [],
                                           'cost' => { 'currency' => 'USD', 'environments_count' => 0,
                                                       'total' => 0.0 } })
    end
  end

  describe 'POST #create with options' do
    let(:environment) do
      Environment.new(
        id: 'demo-123',
        project_name: 'my-api',
        status: 'provisioning',
        created_at: Time.current,
        expires_at: 1.hour.from_now,
        ttl_minutes: 60,
        region: 'us-east-1'
      )
    end

    it 'passes region and volume options to the service' do
      expect_any_instance_of(AwsService).to receive(:create_environment).with(
        'my-api', 60, 'm6i.large',
        hash_including(region: 'eu-west-1', volume_size: 100, volume_type: 'io2')
      ).and_return(environment)

      post :create, params: {
        project_name: 'my-api',
        ttl_minutes: 60,
        instance_type: 'm6i.large',
        region: 'eu-west-1',
        volume_size: 100,
        volume_type: 'io2'
      }
      expect(response).to have_http_status(:created)
    end
  end

  describe 'GET #show' do
    let(:environment) do
      Environment.new(
        id: 'test-123',
        project_name: 'demo',
        status: 'ready',
        created_at: Time.current,
        expires_at: 1.hour.from_now,
        ttl_minutes: 60,
        region: 'us-east-1'
      )
    end

    it 'returns the environment' do
      allow_any_instance_of(AwsService).to receive(:refresh_environment_state).with('test-123').and_return(environment)
      get :show, params: { id: 'test-123' }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['project_name']).to eq('demo')
    end

    it 'returns 404 when not found' do
      allow_any_instance_of(AwsService).to receive(:refresh_environment_state).and_return(nil)
      get :show, params: { id: 'missing' }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    let(:environment) do
      Environment.new(
        id: 'demo-123',
        project_name: 'my-api',
        status: 'provisioning',
        created_at: Time.current,
        expires_at: 1.hour.from_now,
        ttl_minutes: 60,
        region: 'us-east-1'
      )
    end

    it 'creates an environment' do
      allow_any_instance_of(AwsService).to receive(:create_environment).and_return(environment)
      post :create, params: { project_name: 'my-api', ttl_minutes: 60, instance_type: 't3.micro' }
      expect(response).to have_http_status(:created)
      expect(response.parsed_body['project_name']).to eq('my-api')
    end
  end

  describe 'DELETE #destroy' do
    let(:environment) do
      Environment.new(
        id: 'demo-123',
        project_name: 'my-api',
        status: 'terminated',
        created_at: Time.current,
        expires_at: 1.hour.from_now,
        ttl_minutes: 60,
        region: 'us-east-1'
      )
    end

    it 'terminates the environment' do
      allow_any_instance_of(AwsService).to receive(:terminate_environment).and_return(environment)
      delete :destroy, params: { id: 'demo-123' }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['status']).to eq('terminated')
    end
  end

  describe 'POST #refresh' do
    let(:environment) do
      Environment.new(
        id: 'demo-123',
        project_name: 'my-api',
        status: 'ready',
        created_at: Time.current,
        expires_at: 1.hour.from_now,
        ttl_minutes: 60,
        region: 'us-east-1'
      )
    end

    it 'refreshes the environment state' do
      allow_any_instance_of(AwsService).to receive(:refresh_environment_state).and_return(environment)
      post :refresh, params: { id: 'demo-123' }
      expect(response).to have_http_status(:ok)
    end
  end
end
