Rails.application.routes.draw do
  # Health
  get "/health", to: "health#index"

  # Environment lifecycle
  resources :environments, only: %i[index show create destroy] do
    member do
      post :refresh
    end
  end
end
