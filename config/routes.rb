Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  root "pages#home"

  get "privacy", to: "pages#privacy"
  get "terms", to: "pages#terms"
  get "support", to: "pages#support"

  get "today", to: "days#show", as: :today
  resources :days, only: [ :show ], param: :date do
    resources :food_log_entries, only: [ :create, :edit, :update, :destroy ], path: "entries"
  end

  resource :settings, only: [ :edit, :update ], controller: "users"

  resources :foods, only: [ :index, :new, :create, :edit, :update, :destroy ] do
    collection do
      get :barcode_lookup
    end
  end

  resource :meal_picker, only: :show

  resources :recipes

  resources :meal_templates, only: [ :index, :new, :create, :destroy ] do
    member do
      post :log
    end
  end

  post "onboarding/skip", to: "onboarding#skip", as: :skip_onboarding
  get "onboarding/:step", to: "onboarding#show", as: :onboarding_step
  patch "onboarding/:step", to: "onboarding#update", as: :update_onboarding_step

  mount MissionControl::Jobs::Engine, at: "/jobs"
  mount Lookbook::Engine, at: "/lookbook" if Rails.env.development?

  namespace :api do
    namespace :v1 do
      resource :path_configuration, only: :show
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: :json }

  # Defines the root path route ("/")
  # root "posts#index"
end
