Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  root "pages#home"

  get "today", to: "days#show", as: :today
  resources :days, only: [:show], param: :date do
    resources :food_log_entries, only: [:create, :edit, :update, :destroy], path: "entries"
  end

  resource :settings, only: [:edit, :update], controller: "users"

  resources :foods, only: [:index, :new, :create, :edit, :update, :destroy]

  resource :meal_picker, only: :show

  resources :recipes

  resources :meal_templates, only: [:index, :new, :create, :destroy] do
    member do
      post :log
    end
  end

  post "onboarding/skip", to: "onboarding#skip", as: :skip_onboarding
  get "onboarding/:step", to: "onboarding#show", as: :onboarding_step
  patch "onboarding/:step", to: "onboarding#update", as: :update_onboarding_step

  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
