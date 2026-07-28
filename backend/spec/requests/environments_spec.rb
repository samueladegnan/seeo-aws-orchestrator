# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Environments API', type: :request do
  let(:api_key) { 'dev-change-me-in-production' }
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
      allow_any_instance_of(AwsService).to receive(:list_environments).and_return([])

      get '/environments', headers: { 'Authorization' => "Bearer #{AuthorizationService.issue_token(admin)}" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('environments', 'cost')
    end
  end

  describe 'POST /environments' do
    it 'creates an environment for an operator' do
      allow_any_instance_of(AwsService).to receive(:create_environment).and_return(
        Environment.new(
          id: 'api-123',
          project_name: 'api',
          status: 'provisioning',
          created_at: Time.current,
          expires_at: 1.hour.from_now,
          ttl_minutes: 60
        )
      )

      post '/environments',
           params: { project_name: 'api', ttl_minutes: 60 },
           headers: { 'Authorization' => "Bearer #{AuthorizationService.issue_token(admin)}" }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['project_name']).to eq('api')
    end

    it 'denies viewers' do
      viewer = User.create!(team: team, email: 'viewer@example.com', role: 'viewer')

      post '/environments',
           params: { project_name: 'api', ttl_minutes: 60 },
           headers: { 'Authorization' => "Bearer #{AuthorizationService.issue_token(viewer)}" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE /environments/:id' do
    it 'terminates an environment for an operator' do
      allow_any_instance_of(AwsService).to receive(:terminate_environment).and_return(
        Environment.new(
          id: 'api-123',
          project_name: 'api',
          status: 'terminated',
          created_at: Time.current,
          expires_at: 1.hour.from_now,
          ttl_minutes: 60
        )
      )

      delete '/environments/api-123',
             headers: { 'Authorization' => "Bearer #{AuthorizationService.issue_token(admin)}" }
      expect(response).to have_http_status(:ok)
    end
  end
end
