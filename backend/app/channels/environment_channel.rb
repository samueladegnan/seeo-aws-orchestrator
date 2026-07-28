# frozen_string_literal: true

class EnvironmentChannel < ApplicationCable::Channel
  def subscribed
    stream_from "environment_channel_#{session_id}"
  end

  def unsubscribed
    # Any cleanup needed when channel subscription is cancelled
  end

  def self.broadcast(environment, session_id = 'default')
    ActionCable.server.broadcast("environment_channel_#{session_id}", {
                                   id: environment.id,
                                   status: environment.status,
                                   project_name: environment.project_name,
                                   expires_at: environment.expires_at&.iso8601,
                                   public_ip: environment.public_ip
                                 })
  end

  private

  def session_id
    params['session_id'].presence || 'default'
  end
end
