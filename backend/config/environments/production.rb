# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Cache
  config.action_controller.perform_caching = true

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL
  config.force_ssl = true

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new($stdout)

  # Use the lowest log level to ensure availability of diagnostic information
  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info').to_sym

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Enable DNS rebinding protection and other Host header attacks.
  # For this demo app we allow all hosts so the Render URL works out of the box.
  if ENV['RAILS_ALLOW_ALL_HOSTS'] == 'true'
    config.hosts.clear
    config.action_cable.allowed_request_origins = [/.*/]
  else
    config.hosts = ENV.fetch('RAILS_ALLOWED_HOSTS', '.localhost').split(',').map(&:strip)
  end
end
