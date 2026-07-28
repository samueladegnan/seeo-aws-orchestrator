# frozen_string_literal: true

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_options = lambda do |_event|
    {
      tenant_id: Current.team&.id,
      user_email: Current.user&.email,
      user_role: Current.role
    }.compact
  end
end
