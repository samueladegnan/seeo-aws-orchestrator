# frozen_string_literal: true

class CostTrackingService
  COMPUTE_RATES = {
    'aws' => { 'small' => 0.0104, 'medium' => 0.0208, 'large' => 0.0416 },
    'azure' => { 'small' => 0.0100, 'medium' => 0.0200, 'large' => 0.0830 },
    'gcp' => { 'small' => 0.0084, 'medium' => 0.0168, 'large' => 0.0335 },
    'oci' => { 'small' => 0.0075, 'medium' => 0.0150, 'large' => 0.0300 }
  }.freeze

  STORAGE_RATES = {
    'aws' => { 'balanced' => 0.08, 'performance' => 0.125, 'throughput' => 0.045 },
    'azure' => { 'balanced' => 0.075, 'performance' => 0.15, 'throughput' => 0.05 },
    'gcp' => { 'balanced' => 0.10, 'performance' => 0.17, 'throughput' => 0.04 },
    'oci' => { 'balanced' => 0.0255, 'performance' => 0.0425, 'throughput' => 0.01 }
  }.freeze

  DEFAULT_RATE = 0.02
  DEFAULT_STORAGE_RATE = 0.08

  class << self
    def estimate(provider:, compute_tier:, ttl_minutes:, volume_size: nil, storage_tier: 'balanced')
      compute_rate = COMPUTE_RATES.dig(provider.to_s, compute_tier.to_s) || DEFAULT_RATE
      storage_rate = STORAGE_RATES.dig(provider.to_s, storage_tier.to_s) || DEFAULT_STORAGE_RATE
      hours = ttl_minutes.to_f / 60.0
      compute_cost = compute_rate * hours
      storage_cost = volume_size.to_i.positive? ? storage_rate * volume_size.to_i * hours / 730.0 : 0.0
      (compute_cost + storage_cost).round(4)
    end

    def summary(environments)
      total = environments.sum { |environment| environment_cost(environment) }
      { total: total.round(4), currency: 'USD', environments_count: environments.size }
    end

    def environment_cost(environment)
      estimate(
        provider: environment.provider,
        compute_tier: environment.compute_tier || tier_for_shape(environment.instance_type),
        ttl_minutes: environment.ttl_minutes,
        volume_size: environment.volume_size,
        storage_tier: environment.storage_tier || 'balanced'
      )
    end

    private

    def tier_for_shape(shape)
      return 'small' if shape.blank?
      return 'large' if shape.to_s.match?(/large|medium|4$/i)
      return 'medium' if shape.to_s.match?(/small|2$/i)

      'small'
    end
  end
end
