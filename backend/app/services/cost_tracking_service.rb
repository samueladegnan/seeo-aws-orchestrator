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

  DEFAULT_RATE = 0.05

  class << self
    def estimate(instance_type:, ttl_minutes:)
      rate = RATES.fetch(instance_type, DEFAULT_RATE)
      hours = ttl_minutes.to_f / 60.0
      (rate * hours).round(4)
    end

    def summary(environments)
      total = environments.sum do |env|
        estimate(instance_type: env.instance_type || SeeoConfig.ec2_instance_type, ttl_minutes: env.ttl_minutes)
      end
      { total: total.round(4), currency: 'USD', environments_count: environments.size }
    end
  end
end
