Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
  resource :setup, only: %i[new create], controller: "setup"
  resource :session, only: %i[new create destroy] do
    get :code, on: :collection
    post :code, on: :collection
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
  resource :profile, only: %i[show]
  resource :agent_access_reauthentication, only: %i[new create] do
    post :verify, on: :collection
    get :magic_link, on: :collection
    post :magic_link, on: :collection
  end
  resources :agent_access_tokens, only: %i[index new create destroy] do
    get :revoke, on: :member
  end
  resources :people, only: %i[index show]
  resources :tracked_items, except: %i[destroy] do
    member do
      patch :complete
      patch :reopen
    end
    resources :updates, only: :create, controller: "tracked_item_updates"
  end
  resources :dated_agendas, only: %i[index show] do
    get :print, on: :member
  end
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
    resources :loops_roster_syncs, only: %i[new create show]
    resources :position_titles, only: %i[index create update] do
      post :reorder, on: :collection
    end
    resources :agenda_item_catalog_entries, except: :show do
      post :reorder, on: :collection
      patch :move, on: :member
    end
    resources :administrators, only: %i[index]
    resources :agent_access_tokens, only: %i[index destroy] do
      get :revoke, on: :member
    end
    resources :meeting_types, except: %i[show] do
      post :seed_defaults, on: :collection
      post :reset_defaults, on: :collection
      post :reorder, on: :collection
      post :reset_agenda, on: :member
      resources :agenda_sections, controller: "meeting_type_agenda_sections", except: %i[index show] do
        post :reorder, on: :collection
        patch :move, on: :member
      end
      resources :agenda_items, controller: "meeting_type_agenda_items", as: :agenda_items, only: %i[new create edit update destroy] do
        post :reorder, on: :collection
      end
    end
    resources :dated_agendas do
      member do
        patch :approve
        patch :publish
        patch :reopen
        get :print
        get :commander
      end
      resources :agenda_sections, controller: "dated_agenda_sections", except: %i[index show] do
        post :reorder, on: :collection
        patch :move, on: :member
      end
      resources :agenda_items, controller: "dated_agenda_items", as: :agenda_items, only: %i[new create edit update destroy] do
        post :reorder, on: :collection
        patch :refresh_roll_call, on: :member
        resource :roll_call, only: %i[edit update], controller: "dated_agenda_roll_calls"
      end
      resources :tracked_items, controller: "dated_agenda_tracked_items", only: %i[new create]
    end
  end
  resource :passkey_invitation, only: %i[destroy]
  resource :roster_email_review, only: %i[update]
  resource :dashboard, only: %i[show], controller: "dashboard"
  namespace :api do
    get "/", to: "handbook#show"
    resources :people, only: %i[index show]
    resources :officers, only: %i[index]
    get "membership/summary", to: "membership#summary"
    get "membership/renewals", to: "membership#renewals"
    get "membership/roster", to: "membership#roster"
    get "membership/people/:id", to: "membership#person"
    resources :meeting_bodies, only: %i[index]
    resources :meeting_types, only: %i[index]
    resources :dated_agendas, only: %i[index show create] do
      member do
        patch :approve
        patch :publish
        patch :reopen
      end
      resources :tracked_items, only: :create, controller: "dated_agenda_tracked_items"
    end
    resources :tracked_items, only: %i[index show create] do
      member do
        patch :complete
        patch :reopen
      end
      resources :updates, only: :create, controller: "tracked_item_updates"
    end
  end
  root "dashboard#show"
end
