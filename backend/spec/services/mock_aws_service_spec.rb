# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MockAwsService do
  let(:service) { described_class.new }

  before { described_class.reset! }

  describe '#create_environment and #terminate_environment' do
    it 'creates and terminates an environment and clears it from the store' do
      environment = service.create_environment('demo', 60, 't3.micro')
      expect(environment).to be_a(Environment)
      expect(environment.status).to eq('ready')

      terminated = service.terminate_environment(environment.id)
      expect(terminated.status).to eq('terminated')
      expect(terminated.created_at).to be_a(Time)
      expect(terminated.expires_at).to be_a(Time)

      # Regression: to_summary must not raise NoMethodError on String.
      summary = terminated.to_summary
      expect(summary[:created_at]).to include('T')
      expect(summary[:expires_at]).to include('T')

      # Terminated environments should be removed from the mock store.
      expect(service.get_environment(environment.id)).to be_nil
      expect(service.list_environments).to be_empty
    end
  end
end
