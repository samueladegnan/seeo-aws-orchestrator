# frozen_string_literal: true

Rails.application.routes.draw do
  # Health
  get '/health', to: 'health#index'

  # Environment lifecycle
  resources :environments, only: %i[index show create destroy] do
    member do
      post :refresh
    end
  end

  # Real-time updates
  get '/session-token', to: 'session_tokens#show'
  get '/cable-token', to: 'cable_tokens#show'
  mount ActionCable.server => '/cable'
end
