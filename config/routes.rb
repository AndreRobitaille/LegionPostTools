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
  resources :passkeys, only: %i[index destroy] do
    collection do
      post :registration_options
      post :registration
      post :authentication_options
      post :authentication
    end
  end
  namespace :settings do
    resource :security, only: %i[show]
  end
  resource :passkey_invitation, only: %i[destroy]
  resource :dashboard, only: %i[show], controller: "dashboard"
  root "dashboard#show"
end
