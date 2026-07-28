# frozen_string_literal: true

class CostTrackingService
  # Approximate on-demand hourly rates for us-east-1 (USD).
  RATES = {
    't3.micro' => 0.0104,
    't3.small' => 0.0208,
    't3.medium' => 0.0416,
    't3.large' => 0.0832,
    't2.micro' => 0.0116,
    't2.small' => 0.0230,
    't2.medium' => 0.0464,
    'm5.large' => 0.0960,
    'm5.xlarge' => 0.1920,
    'c5.large' => 0.0850
  }.freeze

  # Storage rates per GB-month (USD).
  STORAGE_RATES = {
    'gp3' => 0.08,
    'io2' => 0.125,
    'st1' => 0.045
  }.freeze

  DEFAULT_RATE = 0.05
  DEFAULT_STORAGE_RATE = 0.08

  class << self
    def estimate(instance_type:, ttl_minutes:, volume_size: nil, volume_type: 'gp3')
      rate = RATES.fetch(instance_type, DEFAULT_RATE)
      hours = ttl_minutes.to_f / 60.0
      compute_cost = rate * hours
      storage_cost = storage_estimate(volume_size: volume_size, volume_type: volume_type, ttl_minutes: ttl_minutes)
      (compute_cost + storage_cost).round(4)
    end

    def storage_estimate(volume_size:, volume_type:, ttl_minutes:)
      return 0.0 if volume_size.blank? || volume_size.to_i <= 0

      rate = STORAGE_RATES.fetch(volume_type, DEFAULT_STORAGE_RATE)
      hours = ttl_minutes.to_f / 60.0
      (rate * volume_size.to_i * hours / 730.0).round(4)
    end

    def summary(environments)
      total = environments.sum do |env|
        estimate(
          instance_type: env.instance_type || SeeoConfig.ec2_instance_type,
          ttl_minutes: env.ttl_minutes,
          volume_size: env.volume_size,
          volume_type: env.volume_type || 'gp3'
        )
      end
      { total: total.round(4), currency: 'USD', environments_count: environments.size }
    end

    def environment_cost(environment)
      estimate(
        instance_type: environment.instance_type || SeeoConfig.ec2_instance_type,
        ttl_minutes: environment.ttl_minutes,
        volume_size: environment.volume_size,
        volume_type: environment.volume_type || 'gp3'
      )
    end
  end
end
