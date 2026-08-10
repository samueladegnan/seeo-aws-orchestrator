# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Environments API', type: :request do
  let(:team) { Team.create!(name: 'Acme', slug: 'acme') }
  let(:project) { Project.create!(team: team, name: 'api', slug: 'api') }
  let(:admin) { User.create!(team: team, email: 'admin@example.com', role: 'admin') }

  before { project; admin }

  it 'requires authentication' do
    get '/environments'
    expect(response).to have_http_status(:unauthorized)
  end

  it 'lists environments for a tenant user' do
    get '/environments', headers: auth_headers(admin)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('environments', 'cost')
  end

  it 'creates a provider-specific environment for an operator' do
    post '/environments',
         params: { project_name: 'api', provider: 'gcp', region: 'us-central1', compute_tier: 'small', ttl_minutes: 60 },
         headers: auth_headers(admin)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('provider' => 'gcp', 'compute_tier' => 'small')
  end

  it 'denies viewers' do
    viewer = User.create!(team: team, email: 'viewer@example.com', role: 'viewer')

    post '/environments', params: { project_name: 'api', provider: 'aws', ttl_minutes: 60 }, headers: auth_headers(viewer)
    expect(response).to have_http_status(:forbidden)
  end

  def auth_headers(user)
    { 'Authorization' => "Bearer #{AuthorizationService.issue_token(user)}" }
  end
end
