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
  mount ActionCable.server => '/cable'
end
