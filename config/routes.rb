Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :registrations, only: %i[new create]
  resource :legacy_setup, only: %i[edit update]
  resource :profile, only: %i[show edit update]
  resources :passwords, param: :token, only: %i[new create edit update]

  resources :matches, only: [] do
    resources :forecasts, only: %i[new create show edit update]
  end
  resources :rounds, only: %i[index show]
  resource :standings, only: :show

  namespace :admin do
    root "dashboard#index"
    resources :competitions, except: %i[show destroy]
    resources :results, only: :index
    resources :gold_point_transactions, only: :index
    resource :standings, only: :show do
      post :rebuild
    end
    resources :matches do
      resource :result, controller: "match_results", only: %i[edit update] do
        match :preview, via: %i[get post]
        post :confirm
      end
    end
    resources :players, except: :show do
      member do
        patch :archive
        patch :restore
      end
    end
    resources :users, only: %i[index show edit update] do
      resources :gold_point_transactions, only: :create
    end
    resources :achievements, except: :show do
      member { post :award }
    end
    resources :scoring_rules, only: %i[index update]
    resources :audit_logs, only: :index
    resources :seasons, only: %i[index show new create] do
      member do
        patch :activate
        post :rollback
      end
    end
  end

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
