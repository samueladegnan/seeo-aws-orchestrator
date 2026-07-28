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
                                   environment: environment.to_summary
                                 })
  end

  private

  def session_id
    params['session_id'].presence || 'default'
  end
end
