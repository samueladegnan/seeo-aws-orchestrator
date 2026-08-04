# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Environments API', type: :request do
  let(:api_key) { 'local-development-only' }
  let(:team) { Team.create!(name: 'Acme', slug: 'acme') }
  let(:project) { Project.create!(team: team, name: 'api', slug: 'api') }
  let(:admin) { User.create!(team: team, email: 'admin@example.com', role: 'admin') }

  before do
    team
    project
    admin
  end

  describe 'GET /environments' do
    it 'requires authentication' do
      get '/environments'
      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists environments for a tenant user' do
      allow_aws_service(:list_environments, [])

      get '/environments', headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('environments', 'cost')
    end

    it 'filters by status' do
      allow_aws_service(:list_environments, 'ready', [])

      get '/environments?status=ready', headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /environments' do
    it 'creates an environment for an operator' do
      environment = Environment.new(
        id: 'api-123',
        project_name: 'api',
        status: 'provisioning',
        created_at: Time.current,
        expires_at: 1.hour.from_now,
        ttl_minutes: 60,
        region: 'us-east-1'
      )
      allow_aws_service(:create_environment, environment)

      post '/environments',
           params: { project_name: 'api', ttl_minutes: 60 },
           headers: auth_headers(admin)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['project_name']).to eq('api')
    end

    it 'denies viewers' do
      viewer = User.create!(team: team, email: 'viewer@example.com', role: 'viewer')

      post '/environments',
           params: { project_name: 'api', ttl_minutes: 60 },
           headers: auth_headers(viewer)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /environments/:id' do
    it 'terminates an environment for an operator' do
      environment = Environment.new(
        id: 'api-123',
        project_name: 'api',
        status: 'terminated',
        created_at: Time.current,
        expires_at: 1.hour.from_now,
        ttl_minutes: 60,
        region: 'us-east-1'
      )
      allow_aws_service(:terminate_environment, environment)

      delete '/environments/api-123', headers: auth_headers(admin)
      expect(response).to have_http_status(:ok)
    end
  end

  def auth_headers(user)
    { 'Authorization' => "Bearer #{AuthorizationService.issue_token(user)}" }
  end

  def allow_aws_service(method, *args, return_value)
    aws_mock = instance_double(AwsService)
    allow(AwsService).to receive(:new).and_return(aws_mock)
    allow(aws_mock).to receive(:active_environment_count).and_return(0)
    if args.empty?
      allow(aws_mock).to receive(method).and_return(return_value)
    else
      allow(aws_mock).to receive(method).with(*args).and_return(return_value)
    end
  end
end
