# frozen_string_literal: true

require 'open3'

class PolicyService
  class PolicyViolation < StandardError; end

  DEFAULT_POLICIES = {
    'max_ttl_minutes' => 24 * 60,
    'allowed_instance_types' => %w[t3.micro t3.small t3.medium t2.micro t2.small m6i.large m5.large m5.xlarge c5.large],
    'allowed_regions' => %w[us-east-1 us-west-2 eu-west-1 ap-southeast-1],
    'max_concurrent_environments' => 10,
    'max_volume_size_gb' => 1000,
    'allowed_volume_types' => %w[gp3 io2 st1]
  }.freeze

  REGO_PATH = Rails.root.join('policies/provision.rego').freeze

  class << self
    def check_provision!(project_name:, ttl_minutes:, instance_type:, team:, region: nil, volume_size: nil, volume_type: nil)
      result = evaluate('data.seeo.provision', {
                          'project_name' => project_name,
                          'ttl_minutes' => ttl_minutes,
                          'instance_type' => instance_type,
                          'region' => region,
                          'volume_size' => volume_size,
                          'volume_type' => volume_type,
                          'team' => team_payload(team)
                        })

      return if result['allow']

      raise PolicyViolation, result['deny']&.first || 'Provisioning denied by policy'
    end

    private

    def evaluate(query, input)
      if opa_available?
        evaluate_with_opa(query, input)
      else
        evaluate_fallback(input)
      end
    end

    def evaluate_with_opa(query, input)
      args = %w[opa eval -d] + [REGO_PATH.to_s, '-f', 'value', '-I', query]
      stdout, _stderr, status = Open3.capture3(*args, stdin_data: input.to_json)

      raise 'OPA evaluation failed' unless status.success?

      JSON.parse(stdout)
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
      policies = DEFAULT_POLICIES
      violations = []

      if input['ttl_minutes'] > policies['max_ttl_minutes']
        violations << "TTL exceeds maximum of #{policies['max_ttl_minutes']} minutes"
      end

      unless policies['allowed_instance_types'].include?(input['instance_type'])
        violations << "Instance type #{input['instance_type']} is not allowed"
      end

      if input['region'].present? && !policies['allowed_regions'].include?(input['region'])
        violations << "Region #{input['region']} is not allowed"
      end

      if input['volume_type'].present? && !policies['allowed_volume_types'].include?(input['volume_type'])
        violations << "Volume type #{input['volume_type']} is not allowed"
      end

      if input['volume_size'].present? && input['volume_size'] > policies['max_volume_size_gb']
        violations << "Volume size exceeds maximum of #{policies['max_volume_size_gb']} GB"
      end

      { 'allow' => violations.empty?, 'deny' => violations }
    end

    def team_payload(team)
      return {} unless team

      {
        'id' => team.id,
        'settings' => team.settings || {}
      }
    end
  end
end
