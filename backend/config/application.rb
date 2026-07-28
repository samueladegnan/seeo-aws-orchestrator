# frozen_string_literal: true

require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_record/railtie'
require 'active_model/railtie'
require 'active_job/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_cable/engine'
require 'active_support/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SeeoBackend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Rails API mode
    config.api_only = true

    # Use Solid Queue for background jobs in production.
    # Development and test run jobs inline so they boot without extra DB setup.
    config.active_job.queue_adapter = Rails.env.production? ? :solid_queue : :inline

    # Time zone
    config.time_zone = 'UTC'

    # CORS
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins SeeoConfig.cors_allow_origins
        resource '*',
                 headers: :any,
                 methods: %i[get post put patch delete options head],
                 credentials: SeeoConfig.cors_allow_credentials?
      end
    end
  end
end
