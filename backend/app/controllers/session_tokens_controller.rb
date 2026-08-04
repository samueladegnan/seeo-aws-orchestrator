# frozen_string_literal: true

class SessionTokensController < ApplicationController
  skip_before_action :require_session_token!

  def show
    issued = SessionTokenService.issue
    render json: issued
  end
end
