# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
ENV['SEEO_MOCK_MODE'] = 'true'
ENV['SEEO_ALLOWED_PROVIDERS'] = 'aws,azure,gcp,oci'

require_relative '../config/environment'

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.use_transactional_fixtures = true

  config.before do
    Current.reset
    allow(EnvironmentChannel).to receive(:broadcast)
  end
end
