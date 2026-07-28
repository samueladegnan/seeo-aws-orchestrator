# frozen_string_literal: true

module SeeoConfig
  class << self
    def app_name
      ENV.fetch('SEEO_APP_NAME', 'SEEO - Secure Ephemeral Environment Orchestrator')
    end

    def api_key
      ENV.fetch('SEEO_API_KEY', 'dev-change-me-in-production')
    end

    def aws_region
      ENV.fetch('AWS_REGION', 'us-east-1')
    end

    def aws_profile
      ENV.fetch('AWS_PROFILE', nil).presence
    end

    def ec2_key_pair
      ENV.fetch('SEEO_EC2_KEY_PAIR', nil).presence
    end

    def ec2_ami_id
      ENV.fetch('SEEO_EC2_AMI_ID', nil).presence
    end

    def ec2_instance_type
      ENV.fetch('SEEO_EC2_INSTANCE_TYPE', 't3.micro')
    end

    def ec2_subnet_id
      ENV.fetch('SEEO_EC2_SUBNET_ID', nil).presence
    end

    def ec2_security_group_id
      ENV.fetch('SEEO_EC2_SECURITY_GROUP_ID', nil).presence
    end

    def iam_instance_profile
      ENV.fetch('SEEO_IAM_INSTANCE_PROFILE', nil).presence
    end

    def environments_table
      ENV.fetch('SEEO_ENVIRONMENTS_TABLE', 'seeo-environments')
    end

    def secrets_secret_name
      ENV.fetch('SEEO_SECRETS_SECRET_NAME', 'seeo/runtime/credentials')
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

    def mock_aws?
      value = ENV.fetch('SEEO_MOCK_AWS', Rails.env.production? ? 'false' : 'true')
      value == 'true'
    end

    def mock_env_limit
      ENV.fetch('SEEO_MOCK_ENV_LIMIT', '20').to_i
    end

    def mock_provisioning_delay_seconds
      ENV.fetch('SEEO_MOCK_PROVISIONING_DELAY_SECONDS', '2').to_i
    end
  end
end
