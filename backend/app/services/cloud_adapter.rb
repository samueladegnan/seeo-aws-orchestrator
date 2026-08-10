# frozen_string_literal: true

class CloudAdapter
  class UnsupportedProviderError < StandardError; end

  attr_reader :provider

  def initialize(provider:)
    @provider = provider.to_s
  end

  def create_environment(*) = raise NotImplementedError
  def get_environment(*) = raise NotImplementedError
  def list_environments(*) = raise NotImplementedError
  def active_environment_count = list_environments.count { |environment| environment.status != 'terminated' }
  def list_expired_environments = raise NotImplementedError
  def terminate_environment(*) = raise NotImplementedError
  def force_terminate_environment(*) = raise NotImplementedError
  def refresh_environment_state(*) = raise NotImplementedError

  def self.for(provider: nil, mock: false)
    selected = (provider.presence || CloudProvider.default_provider).to_s
    unless CloudProvider.valid?(selected) && SeeoConfig.allowed_providers.include?(selected)
      raise UnsupportedProviderError, "Cloud provider #{selected} is not enabled"
    end

    return MockCloudService.new(provider: selected) if mock

    {
      'aws' => AwsService,
      'azure' => AzureService,
      'gcp' => GcpService,
      'oci' => OciService
    }.fetch(selected).new(provider: selected)
  end
end
