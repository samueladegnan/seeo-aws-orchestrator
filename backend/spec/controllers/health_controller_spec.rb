# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthController, type: :controller do
  describe 'GET #index' do
    it 'returns the multi-cloud runtime catalog' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'status' => 'ok',
        'version' => '0.3.0',
        'mock_mode' => true,
        'default_provider' => 'aws'
      )
      expect(response.parsed_body['providers'].pluck('id')).to include('aws', 'azure', 'gcp', 'oci')
    end
  end
end
