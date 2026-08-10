# frozen_string_literal: true

class MockAwsService < MockCloudService
  def initialize(provider: 'aws')
    super
  end
end
