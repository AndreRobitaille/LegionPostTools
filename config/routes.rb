Rails.application.routes.draw do
  resource :setup, only: %i[new create]
  resource :session, only: %i[new create destroy] do
    get :magic_link, on: :collection
  end
  resource :dashboard, only: %i[show]
  root "dashboard#show"
end
