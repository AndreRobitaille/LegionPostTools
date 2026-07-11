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

ActiveRecord::Schema[8.1].define(version: 2026_07_11_040000) do
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
    t.string "name", null: false
    t.string "timezone", default: "America/Chicago", null: false
    t.string "unit_number"
    t.string "unit_type", null: false
    t.datetime "updated_at", null: false
  end

  create_table "people", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address"
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "member_number"
    t.text "notes"
    t.string "phone_number"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_people_on_email_address"
    t.index ["member_number"], name: "index_people_on_member_number"
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

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.string "email_address", null: false
    t.datetime "email_verified_at"
    t.bigint "person_id", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["person_id"], name: "index_users_on_person_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "meeting_bodies", "organizations"
  add_foreign_key "permission_grants", "users"
  add_foreign_key "position_assignments", "people"
  add_foreign_key "position_assignments", "position_titles"
  add_foreign_key "position_titles", "organizations"
  add_foreign_key "users", "people"
end
