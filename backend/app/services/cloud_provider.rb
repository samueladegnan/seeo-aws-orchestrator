# frozen_string_literal: true

module CloudProvider
  PROVIDERS = {
    'aws' => {
      label: 'Amazon Web Services', short_label: 'AWS', default_region: 'us-east-1',
      regions: { 'us-east-1' => 'US East (N. Virginia)', 'us-west-2' => 'US West (Oregon)', 'eu-west-1' => 'Europe (Ireland)', 'ap-southeast-1' => 'Asia Pacific (Singapore)' },
      compute: { 'small' => 't3.micro', 'medium' => 't3.small', 'large' => 't3.medium' },
      storage: { 'balanced' => 'gp3', 'performance' => 'io2', 'throughput' => 'st1' }
    },
    'azure' => {
      label: 'Microsoft Azure', short_label: 'Azure', default_region: 'eastus',
      regions: { 'eastus' => 'East US', 'westus2' => 'West US 2', 'westeurope' => 'West Europe', 'southeastasia' => 'Southeast Asia' },
      compute: { 'small' => 'Standard_B1s', 'medium' => 'Standard_B2s', 'large' => 'Standard_D2s_v5' },
      storage: { 'balanced' => 'StandardSSD_LRS', 'performance' => 'Premium_LRS', 'throughput' => 'Standard_LRS' }
    },
    'gcp' => {
      label: 'Google Cloud', short_label: 'Google Cloud', default_region: 'us-central1',
      regions: { 'us-central1' => 'Iowa', 'us-east1' => 'South Carolina', 'europe-west1' => 'Belgium', 'asia-southeast1' => 'Singapore' },
      compute: { 'small' => 'e2-micro', 'medium' => 'e2-small', 'large' => 'e2-medium' },
      storage: { 'balanced' => 'pd-balanced', 'performance' => 'pd-ssd', 'throughput' => 'pd-standard' }
    },
    'oci' => {
      label: 'Oracle Cloud Infrastructure', short_label: 'OCI', default_region: 'us-ashburn-1',
      regions: { 'us-ashburn-1' => 'Ashburn', 'us-phoenix-1' => 'Phoenix', 'uk-london-1' => 'London', 'ap-singapore-1' => 'Singapore' },
      compute: { 'small' => 'VM.Standard.E4.Flex', 'medium' => 'VM.Standard.E4.Flex', 'large' => 'VM.Standard.E4.Flex' },
      storage: { 'balanced' => 'balanced', 'performance' => 'higher_performance', 'throughput' => 'lower_cost' }
    }
  }.freeze

  TIERS = %w[small medium large].freeze
  STORAGE_TIERS = %w[balanced performance throughput].freeze

  module_function

  def valid?(provider)
    PROVIDERS.key?(provider.to_s)
  end

  def definition(provider)
    PROVIDERS.fetch(provider.to_s) { raise ArgumentError, "Unsupported cloud provider: #{provider}" }
  end

  def default_provider
    selected = ENV.fetch('SEEO_DEFAULT_PROVIDER', 'aws')
    raise ArgumentError, "Unsupported default provider: #{selected}" unless valid?(selected)

    selected
  end

  def provider_names
    PROVIDERS.keys
  end

  def region(provider, requested)
    definition = definition(provider)
    selected = requested.presence || definition[:default_region]
    raise ArgumentError, "Region #{selected} is not available in #{provider}" unless definition[:regions].key?(selected)

    selected
  end

  def compute_shape(provider, tier)
    definition(provider)[:compute].fetch(tier.to_s) { raise ArgumentError, "Unsupported compute tier #{tier} for #{provider}" }
  end

  def storage_shape(provider, tier)
    definition(provider)[:storage].fetch(tier.to_s) { raise ArgumentError, "Unsupported storage tier #{tier} for #{provider}" }
  end
end
