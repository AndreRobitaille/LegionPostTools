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

ActiveRecord::Schema[8.1].define(version: 2026_07_12_141403) do
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

  create_table "installations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "setup_completed_at"
    t.string "singleton_key", null: false
    t.datetime "updated_at", null: false
    t.index ["singleton_key"], name: "index_installations_on_singleton_key", unique: true
  end

  create_table "magic_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_magic_links_on_token_digest", unique: true
    t.index ["user_id"], name: "index_magic_links_on_user_id"
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

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "default_location_address"
    t.string "default_location_name"
    t.string "locality"
    t.string "name", null: false
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
    t.string "email_address", null: false
    t.datetime "email_verified_at"
    t.bigint "person_id", null: false
    t.string "roster_email_review_decision"
    t.string "roster_email_reviewed_address"
    t.datetime "roster_email_reviewed_at"
    t.datetime "updated_at", null: false
    t.string "webauthn_id", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["person_id"], name: "index_users_on_person_id", unique: true
    t.index ["webauthn_id"], name: "index_users_on_webauthn_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "magic_links", "users"
  add_foreign_key "meeting_bodies", "organizations"
  add_foreign_key "passkey_credentials", "users"
  add_foreign_key "permission_grants", "users"
  add_foreign_key "position_assignments", "people"
  add_foreign_key "position_assignments", "position_titles"
  add_foreign_key "position_titles", "organizations"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "people"
end
