# frozen_string_literal: true

Rails.application.config.solid_queue.recurring = Rails.application.config_for(:recurring) if Rails.env.production?
