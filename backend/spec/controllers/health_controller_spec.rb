# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthController, type: :controller do
  describe 'GET #index' do
    it 'returns ok status' do
      get :index
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('status' => 'ok', 'version' => '0.1.0', 'mock_mode' => false)
    end
  end
end
