# frozen_string_literal: true

class EnvironmentChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'environment_channel'
  end

  def unsubscribed
    # Any cleanup needed when channel subscription is cancelled
  end

  def self.broadcast(environment)
    ActionCable.server.broadcast('environment_channel', {
                                   id: environment.id,
                                   status: environment.status,
                                   project_name: environment.project_name,
                                   expires_at: environment.expires_at&.iso8601,
                                   public_ip: environment.public_ip
                                 })
  end
end
