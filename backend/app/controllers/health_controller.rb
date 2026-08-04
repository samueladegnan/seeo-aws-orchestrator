# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :authenticate_request!, only: [:index]
  skip_before_action :require_session_token!, only: [:index]

  def index
    render json: { status: 'ok', version: '0.1.0', mock_mode: SeeoConfig.mock_aws? }
  end
end
