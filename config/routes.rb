Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  resource :setup, only: %i[new create]
  resource :session, only: %i[new create destroy] do
    get :magic_link, on: :collection
    post :magic_link, on: :collection
  end
  resource :dashboard, only: %i[show], controller: "dashboard"
  root "dashboard#show"
end
