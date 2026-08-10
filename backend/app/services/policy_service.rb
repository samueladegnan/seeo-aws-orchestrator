# frozen_string_literal: true

require 'open3'

class PolicyService
  class PolicyViolation < StandardError; end

  DEFAULT_POLICIES = {
    'max_ttl_minutes' => 24 * 60,
    'allowed_compute_tiers' => CloudProvider::TIERS,
    'max_concurrent_environments' => 10,
    'max_volume_size_gb' => 1000,
    'allowed_storage_tiers' => CloudProvider::STORAGE_TIERS
  }.freeze

  REGO_PATH = Rails.root.join('policies/provision.rego').freeze

  class << self
    def check_provision!(**options)
      result = evaluate('data.seeo.allow', provision_input(options))
      return if result['allow']

      raise PolicyViolation, result['deny']&.first || 'Provisioning denied by policy'
    end

    def check_concurrency!(active_count)
      limit = DEFAULT_POLICIES['max_concurrent_environments']
      return if active_count < limit

      raise PolicyViolation, "Concurrent environment limit of #{limit} reached"
    end

    private

    def evaluate(query, input)
      opa_available? ? evaluate_with_opa(query, input) : evaluate_fallback(input)
    end

    def evaluate_with_opa(query, input)
      args = %w[opa eval -d] + [REGO_PATH.to_s, '-f', 'value', '-I', query]
      stdout, _stderr, status = Open3.capture3(*args, stdin_data: input.to_json)
      raise 'OPA evaluation failed' unless status.success?

      parsed = JSON.parse(stdout)
      parsed.is_a?(Hash) ? parsed : { 'allow' => parsed == true, 'deny' => parsed == true ? [] : ['Provisioning denied by policy'] }
    rescue StandardError => e
      Rails.logger.warn "[PolicyService] OPA evaluation failed: #{e.message}. Falling back to built-in policies."
      evaluate_fallback(input)
    end

    def opa_available?
      return @opa_available unless @opa_available.nil?

      _stdout, _stderr, status = Open3.capture3('which opa')
      @opa_available = status.success?
    end

    def evaluate_fallback(input)
      violations = []
      provider = input['provider'].to_s
      definition = CloudProvider.definition(provider) if CloudProvider.valid?(provider)

      violations << "Provider #{provider} is not allowed" unless SeeoConfig.allowed_providers.include?(provider)
      violations << 'TTL must be at least 1 minute' if input['ttl_minutes'].to_i < 1
      violations << "TTL exceeds maximum of #{DEFAULT_POLICIES['max_ttl_minutes']} minutes" if input['ttl_minutes'].to_i > DEFAULT_POLICIES['max_ttl_minutes']
      violations << "Compute tier #{input['compute_tier']} is not allowed" unless DEFAULT_POLICIES['allowed_compute_tiers'].include?(input['compute_tier'])
      if input['region'].present? && (!definition || !definition[:regions].key?(input['region']))
        violations << "Region #{input['region']} is not allowed for #{provider}"
      end
      if input['storage_tier'].present? && !DEFAULT_POLICIES['allowed_storage_tiers'].include?(input['storage_tier'])
        violations << "Storage tier #{input['storage_tier']} is not allowed"
      end
      if input['volume_size'].present? && input['volume_size'].to_i > DEFAULT_POLICIES['max_volume_size_gb']
        violations << "Volume size exceeds maximum of #{DEFAULT_POLICIES['max_volume_size_gb']} GB"
      end
      if input['active_environment_count'].to_i >= DEFAULT_POLICIES['max_concurrent_environments']
        violations << "Concurrent environment limit of #{DEFAULT_POLICIES['max_concurrent_environments']} reached"
      end

      { 'allow' => violations.empty?, 'deny' => violations }
    end

    def provision_input(options)
      {
        'project_name' => options[:project_name],
        'provider' => options[:provider],
        'ttl_minutes' => options[:ttl_minutes],
        'compute_tier' => options[:compute_tier],
        'region' => options[:region],
        'volume_size' => options[:volume_size].presence || 10,
        'storage_tier' => options[:storage_tier].presence || 'balanced',
        'active_environment_count' => options[:active_environment_count].to_i,
        'team' => team_payload(options[:team])
      }
    end

    def team_payload(team)
      return {} unless team

      { 'id' => team.id, 'settings' => team.settings || {} }
    end
  end
end
