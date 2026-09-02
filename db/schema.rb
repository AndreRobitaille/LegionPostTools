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

ActiveRecord::Schema[8.1].define(version: 2026_09_02_010200) do
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
    t.check_constraint "state::text = ANY (ARRAY['processing'::character varying::text, 'completed'::character varying::text])", name: "agent_api_executions_state_check"
  end

  create_table "dated_agenda_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "agenda_item_catalog_entry_id"
    t.string "behavior_type", null: false
    t.datetime "created_at", null: false
    t.bigint "dated_agenda_id", null: false
    t.bigint "dated_agenda_section_id", null: false
    t.bigint "endeavor_id"
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
    t.datetime "updated_at", null: false
    t.index ["agenda_item_catalog_entry_id"], name: "index_dated_agenda_items_on_agenda_item_catalog_entry_id"
    t.index ["dated_agenda_id", "agenda_item_catalog_entry_id"], name: "index_dated_agenda_items_on_agenda_and_catalog_entry", unique: true
    t.index ["dated_agenda_id", "endeavor_id"], name: "idx_dated_agenda_items_agenda_endeavor", unique: true, where: "(endeavor_id IS NOT NULL)"
    t.index ["dated_agenda_id", "meeting_type_agenda_item_id"], name: "index_dated_agenda_items_on_agenda_and_mt_item", unique: true, where: "(meeting_type_agenda_item_id IS NOT NULL)"
    t.index ["dated_agenda_id", "source_key"], name: "index_dated_agenda_items_on_agenda_and_source_key", unique: true, where: "(source_key IS NOT NULL)"
    t.index ["dated_agenda_id"], name: "index_dated_agenda_items_on_dated_agenda_id"
    t.index ["dated_agenda_section_id", "position"], name: "idx_dated_agenda_items_section_position", unique: true
    t.index ["endeavor_id"], name: "index_dated_agenda_items_on_endeavor_id"
    t.index ["meeting_type_agenda_item_id"], name: "index_dated_agenda_items_on_meeting_type_agenda_item_id"
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
    t.text "location_address"
    t.string "location_name", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "meeting_body_id", null: false
    t.bigint "meeting_id", null: false
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
    t.index ["meeting_id"], name: "index_dated_agendas_on_meeting_id", unique: true
    t.index ["meeting_type_id"], name: "index_dated_agendas_on_meeting_type_id"
    t.index ["organization_id", "meeting_body_id", "meeting_type_id", "starts_at"], name: "index_dated_agendas_on_org_body_type_and_starts_at"
    t.index ["organization_id", "starts_at"], name: "index_dated_agendas_on_organization_id_and_starts_at"
    t.index ["organization_id", "status"], name: "index_dated_agendas_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_dated_agendas_on_organization_id"
    t.index ["published_by_id"], name: "index_dated_agendas_on_published_by_id"
    t.index ["reopened_by_id"], name: "index_dated_agendas_on_reopened_by_id"
  end

  create_table "endeavor_updates", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.bigint "endeavor_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_endeavor_updates_on_author_id"
    t.index ["endeavor_id"], name: "index_endeavor_updates_on_endeavor_id"
  end

  create_table "endeavors", force: :cascade do |t|
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
    t.index ["completed_by_id"], name: "index_endeavors_on_completed_by_id"
    t.index ["created_by_id"], name: "index_endeavors_on_created_by_id"
    t.index ["meeting_body_id"], name: "index_endeavors_on_meeting_body_id"
    t.index ["organization_id", "raise_by_on"], name: "index_endeavors_on_organization_id_and_raise_by_on"
    t.index ["organization_id", "status"], name: "index_endeavors_on_organization_id_and_status"
    t.index ["organization_id"], name: "index_endeavors_on_organization_id"
    t.check_constraint "importance::text = ANY (ARRAY['standard'::character varying::text, 'important'::character varying::text])", name: "endeavors_importance_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'completed'::character varying::text])", name: "endeavors_status_check"
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
    t.index ["status"], name: "idx_one_active_loops_roster_sync", unique: true, where: "((status)::text = ANY (ARRAY[('queued'::character varying)::text, ('running'::character varying)::text]))"
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
    t.check_constraint "purpose::text = ANY (ARRAY['sign_in'::character varying::text, 'create_agent_access_token'::character varying::text, 'official_minutes_action'::character varying::text])", name: "magic_links_purpose_check"
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

  create_table "meeting_minutes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_revision_id"
    t.text "location_address"
    t.string "location_name", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "meeting_body_id", null: false
    t.bigint "meeting_id", null: false
    t.bigint "meeting_type_id"
    t.bigint "organization_id", null: false
    t.datetime "starts_at", null: false
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["current_revision_id"], name: "index_meeting_minutes_on_current_revision_id"
    t.index ["meeting_body_id"], name: "index_meeting_minutes_on_meeting_body_id"
    t.index ["meeting_id"], name: "index_meeting_minutes_on_meeting_id", unique: true
    t.index ["meeting_type_id"], name: "index_meeting_minutes_on_meeting_type_id"
    t.index ["organization_id", "starts_at"], name: "index_meeting_minutes_on_organization_id_and_starts_at"
    t.index ["organization_id"], name: "index_meeting_minutes_on_organization_id"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'approved'::character varying, 'attested'::character varying, 'membership_approved'::character varying]::text[])", name: "meeting_minutes_status_check"
  end

  create_table "meeting_transcripts", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "media_type", null: false
    t.bigint "meeting_id", null: false
    t.bigint "organization_id", null: false
    t.string "original_filename"
    t.datetime "purge_scheduled_at"
    t.datetime "purged_at"
    t.bigint "purged_by_id"
    t.string "retention_policy", default: "delete_after_acceptance", null: false
    t.string "sha256_digest", null: false
    t.string "source_kind", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_meeting_transcripts_on_created_by_id"
    t.index ["meeting_id"], name: "index_meeting_transcripts_on_meeting_id", unique: true
    t.index ["organization_id"], name: "index_meeting_transcripts_on_organization_id"
    t.index ["purged_by_id"], name: "index_meeting_transcripts_on_purged_by_id"
    t.index ["sha256_digest"], name: "index_meeting_transcripts_on_sha256_digest"
    t.check_constraint "byte_size >= 0", name: "meeting_transcripts_byte_size_check"
    t.check_constraint "retention_policy::text = ANY (ARRAY['delete_after_acceptance'::character varying::text, 'retain_restricted'::character varying::text])", name: "meeting_transcripts_retention_policy_check"
    t.check_constraint "source_kind::text = ANY (ARRAY['pasted_text'::character varying::text, 'text_upload'::character varying::text])", name: "meeting_transcripts_source_kind_check"
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

  create_table "meetings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "location_address"
    t.string "location_name", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "meeting_body_id", null: false
    t.bigint "meeting_type_id"
    t.bigint "organization_id", null: false
    t.datetime "starts_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_body_id"], name: "index_meetings_on_meeting_body_id"
    t.index ["meeting_type_id"], name: "index_meetings_on_meeting_type_id"
    t.index ["organization_id", "starts_at"], name: "index_meetings_on_organization_id_and_starts_at"
    t.index ["organization_id"], name: "index_meetings_on_organization_id"
  end

  create_table "minutes_attendance_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dated_agenda_roll_call_entry_id"
    t.integer "lock_version", default: 0, null: false
    t.bigint "meeting_minutes_id", null: false
    t.string "office_name", null: false
    t.bigint "person_id"
    t.string "person_name"
    t.integer "position", null: false
    t.bigint "position_title_id"
    t.string "status", default: "not_recorded", null: false
    t.datetime "updated_at", null: false
    t.index ["dated_agenda_roll_call_entry_id"], name: "index_minutes_attendance_on_agenda_roll_call"
    t.index ["meeting_minutes_id", "position"], name: "index_minutes_attendance_on_minutes_and_position", unique: true
    t.index ["meeting_minutes_id"], name: "index_minutes_attendance_entries_on_meeting_minutes_id"
    t.index ["person_id"], name: "index_minutes_attendance_entries_on_person_id"
    t.index ["position_title_id"], name: "index_minutes_attendance_entries_on_position_title_id"
    t.check_constraint "\"position\" > 0", name: "minutes_attendance_position_check"
    t.check_constraint "status::text = ANY (ARRAY['present'::character varying::text, 'absent'::character varying::text, 'excused'::character varying::text, 'vacant'::character varying::text, 'not_recorded'::character varying::text])", name: "minutes_attendance_status_check"
  end

  create_table "minutes_attestations", force: :cascade do |t|
    t.datetime "attested_at", null: false
    t.bigint "attested_by_id", null: false
    t.string "attester_name", null: false
    t.string "attester_office", null: false
    t.datetime "created_at", null: false
    t.bigint "minutes_revision_id", null: false
    t.bigint "official_action_confirmation_id", null: false
    t.bigint "recorded_by_id", null: false
    t.datetime "updated_at", null: false
    t.index ["attested_by_id"], name: "index_minutes_attestations_on_attested_by_id"
    t.index ["minutes_revision_id"], name: "index_minutes_attestations_on_minutes_revision_id", unique: true
    t.index ["official_action_confirmation_id"], name: "index_minutes_attestations_on_official_action_confirmation_id", unique: true
    t.index ["recorded_by_id"], name: "index_minutes_attestations_on_recorded_by_id"
  end

  create_table "minutes_draft_runs", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.bigint "discarded_by_id"
    t.string "error_category"
    t.integer "input_tokens"
    t.bigint "meeting_minutes_id", null: false
    t.bigint "meeting_transcript_id", null: false
    t.string "model", null: false
    t.integer "output_tokens"
    t.string "prompt_sha256", null: false
    t.string "prompt_version", null: false
    t.string "provider", null: false
    t.string "provider_request_id"
    t.string "provider_response_id"
    t.string "reasoning_effort", null: false
    t.integer "reasoning_tokens"
    t.bigint "requested_by_id", null: false
    t.bigint "retry_of_id"
    t.string "schema_version", null: false
    t.integer "source_line_count", null: false
    t.string "source_sha256", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.string "text_verbosity", null: false
    t.integer "total_tokens"
    t.datetime "updated_at", null: false
    t.index ["discarded_by_id"], name: "index_minutes_draft_runs_on_discarded_by_id"
    t.index ["meeting_minutes_id", "created_at"], name: "index_minutes_draft_runs_on_meeting_minutes_id_and_created_at"
    t.index ["meeting_minutes_id"], name: "index_minutes_draft_runs_on_meeting_minutes_id"
    t.index ["meeting_transcript_id"], name: "index_minutes_draft_runs_on_meeting_transcript_id"
    t.index ["requested_by_id"], name: "index_minutes_draft_runs_on_requested_by_id"
    t.index ["retry_of_id"], name: "idx_one_active_minutes_draft_retry", unique: true, where: "((retry_of_id IS NOT NULL) AND ((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('running'::character varying)::text])))"
    t.index ["retry_of_id"], name: "index_minutes_draft_runs_on_retry_of_id"
    t.index ["status", "discarded_at"], name: "index_minutes_draft_runs_on_status_and_discarded_at"
    t.check_constraint "source_line_count > 0", name: "minutes_draft_runs_source_line_count_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'running'::character varying::text, 'succeeded'::character varying::text, 'failed'::character varying::text])", name: "minutes_draft_runs_status_check"
  end

  create_table "minutes_draft_suggestions", force: :cascade do |t|
    t.bigint "applied_record_id"
    t.string "applied_record_type"
    t.string "confidence", null: false
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.bigint "minutes_attendance_entry_id"
    t.bigint "minutes_draft_run_id", null: false
    t.bigint "minutes_item_id"
    t.bigint "minutes_section_id"
    t.jsonb "missing_facts", default: [], null: false
    t.jsonb "payload", default: {}, null: false
    t.string "review_state", default: "unreviewed", null: false
    t.datetime "reviewed_at"
    t.bigint "reviewed_by_id"
    t.bigint "source_dated_agenda_item_id"
    t.integer "source_end_line", null: false
    t.integer "source_start_line", null: false
    t.datetime "updated_at", null: false
    t.index ["applied_record_type", "applied_record_id"], name: "index_minutes_draft_suggestions_on_applied_record"
    t.index ["minutes_attendance_entry_id"], name: "index_minutes_draft_suggestions_on_minutes_attendance_entry_id"
    t.index ["minutes_draft_run_id", "review_state"], name: "index_minutes_draft_suggestions_on_run_and_review_state"
    t.index ["minutes_draft_run_id"], name: "index_minutes_draft_suggestions_on_minutes_draft_run_id"
    t.index ["minutes_item_id"], name: "index_minutes_draft_suggestions_on_minutes_item_id"
    t.index ["minutes_section_id"], name: "index_minutes_draft_suggestions_on_minutes_section_id"
    t.index ["reviewed_by_id"], name: "index_minutes_draft_suggestions_on_reviewed_by_id"
    t.index ["source_dated_agenda_item_id"], name: "index_minutes_draft_suggestions_on_source_dated_agenda_item_id"
    t.check_constraint "confidence::text = ANY (ARRAY['high'::character varying::text, 'medium'::character varying::text, 'low'::character varying::text])", name: "minutes_draft_suggestions_confidence_check"
    t.check_constraint "kind::text = ANY (ARRAY['item_summary'::character varying::text, 'outcome'::character varying::text, 'attendance'::character varying::text, 'additional_item'::character varying::text])", name: "minutes_draft_suggestions_kind_check"
    t.check_constraint "review_state::text = ANY (ARRAY['unreviewed'::character varying::text, 'used'::character varying::text, 'edited'::character varying::text, 'discarded'::character varying::text])", name: "minutes_draft_suggestions_review_state_check"
    t.check_constraint "source_start_line > 0 AND source_end_line >= source_start_line", name: "minutes_draft_suggestions_source_range_check"
  end

  create_table "minutes_items", force: :cascade do |t|
    t.string "behavior_type", null: false
    t.datetime "created_at", null: false
    t.bigint "endeavor_id"
    t.integer "lock_version", default: 0, null: false
    t.bigint "minutes_section_id", null: false
    t.integer "position", null: false
    t.string "record_key", null: false
    t.bigint "source_dated_agenda_item_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["endeavor_id"], name: "index_minutes_items_on_endeavor_id"
    t.index ["minutes_section_id", "position"], name: "index_minutes_items_on_section_and_position", unique: true
    t.index ["minutes_section_id"], name: "index_minutes_items_on_minutes_section_id"
    t.index ["record_key"], name: "index_minutes_items_on_record_key", unique: true
    t.index ["source_dated_agenda_item_id"], name: "index_minutes_items_on_source_dated_agenda_item_id"
    t.check_constraint "\"position\" > 0", name: "minutes_items_position_check"
  end

  create_table "minutes_lifecycle_events", force: :cascade do |t|
    t.bigint "actor_id", null: false
    t.string "actor_name", null: false
    t.string "actor_office", null: false
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.string "from_status", null: false
    t.bigint "meeting_minutes_id", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "minutes_revision_id", null: false
    t.datetime "occurred_at", null: false
    t.bigint "official_action_confirmation_id", null: false
    t.bigint "recorded_by_id", null: false
    t.string "to_status", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_minutes_lifecycle_events_on_actor_id"
    t.index ["meeting_minutes_id"], name: "index_minutes_lifecycle_events_on_meeting_minutes_id"
    t.index ["minutes_revision_id"], name: "index_minutes_lifecycle_events_on_minutes_revision_id"
    t.index ["official_action_confirmation_id"], name: "idx_on_official_action_confirmation_id_7ceb2b7c93", unique: true
    t.index ["recorded_by_id"], name: "index_minutes_lifecycle_events_on_recorded_by_id"
    t.check_constraint "event_type::text = ANY (ARRAY['approved'::character varying, 'attested'::character varying, 'reopened'::character varying, 'membership_approved'::character varying]::text[])", name: "minutes_lifecycle_events_type_check"
  end

  create_table "minutes_membership_approvals", force: :cascade do |t|
    t.bigint "approving_meeting_id", null: false
    t.datetime "created_at", null: false
    t.string "disposition", null: false
    t.text "factual_note"
    t.bigint "meeting_minutes_id", null: false
    t.bigint "minutes_revision_id", null: false
    t.bigint "official_action_confirmation_id", null: false
    t.datetime "recorded_at", null: false
    t.bigint "recorded_by_id", null: false
    t.string "recorder_name", null: false
    t.string "recorder_office", null: false
    t.datetime "updated_at", null: false
    t.index ["approving_meeting_id"], name: "index_minutes_membership_approvals_on_approving_meeting_id"
    t.index ["meeting_minutes_id"], name: "index_minutes_membership_approvals_on_meeting_minutes_id", unique: true
    t.index ["minutes_revision_id"], name: "index_minutes_membership_approvals_on_minutes_revision_id", unique: true
    t.index ["official_action_confirmation_id"], name: "idx_on_official_action_confirmation_id_40172e0bce", unique: true
    t.index ["recorded_by_id"], name: "index_minutes_membership_approvals_on_recorded_by_id"
    t.check_constraint "disposition::text = ANY (ARRAY['approved_as_presented'::character varying, 'approved_as_corrected'::character varying, 'approved_by_motion'::character varying, 'other'::character varying]::text[])", name: "minutes_membership_approvals_disposition_check"
  end

  create_table "minutes_outcomes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "disposition", default: "not_recorded", null: false
    t.string "kind", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "minutes_item_id", null: false
    t.string "mover_name"
    t.bigint "mover_person_id"
    t.integer "position", null: false
    t.string "seconder_name"
    t.bigint "seconder_person_id"
    t.text "text", null: false
    t.datetime "updated_at", null: false
    t.string "vote_summary"
    t.index ["minutes_item_id", "position"], name: "index_minutes_outcomes_on_item_and_position", unique: true
    t.index ["minutes_item_id"], name: "index_minutes_outcomes_on_minutes_item_id"
    t.index ["mover_person_id"], name: "index_minutes_outcomes_on_mover_person_id"
    t.index ["seconder_person_id"], name: "index_minutes_outcomes_on_seconder_person_id"
    t.check_constraint "\"position\" > 0", name: "minutes_outcomes_position_check"
    t.check_constraint "disposition::text = ANY (ARRAY['adopted'::character varying::text, 'lost'::character varying::text, 'withdrawn'::character varying::text, 'postponed'::character varying::text, 'referred'::character varying::text, 'no_vote'::character varying::text, 'not_recorded'::character varying::text])", name: "minutes_outcomes_disposition_check"
    t.check_constraint "kind::text = ANY (ARRAY['motion'::character varying::text, 'decision'::character varying::text])", name: "minutes_outcomes_kind_check"
  end

  create_table "minutes_revisions", force: :cascade do |t|
    t.datetime "approved_at", null: false
    t.bigint "approved_by_id", null: false
    t.string "approver_name", null: false
    t.string "approver_office", null: false
    t.datetime "created_at", null: false
    t.bigint "meeting_minutes_id", null: false
    t.integer "number", null: false
    t.jsonb "payload", null: false
    t.string "sha256", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_minutes_revisions_on_approved_by_id"
    t.index ["meeting_minutes_id", "number"], name: "index_minutes_revisions_on_meeting_minutes_id_and_number", unique: true
    t.index ["meeting_minutes_id", "sha256"], name: "index_minutes_revisions_on_meeting_minutes_id_and_sha256"
    t.index ["meeting_minutes_id"], name: "index_minutes_revisions_on_meeting_minutes_id"
    t.check_constraint "number > 0", name: "minutes_revisions_number_check"
  end

  create_table "minutes_sections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "meeting_minutes_id", null: false
    t.integer "position", null: false
    t.bigint "source_dated_agenda_section_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_minutes_id", "position"], name: "index_minutes_sections_on_minutes_and_position", unique: true
    t.index ["meeting_minutes_id"], name: "index_minutes_sections_on_meeting_minutes_id"
    t.index ["source_dated_agenda_section_id"], name: "index_minutes_sections_on_source_dated_agenda_section_id"
    t.check_constraint "\"position\" > 0", name: "minutes_sections_position_check"
  end

  create_table "official_action_confirmations", force: :cascade do |t|
    t.string "action", null: false
    t.jsonb "action_payload", default: {}, null: false
    t.bigint "agent_access_token_id"
    t.string "confirmation_method", default: "in_app", null: false
    t.datetime "confirmed_at"
    t.datetime "consumed_at"
    t.string "content_digest", null: false
    t.datetime "created_at", null: false
    t.text "evidence_note"
    t.datetime "expires_at", null: false
    t.bigint "meeting_minutes_id", null: false
    t.integer "record_lock_version", null: false
    t.bigint "session_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["agent_access_token_id"], name: "index_official_action_confirmations_on_agent_access_token_id"
    t.index ["meeting_minutes_id"], name: "index_official_action_confirmations_on_meeting_minutes_id"
    t.index ["session_id"], name: "index_official_action_confirmations_on_session_id"
    t.index ["user_id"], name: "index_official_action_confirmations_on_user_id"
    t.check_constraint "action::text = ANY (ARRAY['approve'::character varying, 'attest'::character varying, 'reopen'::character varying, 'record_membership_approval'::character varying]::text[])", name: "official_action_confirmations_action_check"
    t.check_constraint "confirmation_method::text = ANY (ARRAY['in_app'::character varying::text, 'delegated_agent'::character varying::text, 'external_written_confirmation'::character varying::text])", name: "official_action_confirmations_method_check"
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
    t.check_constraint "capability::text = ANY (ARRAY['manage_settings'::character varying, 'manage_people'::character varying, 'manage_meeting_bodies'::character varying, 'manage_agendas'::character varying, 'manage_minutes'::character varying, 'approve_minutes'::character varying, 'attest_minutes'::character varying, 'record_minutes_approval'::character varying, 'view_internal_records'::character varying]::text[])", name: "permission_grants_capability_check"
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

  create_table "position_capability_grants", force: :cascade do |t|
    t.string "capability", null: false
    t.datetime "created_at", null: false
    t.bigint "position_title_id", null: false
    t.datetime "updated_at", null: false
    t.index ["position_title_id", "capability"], name: "index_position_capabilities_on_title_and_capability", unique: true
    t.index ["position_title_id"], name: "index_position_capability_grants_on_position_title_id"
    t.check_constraint "capability::text = ANY (ARRAY['manage_people'::character varying, 'manage_meeting_bodies'::character varying, 'manage_agendas'::character varying, 'manage_minutes'::character varying, 'approve_minutes'::character varying, 'attest_minutes'::character varying, 'record_minutes_approval'::character varying, 'view_internal_records'::character varying]::text[])", name: "position_capability_grants_capability_check"
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

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.string "disabled_reason"
    t.string "disabled_reason_detail"
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
    t.index ["disabled_reason"], name: "index_users_on_disabled_reason"
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
  add_foreign_key "dated_agenda_items", "endeavors"
  add_foreign_key "dated_agenda_items", "meeting_type_agenda_items"
  add_foreign_key "dated_agenda_roll_call_entries", "dated_agenda_items"
  add_foreign_key "dated_agenda_roll_call_entries", "people", on_delete: :nullify
  add_foreign_key "dated_agenda_roll_call_entries", "position_titles", on_delete: :nullify
  add_foreign_key "dated_agenda_sections", "dated_agendas"
  add_foreign_key "dated_agenda_sections", "meeting_type_agenda_sections"
  add_foreign_key "dated_agendas", "meeting_bodies"
  add_foreign_key "dated_agendas", "meeting_types"
  add_foreign_key "dated_agendas", "meetings"
  add_foreign_key "dated_agendas", "organizations"
  add_foreign_key "dated_agendas", "users", column: "approved_by_id"
  add_foreign_key "dated_agendas", "users", column: "published_by_id"
  add_foreign_key "dated_agendas", "users", column: "reopened_by_id"
  add_foreign_key "endeavor_updates", "endeavors"
  add_foreign_key "endeavor_updates", "users", column: "author_id"
  add_foreign_key "endeavors", "meeting_bodies"
  add_foreign_key "endeavors", "organizations"
  add_foreign_key "endeavors", "users", column: "completed_by_id"
  add_foreign_key "endeavors", "users", column: "created_by_id"
  add_foreign_key "loops_roster_syncs", "roster_imports"
  add_foreign_key "loops_roster_syncs", "users", column: "requested_by_id", on_delete: :nullify
  add_foreign_key "magic_links", "sessions"
  add_foreign_key "magic_links", "users"
  add_foreign_key "meeting_bodies", "organizations"
  add_foreign_key "meeting_minutes", "meeting_bodies"
  add_foreign_key "meeting_minutes", "meeting_types"
  add_foreign_key "meeting_minutes", "meetings"
  add_foreign_key "meeting_minutes", "minutes_revisions", column: "current_revision_id"
  add_foreign_key "meeting_minutes", "organizations"
  add_foreign_key "meeting_transcripts", "meetings"
  add_foreign_key "meeting_transcripts", "organizations"
  add_foreign_key "meeting_transcripts", "users", column: "created_by_id"
  add_foreign_key "meeting_transcripts", "users", column: "purged_by_id"
  add_foreign_key "meeting_type_agenda_items", "agenda_item_catalog_entries"
  add_foreign_key "meeting_type_agenda_items", "meeting_type_agenda_sections"
  add_foreign_key "meeting_type_agenda_items", "meeting_types"
  add_foreign_key "meeting_type_agenda_sections", "meeting_types"
  add_foreign_key "meeting_types", "organizations"
  add_foreign_key "meetings", "meeting_bodies"
  add_foreign_key "meetings", "meeting_types"
  add_foreign_key "meetings", "organizations"
  add_foreign_key "minutes_attendance_entries", "dated_agenda_roll_call_entries"
  add_foreign_key "minutes_attendance_entries", "meeting_minutes", column: "meeting_minutes_id"
  add_foreign_key "minutes_attendance_entries", "people", on_delete: :nullify
  add_foreign_key "minutes_attendance_entries", "position_titles", on_delete: :nullify
  add_foreign_key "minutes_attestations", "minutes_revisions"
  add_foreign_key "minutes_attestations", "official_action_confirmations"
  add_foreign_key "minutes_attestations", "users", column: "attested_by_id"
  add_foreign_key "minutes_attestations", "users", column: "recorded_by_id"
  add_foreign_key "minutes_draft_runs", "meeting_minutes", column: "meeting_minutes_id"
  add_foreign_key "minutes_draft_runs", "meeting_transcripts"
  add_foreign_key "minutes_draft_runs", "minutes_draft_runs", column: "retry_of_id"
  add_foreign_key "minutes_draft_runs", "users", column: "discarded_by_id", on_delete: :nullify
  add_foreign_key "minutes_draft_runs", "users", column: "requested_by_id"
  add_foreign_key "minutes_draft_suggestions", "dated_agenda_items", column: "source_dated_agenda_item_id"
  add_foreign_key "minutes_draft_suggestions", "minutes_attendance_entries"
  add_foreign_key "minutes_draft_suggestions", "minutes_draft_runs"
  add_foreign_key "minutes_draft_suggestions", "minutes_items"
  add_foreign_key "minutes_draft_suggestions", "minutes_sections"
  add_foreign_key "minutes_draft_suggestions", "users", column: "reviewed_by_id"
  add_foreign_key "minutes_items", "dated_agenda_items", column: "source_dated_agenda_item_id"
  add_foreign_key "minutes_items", "endeavors"
  add_foreign_key "minutes_items", "minutes_sections"
  add_foreign_key "minutes_lifecycle_events", "meeting_minutes", column: "meeting_minutes_id"
  add_foreign_key "minutes_lifecycle_events", "minutes_revisions"
  add_foreign_key "minutes_lifecycle_events", "official_action_confirmations"
  add_foreign_key "minutes_lifecycle_events", "users", column: "actor_id"
  add_foreign_key "minutes_lifecycle_events", "users", column: "recorded_by_id"
  add_foreign_key "minutes_membership_approvals", "meeting_minutes", column: "meeting_minutes_id"
  add_foreign_key "minutes_membership_approvals", "meetings", column: "approving_meeting_id"
  add_foreign_key "minutes_membership_approvals", "minutes_revisions"
  add_foreign_key "minutes_membership_approvals", "official_action_confirmations"
  add_foreign_key "minutes_membership_approvals", "users", column: "recorded_by_id"
  add_foreign_key "minutes_outcomes", "minutes_items"
  add_foreign_key "minutes_outcomes", "people", column: "mover_person_id", on_delete: :nullify
  add_foreign_key "minutes_outcomes", "people", column: "seconder_person_id", on_delete: :nullify
  add_foreign_key "minutes_revisions", "meeting_minutes", column: "meeting_minutes_id"
  add_foreign_key "minutes_revisions", "users", column: "approved_by_id"
  add_foreign_key "minutes_sections", "dated_agenda_sections", column: "source_dated_agenda_section_id"
  add_foreign_key "minutes_sections", "meeting_minutes", column: "meeting_minutes_id"
  add_foreign_key "official_action_confirmations", "agent_access_tokens"
  add_foreign_key "official_action_confirmations", "meeting_minutes", column: "meeting_minutes_id"
  add_foreign_key "official_action_confirmations", "sessions"
  add_foreign_key "official_action_confirmations", "users"
  add_foreign_key "passkey_credentials", "users"
  add_foreign_key "permission_grants", "users"
  add_foreign_key "position_assignments", "people"
  add_foreign_key "position_assignments", "position_titles"
  add_foreign_key "position_capability_grants", "position_titles", on_delete: :cascade
  add_foreign_key "position_titles", "organizations"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "people"
end
