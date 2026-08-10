# frozen_string_literal: true

class HealthController < ApplicationController
  skip_before_action :authenticate_request!, only: [:index]
  skip_before_action :require_session_token!, only: [:index]

  def index
    render json: {
      status: 'ok',
      version: SeeoConfig.app_version,
      mock_mode: SeeoConfig.mock_mode?,
      default_provider: SeeoConfig.default_provider,
      providers: SeeoConfig.allowed_providers.map { |provider| { id: provider, label: CloudProvider.definition(provider)[:label] } }
    }
  end
end
