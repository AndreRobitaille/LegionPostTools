# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_29_060000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agenda_item_catalog_entries", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "behavior_type", null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "removed_from_catalog_at"
    t.datetime "seeded_at"
    t.boolean "show_wording_in_minutes", default: true, null: false
    t.boolean "show_wording_on_agenda", default: true, null: false
    t.string "slug", null: false
    t.string "source_key"
    t.string "source_label"
    t.text "summary", default: "", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "category", "position"], name: "idx_agenda_catalog_on_org_category_position"
    t.index ["organization_id", "removed_from_catalog_at"], name: "idx_agenda_catalog_on_org_removal"
    t.index ["organization_id", "slug"], name: "index_agenda_item_catalog_entries_on_organization_id_and_slug", unique: true
    t.index ["organization_id", "source_key"], name: "idx_on_organization_id_source_key_ecf47169eb", unique: true, where: "(source_key IS NOT NULL)"
    t.index ["organization_id"], name: "index_agenda_item_catalog_entries_on_organization_id"
  end

  create_table "agent_access_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_hint", null: false
    t.datetime "expires_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.string "public_id", null: false
    t.datetime "revoked_at"
    t.bigint "revoked_by_id"
    t.string "secret_digest", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_agent_access_tokens_on_expires_at"
    t.index ["public_id"], name: "index_agent_access_tokens_on_public_id", unique: true
    t.index ["revoked_at"], name: "index_agent_access_tokens_on_revoked_at"
    t.index ["revoked_by_id"], name: "index_agent_access_tokens_on_revoked_by_id"
    t.index ["user_id"], name: "index_agent_access_tokens_on_user_id"
  end

  create_table "agent_api_executions", force: :cascade do |t|
    t.bigint "agent_access_token_id", null: false
    t.datetime "created_at", null: false
    t.string "idempotency_key", null: false
    t.string "request_fingerprint", null: false
    t.string "request_method", null: false
    t.string "request_path", null: false
    t.text "response_body"
    t.integer "response_status"
    t.string "state", default: "processing", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["agent_access_token_id", "idempotency_key"], name: "idx_agent_api_executions_token_key", unique: true
    t.index ["agent_access_token_id"], name: "index_agent_api_executions_on_agent_access_token_id"
    t.index ["state", "created_at"], name: "index_agent_api_executions_on_state_and_created_at"
    t.index ["user_id"], name: "index_agent_api_executions_on_user_id"
    t.check_constraint "state::text = ANY (ARRAY['processing'::character varying, 'completed'::character varying]::text[])", name: "agent_api_executions_state_check"
  end

  create_table "dated_agenda_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "agenda_item_catalog_entry_id"
    t.string "behavior_type", null: false
    t.datetime "created_at", null: false
    t.bigint "dated_agenda_id", null: false
    t.bigint "dated_agenda_section_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "meeting_type_agenda_item_id"
    t.integer "position", default: 0, null: false
    t.datetime "seeded_at"
    t.boolean "show_wording_in_minutes", default: true, null: false
    t.boolean "show_wording_on_agenda", default: true, null: false
    t.string "source_key"
    t.string "source_label"
    t.text "summary", default: "", null: false
    t.string "title", null: false
    t.bigint "tracked_item_id"
    t.datetime "updated_at", null: false
    t.index ["agenda_item_catalog_entry_id"], name: "index_dated_agenda_items_on_agenda_item_catalog_entry_id"
    t.index ["dated_agenda_id", "agenda_item_catalog_entry_id"], name: "index_dated_agenda_items_on_agenda_and_catalog_entry", unique: true
    t.index ["dated_agenda_id", "meeting_type_agenda_item_id"], name: "index_dated_agenda_items_on_agenda_and_mt_item", unique: true, where: "(meeting_type_agenda_item_id IS NOT NULL)"
    t.index ["dated_agenda_id", "source_key"], name: "index_dated_agenda_items_on_agenda_and_source_key", unique: true, where: "(source_key IS NOT NULL)"
    t.index ["dated_agenda_id", "tracked_item_id"], name: "idx_dated_agenda_items_agenda_tracked_item", unique: true, where: "(tracked_item_id IS NOT NULL)"
    t.index ["dated_agenda_id"], name: "index_dated_agenda_items_on_dated_agenda_id"
    t.index ["dated_agenda_section_id", "position"], name: "idx_dated_agenda_items_section_position", unique: true
    t.index ["meeting_type_agenda_item_id"], name: "index_dated_agenda_items_on_meeting_type_agenda_item_id"
    t.index ["tracked_item_id"], name: "index_dated_agenda_items_on_tracked_item_id"
  end

  create_table "dated_agenda_roll_call_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dated_agenda_item_id", null: false
    t.string "office_name", null: false
    t.bigint "person_id"
    t.string "person_name"
    t.integer "position", null: false
    t.bigint "position_title_id"
    t.datetime "updated_at", null: false
    t.index ["dated_agenda_item_id", "position"], name: "idx_agenda_roll_call_item_position", unique: true
    t.index ["dated_agenda_item_id"], name: "index_dated_agenda_roll_call_entries_on_dated_agenda_item_id"
    t.index ["person_id"], name: "index_dated_agenda_roll_call_entries_on_person_id"
    t.index ["position_title_id"], name: "index_dated_agenda_roll_call_entries_on_position_title_id"
  end

  create_table "dated_agenda_sections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dated_agenda_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "meeting_type_agenda_section_id"
    t.integer "position", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["dated_agenda_id", "meeting_type_agenda_section_id"], name: "idx_dated_sections_source", unique: true, where: "(meeting_type_agenda_section_id IS NOT NULL)"
    t.index ["dated_agenda_id", "position"], name: "idx_dated_agenda_sections_position", unique: true
    t.index ["dated_agenda_id", "title"], name: "idx_dated_agenda_sections_title", unique: true
    t.index ["dated_agenda_id"], name: "index_dated_agenda_sections_on_dated_agenda_id"
    t.index ["meeting_type_agenda_section_id"], name: "index_dated_agenda_sections_on_meeting_type_agenda_section_id"
  end

  create_table "dated_agendas", force: :cascade do |t|
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.datetime "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "meeting_body_id", null: false
    t.bigint "meeting_type_id", null: false
    t.bigint "organization_id", null: false
    t.datetime "published_at"
    t.bigint "published_by_id"
    t.datetime "reopened_at"
    t.bigint "reopened_by_id"
    t.datetime "starts_at", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_dated_agendas_on_approved_by_id"
    t.index ["meeting_body_id"], name: "index_dated_agendas_on_meeting_body_id"
    t.index ["meeting_type_id"], name: "index_dated_agendas_on_meeting_type_id"
    t.index ["organization_id", "meeting_body_id", "meeting_type_id", "starts_at"], name: "index_dated_agendas_on_org_body_type_and_starts_at"
    t.index ["organization_id", "starts_at"], name: "index_dated_agendas_on_organization_id_and_starts_at"
    t.index ["organization_id", "status"], name: "index_dated_agendas_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_dated_agendas_on_organization_id"
    t.index ["published_by_id"], name: "index_dated_agendas_on_published_by_id"
    t.index ["reopened_by_id"], name: "index_dated_agendas_on_reopened_by_id"
  end

  create_table "installations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "setup_completed_at"
    t.string "singleton_key", null: false
    t.datetime "updated_at", null: false
    t.index ["singleton_key"], name: "index_installations_on_singleton_key", unique: true
  end

  create_table "loops_roster_syncs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "eligible_count", default: 0, null: false
    t.text "error_message"
    t.integer "failed_count", default: 0, null: false
    t.jsonb "failures", default: [], null: false
    t.datetime "finished_at"
    t.integer "invalid_email_count", default: 0, null: false
    t.integer "missing_email_count", default: 0, null: false
    t.bigint "requested_by_id"
    t.bigint "roster_import_id", null: false
    t.integer "shared_email_count", default: 0, null: false
    t.datetime "started_at"
    t.string "status", default: "queued", null: false
    t.integer "synced_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_loops_roster_syncs_on_created_at"
    t.index ["requested_by_id"], name: "index_loops_roster_syncs_on_requested_by_id"
    t.index ["roster_import_id"], name: "index_loops_roster_syncs_on_roster_import_id"
    t.index ["status"], name: "idx_one_active_loops_roster_sync", unique: true, where: "((status)::text = ANY ((ARRAY['queued'::character varying, 'running'::character varying])::text[]))"
  end

  create_table "magic_links", force: :cascade do |t|
    t.string "browser_challenge_digest"
    t.string "code_digest"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "purpose", default: "sign_in", null: false
    t.bigint "session_id"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.bigint "user_id", null: false
    t.index ["browser_challenge_digest"], name: "index_magic_links_on_browser_challenge_digest", unique: true
    t.index ["session_id"], name: "index_magic_links_on_session_id"
    t.index ["token_digest"], name: "index_magic_links_on_token_digest", unique: true
    t.index ["user_id"], name: "index_magic_links_on_user_id"
    t.check_constraint "purpose::text = ANY (ARRAY['sign_in'::character varying, 'create_agent_access_token'::character varying]::text[])", name: "magic_links_purpose_check"
  end

  create_table "meeting_bodies", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "default_distribution", default: "print", null: false
    t.text "default_location_address"
    t.string "default_location_name"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "slug"], name: "index_meeting_bodies_on_organization_id_and_slug", unique: true
    t.index ["organization_id"], name: "index_meeting_bodies_on_organization_id"
  end

  create_table "meeting_type_agenda_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "agenda_item_catalog_entry_id", null: false
    t.datetime "created_at", null: false
    t.bigint "meeting_type_agenda_section_id", null: false
    t.bigint "meeting_type_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "seeded_at"
    t.boolean "show_wording_in_minutes", default: true, null: false
    t.boolean "show_wording_on_agenda", default: true, null: false
    t.string "source_key"
    t.string "source_label"
    t.text "summary", default: "", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["agenda_item_catalog_entry_id"], name: "idx_on_agenda_item_catalog_entry_id_af09cfc728"
    t.index ["meeting_type_agenda_section_id", "position"], name: "idx_mt_agenda_items_section_position", unique: true
    t.index ["meeting_type_id", "agenda_item_catalog_entry_id"], name: "index_mt_agenda_items_on_type_and_catalog_entry", unique: true
    t.index ["meeting_type_id", "source_key"], name: "index_mt_agenda_items_on_type_and_source_key", unique: true, where: "(source_key IS NOT NULL)"
    t.index ["meeting_type_id"], name: "index_meeting_type_agenda_items_on_meeting_type_id"
  end

  create_table "meeting_type_agenda_sections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "meeting_type_id", null: false
    t.integer "position", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_type_id", "position"], name: "idx_mt_agenda_sections_position", unique: true
    t.index ["meeting_type_id", "title"], name: "idx_mt_agenda_sections_title", unique: true
    t.index ["meeting_type_id"], name: "index_meeting_type_agenda_sections_on_meeting_type_id"
  end

  create_table "meeting_types", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "seeded_at"
    t.string "slug", null: false
    t.string "source_key"
    t.string "source_label"
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_meeting_types_on_organization_id_and_name", unique: true
    t.index ["organization_id", "position"], name: "index_meeting_types_on_organization_id_and_position", unique: true
    t.index ["organization_id", "slug"], name: "index_meeting_types_on_organization_id_and_slug", unique: true
    t.index ["organization_id", "source_key"], name: "index_meeting_types_on_organization_id_and_source_key", unique: true, where: "(source_key IS NOT NULL)"
    t.index ["organization_id"], name: "index_meeting_types_on_organization_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "default_location_address"
    t.string "default_location_name"
    t.string "locality"
    t.text "mailing_address"
    t.string "name", null: false
    t.string "public_email"
    t.string "timezone", default: "America/Chicago", null: false
    t.string "unit_number"
    t.string "unit_type", null: false
    t.datetime "updated_at", null: false
  end

  create_table "passkey_credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "external_id", null: false
    t.datetime "last_used_at"
    t.string "nickname"
    t.text "public_key", null: false
    t.integer "sign_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["external_id"], name: "index_passkey_credentials_on_external_id", unique: true
    t.index ["user_id"], name: "index_passkey_credentials_on_user_id"
  end

  create_table "people", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "member_number"
    t.text "notes"
    t.string "phone_number"
    t.text "roster_address"
    t.string "roster_branch"
    t.integer "roster_continuous_years"
    t.string "roster_email_address"
    t.datetime "roster_imported_at"
    t.string "roster_member_status"
    t.string "roster_membership_type"
    t.string "roster_name"
    t.integer "roster_paid_through_year"
    t.string "roster_phone_number"
    t.string "roster_post"
    t.datetime "roster_removed_at"
    t.boolean "roster_undeliverable", default: false, null: false
    t.string "roster_war_era"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_people_on_email_address"
    t.index ["member_number"], name: "index_people_on_member_number", unique: true, where: "(member_number IS NOT NULL)"
    t.index ["roster_email_address"], name: "index_people_on_roster_email_address"
    t.index ["roster_member_status"], name: "index_people_on_roster_member_status"
    t.index ["roster_paid_through_year"], name: "index_people_on_roster_paid_through_year"
    t.index ["roster_removed_at"], name: "index_people_on_roster_removed_at"
  end

  create_table "permission_grants", force: :cascade do |t|
    t.string "capability", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "capability"], name: "index_permission_grants_on_user_id_and_capability", unique: true
    t.index ["user_id"], name: "index_permission_grants_on_user_id"
    t.check_constraint "capability::text = ANY (ARRAY['manage_settings'::character varying::text, 'manage_people'::character varying::text, 'manage_meeting_bodies'::character varying::text, 'manage_agendas'::character varying::text, 'manage_minutes'::character varying::text, 'approve_minutes'::character varying::text, 'attest_minutes'::character varying::text, 'record_acceptance_motions'::character varying::text, 'view_internal_records'::character varying::text])", name: "permission_grants_capability_check"
  end

  create_table "position_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ends_on"
    t.bigint "person_id", null: false
    t.bigint "position_title_id", null: false
    t.date "starts_on", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id", "position_title_id", "starts_on"], name: "idx_position_assignments_identity"
    t.index ["person_id"], name: "index_position_assignments_on_person_id"
    t.index ["position_title_id"], name: "index_position_assignments_on_position_title_id"
    t.check_constraint "ends_on IS NULL OR ends_on >= starts_on", name: "position_assignments_date_order_check"
  end

  create_table "position_titles", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "display_order", default: 0, null: false
    t.boolean "grants_full_membership_access", default: false, null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.boolean "required_by_default", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_position_titles_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_position_titles_on_organization_id"
  end

  create_table "roster_imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_count", default: 0, null: false
    t.datetime "imported_at", null: false
    t.integer "problem_count", default: 0, null: false
    t.integer "removed_count", default: 0, null: false
    t.string "status", default: "completed", null: false
    t.jsonb "summary", default: {}, null: false
    t.integer "unchanged_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "updated_count", default: 0, null: false
    t.string "uploaded_filename", null: false
    t.index ["status", "imported_at"], name: "index_roster_imports_on_status_and_imported_at"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "authenticated_at"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "last_seen_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tracked_item_updates", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.bigint "tracked_item_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_tracked_item_updates_on_author_id"
    t.index ["tracked_item_id"], name: "index_tracked_item_updates_on_tracked_item_id"
  end

  create_table "tracked_items", force: :cascade do |t|
    t.datetime "completed_at"
    t.bigint "completed_by_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.string "importance", default: "standard", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "meeting_body_id"
    t.bigint "organization_id", null: false
    t.date "raise_by_on"
    t.string "status", default: "active", null: false
    t.text "summary", default: "", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["completed_by_id"], name: "index_tracked_items_on_completed_by_id"
    t.index ["created_by_id"], name: "index_tracked_items_on_created_by_id"
    t.index ["meeting_body_id"], name: "index_tracked_items_on_meeting_body_id"
    t.index ["organization_id", "raise_by_on"], name: "index_tracked_items_on_organization_id_and_raise_by_on"
    t.index ["organization_id", "status"], name: "index_tracked_items_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_tracked_items_on_organization_id"
    t.check_constraint "importance::text = ANY (ARRAY['standard'::character varying, 'important'::character varying]::text[])", name: "tracked_items_importance_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'completed'::character varying]::text[])", name: "tracked_items_status_check"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.string "email_address", null: false
    t.datetime "email_verified_at"
    t.boolean "login_access_override", default: false, null: false
    t.datetime "login_access_override_at"
    t.bigint "person_id", null: false
    t.string "roster_email_review_decision"
    t.string "roster_email_reviewed_address"
    t.datetime "roster_email_reviewed_at"
    t.datetime "updated_at", null: false
    t.string "webauthn_id", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["login_access_override"], name: "index_users_on_login_access_override"
    t.index ["person_id"], name: "index_users_on_person_id", unique: true
    t.index ["webauthn_id"], name: "index_users_on_webauthn_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agenda_item_catalog_entries", "organizations"
  add_foreign_key "agent_access_tokens", "users"
  add_foreign_key "agent_access_tokens", "users", column: "revoked_by_id"
  add_foreign_key "agent_api_executions", "agent_access_tokens"
  add_foreign_key "agent_api_executions", "users"
  add_foreign_key "dated_agenda_items", "agenda_item_catalog_entries"
  add_foreign_key "dated_agenda_items", "dated_agenda_sections"
  add_foreign_key "dated_agenda_items", "dated_agendas"
  add_foreign_key "dated_agenda_items", "meeting_type_agenda_items"
  add_foreign_key "dated_agenda_items", "tracked_items"
  add_foreign_key "dated_agenda_roll_call_entries", "dated_agenda_items"
  add_foreign_key "dated_agenda_roll_call_entries", "people", on_delete: :nullify
  add_foreign_key "dated_agenda_roll_call_entries", "position_titles", on_delete: :nullify
  add_foreign_key "dated_agenda_sections", "dated_agendas"
  add_foreign_key "dated_agenda_sections", "meeting_type_agenda_sections"
  add_foreign_key "dated_agendas", "meeting_bodies"
  add_foreign_key "dated_agendas", "meeting_types"
  add_foreign_key "dated_agendas", "organizations"
  add_foreign_key "dated_agendas", "users", column: "approved_by_id"
  add_foreign_key "dated_agendas", "users", column: "published_by_id"
  add_foreign_key "dated_agendas", "users", column: "reopened_by_id"
  add_foreign_key "loops_roster_syncs", "roster_imports"
  add_foreign_key "loops_roster_syncs", "users", column: "requested_by_id", on_delete: :nullify
  add_foreign_key "magic_links", "sessions"
  add_foreign_key "magic_links", "users"
  add_foreign_key "meeting_bodies", "organizations"
  add_foreign_key "meeting_type_agenda_items", "agenda_item_catalog_entries"
  add_foreign_key "meeting_type_agenda_items", "meeting_type_agenda_sections"
  add_foreign_key "meeting_type_agenda_items", "meeting_types"
  add_foreign_key "meeting_type_agenda_sections", "meeting_types"
  add_foreign_key "meeting_types", "organizations"
  add_foreign_key "passkey_credentials", "users"
  add_foreign_key "permission_grants", "users"
  add_foreign_key "position_assignments", "people"
  add_foreign_key "position_assignments", "position_titles"
  add_foreign_key "position_titles", "organizations"
  add_foreign_key "sessions", "users"
  add_foreign_key "tracked_item_updates", "tracked_items"
  add_foreign_key "tracked_item_updates", "users", column: "author_id"
  add_foreign_key "tracked_items", "meeting_bodies"
  add_foreign_key "tracked_items", "organizations"
  add_foreign_key "tracked_items", "users", column: "completed_by_id"
  add_foreign_key "tracked_items", "users", column: "created_by_id"
  add_foreign_key "users", "people"
end
