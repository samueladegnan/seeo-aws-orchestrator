# frozen_string_literal: true

class CableTokensController < ApplicationController
  def show
    render json: { token: CableTokenService.issue }
  end
end
