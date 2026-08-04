# frozen_string_literal: true

class EnvironmentChannel < ApplicationCable::Channel
  def subscribed
    reject unless can_subscribe?

    stream_from stream_key
  end

  def self.broadcast(environment, stream_key = nil)
    key = stream_key || environment.stream_key
    ActionCable.server.broadcast(key, { environment: environment.to_summary })
  end

  private

  def can_subscribe?
    current_user.present? &&
      (current_team.present? || service_account?) &&
      requested_stream_key == authorized_stream_key
  end

  def requested_stream_key
    params['stream_key'].presence || params['session_id'].presence
  end

  def authorized_stream_key
    if current_team
      "team_#{current_team.id}"
    else
      "session_#{connection.current_session_id || 'default'}"
    end
  end

  def stream_key
    authorized_stream_key
  end

  def service_account?
    connection.current_service_account == true
  end
end
