# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MockAwsService do
  let(:service) { described_class.new }

  before do
    Current.reset
    Current.session_id = 'test-session'
    described_class.reset!
  end

  after { Current.reset }

  describe '#create_environment and #terminate_environment' do
    it 'creates and terminates an environment and clears it from the store' do
      environment = service.create_environment('demo', 60, 't3.micro')
      expect(environment).to be_a(Environment)
      expect(environment.status).to eq('provisioning')
      expect(environment.region).to eq('us-east-1')
      expect(environment.volume_size).to eq(10)
      expect(environment.volume_type).to eq('gp3')

      sleep 0.1
      ready = service.refresh_environment_state(environment.id)
      expect(ready.status).to eq('provisioning')

      terminated = service.terminate_environment(environment.id)
      expect(terminated.status).to eq('terminated')
      expect(terminated.created_at).to be_a(Time)
      expect(terminated.expires_at).to be_a(Time)

      # Regression: to_summary must not raise NoMethodError on String.
      summary = terminated.to_summary
      expect(summary[:created_at]).to include('T')
      expect(summary[:expires_at]).to include('T')
      expect(summary[:cost]).to be_a(Numeric)

      # Terminated environments should be removed from the mock store.
      expect(service.get_environment(environment.id)).to be_nil
      expect(service.list_environments).to be_empty
    end
  end

  describe 'session isolation' do
    it 'only shows environments for the current session' do
      service.create_environment('alpha', 60, 't3.micro')

      Current.session_id = 'other-session'
      service.create_environment('beta', 60, 't3.micro')

      Current.session_id = 'test-session'
      expect(service.list_environments.map(&:project_name)).to eq(['alpha'])
    end

    it 'does not terminate environments belonging to another session' do
      service.create_environment('alpha', 60, 't3.micro')
      Current.session_id = 'other-session'
      other = service.create_environment('beta', 60, 't3.micro')

      Current.session_id = 'test-session'
      expect { service.terminate_environment(other.id) }.to raise_error(ArgumentError)
      expect(service.list_environments.map(&:project_name)).to eq(['alpha'])
    end

    it 'allows the TTL monitor to terminate expired environments across sessions' do
      env = service.create_environment('alpha', 60, 't3.micro')
      Current.session_id = 'other-session'
      other_env = service.create_environment('beta', 60, 't3.micro')

      service.force_terminate_environment(env.id)
      service.force_terminate_environment(other_env.id)

      expect(service.get_environment(env.id)).to be_nil
      expect(service.get_environment(other_env.id)).to be_nil
    end
  end

  describe 'provisioning simulation' do
    it 'creates environments as ready when the delay is zero' do
      allow(SeeoConfig).to receive(:mock_provisioning_delay_seconds).and_return(0)
      env = service.create_environment('demo', 60, 't3.micro')
      expect(env.status).to eq('ready')
    end
  end

  describe 'options' do
    it 'stores region, volume size, volume type, notes and tags' do
      env = service.create_environment('demo', 60, 't3.micro', {
                                         region: 'eu-west-1',
                                         volume_size: 50,
                                         volume_type: 'io2',
                                         notes: 'test notes',
                                         tags: { env: 'demo' }
                                       })
      expect(env.region).to eq('eu-west-1')
      expect(env.volume_size).to eq(50)
      expect(env.volume_type).to eq('io2')
      expect(env.notes).to eq('test notes')
      expect(env.tags).to eq('env' => 'demo')
    end
  end

  describe 'per-session limits' do
    it 'caps the number of environments a session can create' do
      20.times { |i| service.create_environment("project-#{i}", 60, 't3.micro') }
      expect { service.create_environment('overflow', 60, 't3.micro') }.to raise_error(PolicyService::PolicyViolation)
    end
  end
end
