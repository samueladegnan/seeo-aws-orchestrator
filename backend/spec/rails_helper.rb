# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
# Keep the real AwsService in tests so existing stubs continue to work.
ENV['SEEO_MOCK_AWS'] = 'false'

require_relative '../config/environment'

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.use_transactional_fixtures = true

  config.before do
    Current.reset
    allow(AuditLogService).to receive(:record)
    allow(EnvironmentChannel).to receive(:broadcast)
  end
end
