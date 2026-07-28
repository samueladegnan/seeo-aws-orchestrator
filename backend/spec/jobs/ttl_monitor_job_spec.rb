# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TtlMonitorJob, type: :job do
  let(:expired_env) do
    Environment.new(
      id: 'expired-123',
      project_name: 'stale-api',
      status: 'ready',
      created_at: 2.hours.ago,
      expires_at: 5.minutes.ago,
      ttl_minutes: 60
    )
  end

  let(:active_env) do
    Environment.new(
      id: 'active-456',
      project_name: 'active-api',
      status: 'ready',
      created_at: 10.minutes.ago,
      expires_at: 1.hour.from_now,
      ttl_minutes: 60
    )
  end

  describe '#perform' do
    it 'terminates expired environments' do
      aws_service = instance_double(AwsService)
      allow(AwsService).to receive(:new).and_return(aws_service)
      allow(aws_service).to receive(:list_expired_environments).and_return([expired_env])
      allow(aws_service).to receive(:force_terminate_environment).with(expired_env.id).and_return(expired_env)

      expect { described_class.new.perform }.not_to raise_error
      expect(aws_service).to have_received(:list_expired_environments)
      expect(aws_service).to have_received(:force_terminate_environment).with(expired_env.id)
    end

    it 'does nothing when no environments are expired' do
      aws_service = instance_double(AwsService)
      allow(AwsService).to receive(:new).and_return(aws_service)
      allow(aws_service).to receive(:list_expired_environments).and_return([])
      allow(aws_service).to receive(:force_terminate_environment)

      described_class.new.perform

      expect(aws_service).not_to have_received(:force_terminate_environment)
    end

    it 'logs and continues when a single termination fails' do
      aws_service = instance_double(AwsService)
      allow(AwsService).to receive(:new).and_return(aws_service)
      allow(aws_service).to receive(:list_expired_environments).and_return([expired_env, active_env])
      allow(aws_service).to receive(:force_terminate_environment)
        .with(expired_env.id).and_raise(StandardError, 'AWS failure')
      allow(aws_service).to receive(:force_terminate_environment).with(active_env.id).and_return(active_env)

      expect(Rails.logger).to receive(:error).with("[TTL] Failed to terminate #{expired_env.id}: AWS failure")

      described_class.new.perform

      expect(aws_service).to have_received(:force_terminate_environment).with(expired_env.id)
      expect(aws_service).to have_received(:force_terminate_environment).with(active_env.id)
    end
  end
end
