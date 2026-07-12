Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
  resource :setup, only: %i[new create], controller: "setup"
  resource :session, only: %i[new create destroy] do
    get :magic_link, on: :collection
    post :magic_link, on: :collection
  end
  resources :passkeys, only: %i[index update destroy] do
    collection do
      post :registration_options
      post :registration
      post :authentication_options
      post :authentication
    end
  end
  namespace :settings do
    resource :security, only: %i[show], controller: "security"
  end
  resources :people, only: %i[index show]
  namespace :admin do
    root "dashboard#show"
    resources :people, only: [] do
      resource :user_account, only: %i[create destroy] do
        patch :roster_control, on: :member
      end
      resources :position_assignments, only: %i[create update]
    end
    resources :users, only: [] do
      resource :permission_grants, only: %i[update]
    end
    resources :roster_imports, only: %i[index new create show] do
      post :confirm, on: :member
      delete :discard, on: :member
    end
    resources :position_titles, only: %i[create update]
  end
  resource :passkey_invitation, only: %i[destroy]
  resource :roster_email_review, only: %i[update]
  resource :dashboard, only: %i[show], controller: "dashboard"
  root "dashboard#show"
end
