Rails.application.routes.draw do
  use_doorkeeper do
    controllers authorizations: "mobile/authorizations", tokens: "mobile/tokens"
    skip_controllers :applications, :authorized_applications, :token_info
  end
  namespace :mobile do
    delete "remembered_sessions/:id", to: "sessions#destroy_remembered", as: :remembered_session
    resources :sessions, only: %i[index destroy]
  end
  scope "/public/v1", controller: "public/v1/publications", format: false do
    match "featured_members", action: :featured, via: :all
    match "member_stories/:id", action: :story, via: :all
    match "member_stories/:id/portrait/:revision/:size.webp", action: :portrait, via: :all
    match "events", action: :events, via: :all
    match "events/:id", action: :event, via: :all
    match "officers", action: :officers, via: :all
    match "*path", action: :missing, via: :all
  end

  get "up" => "rails/health#show", as: :rails_health_check
  get "internal/dated-agenda-pdf-source", to: "dated_agenda_pdf_sources#show", as: :dated_agenda_pdf_source
  get "internal/meeting-minutes-pdf-source", to: "meeting_minutes_pdf_sources#show", as: :meeting_minutes_pdf_source
  get "internal/calendar-pdf-source", to: "calendar_pdf_sources#show", as: :calendar_pdf_source

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
  resource :passkey_enrollment_reauthentication, only: %i[new create destroy] do
    post :verify, on: :collection
    get :magic_link, on: :collection
    post :magic_link, on: :collection
  end
  resource :profile, only: %i[show]
  resource :agent_access_reauthentication, only: %i[new create] do
    post :verify, on: :collection
    get :magic_link, on: :collection
    post :magic_link, on: :collection
  end
  resource :official_action_reauthentication, only: %i[new create] do
    post :verify, on: :collection
    get :magic_link, on: :collection
    post :magic_link, on: :collection
  end
  resources :agent_access_tokens, only: %i[index new create destroy] do
    get :revoke, on: :member
  end
  resources :people, only: %i[index show]
  get "contact", to: "post_contacts#show", as: :post_contact
  get "calendar", to: "calendar#show", as: :calendar
  get "calendar/print", to: "calendar#print", as: :print_calendar
  get "calendar/manage", to: "calendar#manage", as: :manage_calendar
  resources :calendar_events, only: %i[show new create edit update destroy]

  resources :meetings, only: %i[index show] do
    resource :minutes, only: :show, controller: "meeting_minutes" do
      get :print
    end
  end
  resources :endeavors, except: %i[destroy] do
    get :source, to: "endeavor_sources#show", on: :member
    member do
      patch :complete
      patch :reopen
    end
    resources :tasks, only: %i[new create edit update], controller: "endeavor_tasks"
    resources :updates, only: :create, controller: "endeavor_updates"
  end
  resources :dated_agendas, only: %i[index show] do
    get :print, on: :member
  end
  namespace :admin do
    resource :website_calendar, only: %i[show update], controller: "website_calendar" do
      post :preview
    end
    resources :website_access_tokens, only: %i[index new create destroy] do
      get :revoke, on: :member
    end
    resources :website_publications, only: %i[index create edit update] do
      post :feature, on: :collection
      post :publish, on: :member
      post :withdraw, on: :member
      post :consent, on: :member
      post :eligibility, on: :member
      post :internal, on: :member
      get :portrait, on: :member
    end

    resources :endeavors, only: :index do
      resource :history, only: %i[show create], controller: "endeavor_histories"
    end
    root "dashboard#show"
    resources :jobs, only: :index do
      member do
        post :retry
        patch :discard
        patch :restore
      end
    end
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
    resources :position_titles, only: %i[index create edit update] do
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
        get :print, on: :member
        resource :approval, only: %i[new create], controller: "minutes_approvals"
        resource :attestation, only: %i[new create], controller: "minutes_attestations"
        resource :reopening, only: %i[new create], controller: "minutes_reopenings"
        resource :membership_approval, only: %i[new create], controller: "minutes_membership_approvals"
        resources :draft_runs, only: %i[new create show], controller: "minutes_draft_runs" do
          get :status, on: :member
          resource :attendance_review, only: :update, controller: "minutes_draft_attendance_reviews"
        end
        resources :draft_suggestions, only: %i[edit update], controller: "minutes_draft_suggestions" do
          post :use, on: :member
          post :discard, on: :member
        end
        resources :sections, except: %i[index show], controller: "minutes_sections" do
          patch :move, on: :member
        end
        resources :items, except: %i[index show], controller: "minutes_items" do
          patch :move, on: :member
          resource :endeavor, only: %i[new create], controller: "minutes_item_endeavors"
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
        get :new_discussion, on: :collection
        post :create_discussion, on: :collection
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
  get "officer-tools", to: "officer_tools#show", as: :officer_tools
  resource :minutes_distribution, only: %i[show update], controller: "minutes_distributions" do
    patch :wording, action: :update_wording
    post :create_recipient
    patch "recipients/:recipient_id", action: :update_recipient, as: :recipient
    post "recipients/:recipient_id/enroll", action: :enroll_recipient, as: :enroll_recipient
    post "minutes/:minutes_id/hold", action: :hold, as: :hold
    post "minutes/:minutes_id/release", action: :release, as: :release
    post "issues/:issue_id/retry", action: :retry_delivery, as: :retry_delivery
    post "issues/:issue_id/deliveries/:delivery_id/resolve", action: :resolve_delivery, as: :resolve_delivery
  end
  namespace :buddy_checks, path: "buddy-checks" do
    root to: "workspace#index"
    get "post-activity", to: "coordination#index", as: :activity
    get "coverage", to: "coordination#coverage", as: :coverage
    get "county-report", to: "coordination#report", as: :report
    get "member-history/:id", to: "coordination#show", as: :member_history
    get "member-history/:id/care", to: "coordination#care", as: :care
    post "member-history/:id/care", to: "coordination#record_care"
    post "member-history/:id/contact-preference", to: "coordination#preference", as: :preference
    get "people", to: "workspace#people", as: :people
    resources :people, only: :show, controller: "workspace"
    resources :contacts, only: %i[index new create edit update]
    resources :follow_ups, path: "follow-ups", only: %i[index new create edit update]
    resources :snoozes, only: %i[index create destroy]
  end
  namespace :membership do
    resources :buddy_attendances, path: "buddy-attendance", controller: "buddy_attendance", only: %i[index show] do
      post :create, on: :member, path: ""
    end
    resources :buddy_addresses, path: "buddy-addresses", only: %i[show] do
      post :create, on: :member, path: ""
    end
    root to: "overview#index"
    get "follow-up", to: "overview#follow_up", as: :follow_up
    get "report", to: "reports#index"
    get "post-checks", to: "post_checks#index", as: :post_checks
    resources :people, only: :show do
      resources :contacts, only: %i[new create]
    end
    resources :drives, only: %i[index new create show update] do
      get :print, on: :member
      resources :assignments, only: %i[create update]
    end
    resources :dues_records, only: :create do
      post :reverse, on: :member
    end
    resources :summaries, only: %i[create show] do
      get :print, on: :member
    end
  end
  get "internal/membership-pdf-source", to: "membership_pdf_sources#show"
  namespace :api do
    namespace :mobile do
      namespace :v1 do
        get "session", to: "buddy_checks#session"
        scope "buddy-checks", controller: "buddy_checks" do
          get "people", action: :people
          get "people/:id", action: :person
          get "suggestion", action: :suggestion
          get "receipts/:operation_id", action: :receipt
          get "mine", action: :mine
          get "follow-ups", action: :follow_ups
          post "follow-ups", action: :schedule
          post "follow-ups/:id/changes", action: :change_follow_up
          get "snoozes", action: :snoozes
          post "snoozes", action: :snooze
          delete "snoozes/:id", action: :undo_snooze
          get ":id/revisions", action: :revisions
          post ":id/corrections", action: :correct
          post "", action: :create
        end
        get "people/:id/contact-export", to: "buddy_checks#contact_export"
      end
    end
    resource :website_calendar, only: %i[show update], controller: "website_calendar" do
      post :preview
    end
    get "/", to: "handbook#show"
    resources :website_publications, only: %i[index show create update] do
      collection do
        get :featured
        put :featured, action: :feature
      end
      member do
        post :consent
        post :eligibility
        post :internal
        post :publish
        post :withdraw
        post :portrait, action: :upload_portrait
        get "portrait/:revision/:size", action: :portrait, constraints: { size: /small|large/ }, defaults: { format: :webp }
        get :history
      end
    end
    resources :people, only: %i[index show] do
      resource :account, only: %i[show create destroy], controller: "user_accounts" do
        patch :roster_control
      end
    end
    resources :officers, only: %i[index]
    resources :position_titles, only: %i[index]
    get "membership/summary", to: "membership#summary"
    get "membership/renewals", to: "membership#renewals"
    get "membership/roster", to: "membership#roster"
    get "membership/people/:id", to: "membership#person"
    get "membership/workspace", to: "membership_work#index"
    get "membership/workspace/people/:id", to: "membership_work#person"
    post "membership/workspace/people/:id/contacts", to: "membership_work#contact"
    get "membership/workspace/drives/:id", to: "membership_work#drive"
    get "membership/workspace/drives/:id/print", to: "membership_work#drive_print"
    resources :meeting_bodies, only: %i[index]
    resources :meeting_types, only: %i[index]
    resources :meetings, only: %i[index show create update destroy] do
      get "member_documents/agenda", to: "member_meeting_documents#agenda"
      get "member_documents/agenda/print", to: "member_meeting_documents#agenda_print"
      get "member_documents/minutes", to: "member_meeting_documents#minutes"
      get "member_documents/minutes/print", to: "member_meeting_documents#minutes_print"
      resource :transcript, only: %i[show create], controller: "meeting_transcripts"
      resource :minutes, only: %i[show create update], controller: "meeting_minutes" do
        get :print
        resource :approval, only: :create, controller: "minutes_approvals"
        resource :attestation, only: :create, controller: "minutes_attestations"
        resource :attendance, only: :update, controller: "minutes_attendance"
        post "sections/reorder", to: "minutes_sections#reorder"
        post "sections/:section_id/items/reorder", to: "minutes_items#reorder"
        post "items/:item_id/outcomes/reorder", to: "minutes_outcomes#reorder"
        resources :sections, only: %i[create update destroy], controller: "minutes_sections"
        resources :items, only: %i[create update destroy], controller: "minutes_items" do
          resource :endeavor, only: :create, controller: "minutes_item_endeavors"
        end
        resources :outcomes, only: %i[create update destroy], controller: "minutes_outcomes"
        resources :draft_runs, only: %i[index show create], controller: "minutes_draft_runs" do
          member do
            post :retry
            patch :discard
            patch :restore
            patch :attendance
          end
          resources :suggestions, only: [], controller: "minutes_draft_suggestions" do
            member do
              patch :use
              patch :edit
              patch :discard
            end
          end
        end
      end
    end
    get "jobs", to: "jobs#index"
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
    get "calendar", to: "calendar#show"
    resources :calendar_events, only: %i[index show create update destroy]
    resources :endeavors, only: %i[index show create update] do
      resources :tasks, only: %i[index show create update], controller: "endeavor_tasks"
      resource :history, only: %i[show create], controller: "endeavor_histories"
      member do
        patch :complete
        patch :reopen
      end
      resources :updates, only: :create, controller: "endeavor_updates"
    end
  end
  root "dashboard#show"
end
