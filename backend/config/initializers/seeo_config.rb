# frozen_string_literal: true

module SeeoConfig
  class << self
    def app_name
      ENV.fetch('SEEO_APP_NAME', 'SEEO - Secure Ephemeral Environment Orchestrator')
    end

    def api_key
      ENV.fetch('SEEO_API_KEY') do
        raise 'SEEO_API_KEY must be set in production' if Rails.env.production?

        'local-development-only'
      end
    end

    delegate :default_provider, to: :CloudProvider

    def allowed_providers
      ENV.fetch('SEEO_ALLOWED_PROVIDERS',
                CloudProvider.provider_names.join(',')).split(',').map(&:strip).select do |provider|
        CloudProvider.valid?(provider)
      end
    end

    def mock_mode?
      value = ENV.fetch('SEEO_MOCK_MODE', Rails.env.production? ? 'false' : 'true')
      value == 'true'
    end

    def provider_region(provider = default_provider)
      ENV.fetch("SEEO_#{provider.to_s.upcase}_REGION", CloudProvider.definition(provider)[:default_region])
    end

    def aws_region
      provider_region('aws')
    end

    def aws_profile
      ENV.fetch('AWS_PROFILE', nil).presence
    end

    def provider_project(provider = default_provider)
      ENV.fetch("SEEO_#{provider.to_s.upcase}_PROJECT", nil).presence
    end

    def provider_network_id(provider = default_provider)
      ENV.fetch("SEEO_#{provider.to_s.upcase}_NETWORK_ID", nil).presence
    end

    def provider_subnet_id(provider = default_provider)
      ENV.fetch("SEEO_#{provider.to_s.upcase}_SUBNET_ID", nil).presence
    end

    def provider_credentials(provider = default_provider)
      ENV.fetch("SEEO_#{provider.to_s.upcase}_CREDENTIALS", nil).presence
    end

    def ec2_key_pair
      ENV.fetch('SEEO_AWS_KEY_PAIR', ENV.fetch('SEEO_EC2_KEY_PAIR', nil)).presence
    end

    def ec2_ami_id
      ENV.fetch('SEEO_AWS_IMAGE_ID', ENV.fetch('SEEO_EC2_AMI_ID', nil)).presence
    end

    def ec2_instance_type
      ENV.fetch('SEEO_AWS_INSTANCE_TYPE', ENV.fetch('SEEO_EC2_INSTANCE_TYPE', 't3.micro'))
    end

    def ec2_subnet_id
      provider_subnet_id('aws') || ENV.fetch('SEEO_EC2_SUBNET_ID', nil).presence
    end

    def ec2_security_group_id
      ENV.fetch('SEEO_AWS_SECURITY_GROUP_ID', ENV.fetch('SEEO_EC2_SECURITY_GROUP_ID', nil)).presence
    end

    def iam_instance_profile
      ENV.fetch('SEEO_AWS_INSTANCE_PROFILE', ENV.fetch('SEEO_IAM_INSTANCE_PROFILE', nil)).presence
    end

    def environments_table
      ENV.fetch('SEEO_ENVIRONMENTS_TABLE', 'seeo-environments')
    end

    def secrets_secret_name
      ENV.fetch('SEEO_AWS_SECRET_NAME', ENV.fetch('SEEO_SECRETS_SECRET_NAME', 'seeo/runtime/credentials'))
    end

    def ttl_check_interval_seconds
      ENV.fetch('SEEO_TTL_CHECK_INTERVAL_SECONDS', '60').to_i
    end

    def cors_allow_origins
      ENV.fetch('CORS_ALLOW_ORIGINS', '*').split(',').map(&:strip)
    end

    def cors_allow_credentials?
      ENV.fetch('CORS_ALLOW_CREDENTIALS', 'false') == 'true'
    end

    def action_cable_allowed_origins
      ENV.fetch('ACTION_CABLE_ALLOWED_ORIGINS', cors_allow_origins.join(',')).split(',').map(&:strip)
    end

    def mock_env_limit
      ENV.fetch('SEEO_MOCK_ENV_LIMIT', '20').to_i
    end

    def mock_provisioning_delay_seconds
      ENV.fetch('SEEO_MOCK_PROVISIONING_DELAY_SECONDS', '2').to_i
    end

    def app_version
      ENV.fetch('SEEO_APP_VERSION', '0.3.0')
    end
  end
end
