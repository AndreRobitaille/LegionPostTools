Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "internal/dated-agenda-pdf-source", to: "dated_agenda_pdf_sources#show", as: :dated_agenda_pdf_source

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
  resources :meetings, only: %i[index show]
  resources :endeavors, except: %i[destroy] do
    member do
      patch :complete
      patch :reopen
    end
    resources :updates, only: :create, controller: "endeavor_updates"
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
    resources :meetings do
      post :agenda, on: :member, action: :create_agenda
      resource :minutes, only: %i[show create edit update], controller: "meeting_minutes" do
        resources :draft_runs, only: %i[new create show], controller: "minutes_draft_runs"
        resources :draft_suggestions, only: %i[edit update], controller: "minutes_draft_suggestions" do
          post :use, on: :member
          post :discard, on: :member
        end
        resources :sections, except: %i[index show], controller: "minutes_sections" do
          patch :move, on: :member
        end
        resources :items, except: %i[index show], controller: "minutes_items" do
          patch :move, on: :member
        end
        resources :outcomes, except: %i[index show], controller: "minutes_outcomes" do
          patch :move, on: :member
        end
        resource :attendance, only: %i[edit update], controller: "minutes_attendance"
      end
      resource :transcript, only: %i[new create show], controller: "meeting_transcripts"
    end
    resources :dated_agendas, only: %i[index edit destroy] do
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
      resources :endeavors, controller: "dated_agenda_endeavors", only: %i[new create]
    end
  end
  resource :passkey_invitation, only: %i[destroy]
  resource :roster_email_review, only: %i[update]
  resource :dashboard, only: %i[show], controller: "dashboard"
  namespace :api do
    get "/", to: "handbook#show"
    resources :people, only: %i[index show]
    resources :officers, only: %i[index]
    resources :position_titles, only: %i[index]
    get "membership/summary", to: "membership#summary"
    get "membership/renewals", to: "membership#renewals"
    get "membership/roster", to: "membership#roster"
    get "membership/people/:id", to: "membership#person"
    resources :meeting_bodies, only: %i[index]
    resources :meeting_types, only: %i[index]
    resources :meetings, only: %i[index show create update destroy]
    resources :agenda_item_catalog_entries, only: %i[index create update destroy] do
      post :reorder, on: :collection
    end
    resources :dated_agendas, only: %i[index show create destroy] do
      member do
        patch :approve
        patch :publish
        patch :reopen
      end
      resources :items, only: %i[create update destroy], controller: "dated_agenda_items" do
        resource :roll_call, only: %i[update], controller: "dated_agenda_roll_calls" do
          post :refresh, on: :member
        end
      end
      post "sections/:section_id/items/reorder", to: "dated_agenda_items#reorder"
      resources :endeavors, only: :create, controller: "dated_agenda_endeavors"
    end
    resources :endeavors, only: %i[index show create] do
      member do
        patch :complete
        patch :reopen
      end
      resources :updates, only: :create, controller: "endeavor_updates"
    end
  end
  root "dashboard#show"
end
