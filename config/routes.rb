Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :registrations, only: %i[new create]
  resource :legacy_setup, only: %i[edit update]
  resource :profile, only: %i[show edit update] do
    get :achievements
  end
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
      member { get :deletion }
      resource :result, controller: "match_results", only: %i[edit update] do
        match :preview, via: %i[get post]
        post :confirm
      end
    end
    get "players/import", to: "player_roster_imports#new", as: :new_player_roster_import
    post "players/import/preview", to: "player_roster_imports#preview", as: :preview_player_roster_import
    post "players/import", to: "player_roster_imports#create", as: :player_roster_import
    resources :players, except: :show do
      member do
        patch :archive
        patch :restore
      end
    end
    resources :users, only: %i[index show edit update] do
      resources :gold_point_transactions, only: :create
    end
    resources :achievements do
      member { post :award }
      resources :awards, only: [], controller: "achievement_awards" do
        member do
          get :revocation
          post :revoke
          get :restoration
          post :restore
        end
      end
    end
    resources :scoring_rules, only: %i[index update]
    resources :audit_logs, only: :index
    resources :seasons, only: %i[index show new create] do
      member do
        get :completion
        post :complete
        get :rollback_preview
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
