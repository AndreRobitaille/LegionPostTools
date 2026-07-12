# Admin and Roster Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a roster-backed Administration section that imports National American Legion roster CSV data, manages person-to-user links, assigns app permissions and post roles, and prompts users when roster email differs from login email.

**Architecture:** Keep imported roster fields on `Person` so the existing person/user/position model remains simple. Add `RosterImport` records for audit/freshness, a CSV parser/importer service boundary, and an `Admin` namespace for all roster, people, account, permission, and position workflows. Store roster/login email review state on `User` so the sign-in prompt can be shown once per imported roster email unless the user chooses “remind me later.”

**Tech Stack:** Rails 8.1, PostgreSQL, Minitest, Hotwire/Turbo, Tailwind CSS, importmap, passwordless auth already present in the app.

---

## File Structure

Create or modify these files:

- Create `db/migrate/*_create_roster_imports.rb` — stores roster import audit/freshness records.
- Create `db/migrate/*_add_roster_fields_to_people.rb` — adds read-only imported roster fields to people.
- Create `db/migrate/*_add_roster_email_review_to_users.rb` — tracks one-time/remind-later email mismatch prompts.
- Modify `app/models/person.rb` — expose roster-name parsing helpers and roster freshness helpers.
- Modify `app/models/user.rb` — expose roster/login email mismatch state and decisions.
- Create `app/models/roster_import.rb` — import audit model.
- Create `app/services/roster_imports/csv_parser.rb` — parse and validate the National roster CSV.
- Create `app/services/roster_imports/importer.rb` — atomically upsert people by Member ID.
- Modify `app/controllers/application_controller.rb` — add reusable capability authorization.
- Create `app/controllers/admin/base_controller.rb` — authenticated admin namespace base.
- Create `app/controllers/admin/dashboard_controller.rb` — admin landing page.
- Create `app/controllers/admin/roster_imports_controller.rb` — upload and result flow.
- Create `app/controllers/admin/people_controller.rb` — member list and detail pages.
- Create `app/controllers/admin/user_accounts_controller.rb` — create/enable/disable login for a person.
- Create `app/controllers/admin/permission_grants_controller.rb` — update user capabilities.
- Create `app/controllers/admin/position_assignments_controller.rb` — assign/end person roles.
- Create `app/controllers/roster_email_reviews_controller.rb` — post-login email mismatch resolution.
- Modify `app/controllers/dashboard_controller.rb` — expose email review prompt state.
- Modify `config/routes.rb` — add admin and email-review routes.
- Modify `app/views/shared/_app_header.html.erb` — show Admin link for authorized users.
- Create `app/views/admin/dashboard/show.html.erb`.
- Create `app/views/admin/roster_imports/new.html.erb`.
- Create `app/views/admin/roster_imports/show.html.erb`.
- Create `app/views/admin/people/index.html.erb`.
- Create `app/views/admin/people/show.html.erb`.
- Create `app/views/dashboard/_roster_email_review.html.erb`.
- Modify `app/views/dashboard/show.html.erb` — render email mismatch prompt.
- Create model/service/controller tests listed in the tasks below.

Keep the first implementation boring: no JavaScript required, no background jobs, no manual roster edits, and no CSV column autodetection beyond the known National export headers.

---

### Task 1: Schema and Models for Roster Imports

**Files:**
- Create: `db/migrate/*_create_roster_imports.rb`
- Create: `db/migrate/*_add_roster_fields_to_people.rb`
- Create: `db/migrate/*_add_roster_email_review_to_users.rb`
- Create: `app/models/roster_import.rb`
- Modify: `app/models/person.rb`
- Modify: `app/models/user.rb`
- Test: `test/models/roster_import_test.rb`
- Test: `test/models/person_test.rb`
- Test: `test/models/user_test.rb`

- [ ] **Step 1: Write failing model tests**

Add to `test/models/roster_import_test.rb`:

```ruby
require "test_helper"

class RosterImportTest < ActiveSupport::TestCase
  test "latest_successful returns newest successful import" do
    older = RosterImport.create!(status: "completed", imported_at: 2.days.ago, uploaded_filename: "old.csv")
    newer = RosterImport.create!(status: "completed", imported_at: 1.day.ago, uploaded_filename: "new.csv")
    RosterImport.create!(status: "failed", imported_at: Time.current, uploaded_filename: "bad.csv")

    assert_equal newer, RosterImport.latest_successful
    assert_not_equal older, RosterImport.latest_successful
  end

  test "stale when newest successful import is older than thirty days" do
    RosterImport.create!(status: "completed", imported_at: 31.days.ago, uploaded_filename: "old.csv")

    assert RosterImport.roster_stale?
  end

  test "fresh when newest successful import is within thirty days" do
    RosterImport.create!(status: "completed", imported_at: 5.days.ago, uploaded_filename: "fresh.csv")

    assert_not RosterImport.roster_stale?
  end
end
```

Add to `test/models/person_test.rb`:

```ruby
test "roster display name uses imported roster name when present" do
  person = Person.new(first_name: "Vincent", last_name: "Alber", roster_name: "Alber, Vincent")

  assert_equal "Alber, Vincent", person.roster_display_name
end

test "roster display name falls back to full name" do
  person = Person.new(first_name: "Jane", last_name: "Doe")

  assert_equal "Jane Doe", person.roster_display_name
end
```

Add to `test/models/user_test.rb`:

```ruby
test "detects unresolved roster email mismatch" do
  person = Person.create!(first_name: "Jane", last_name: "Doe", roster_email_address: "roster@example.com")
  user = User.create!(person: person, email_address: "login@example.com", email_verified_at: Time.current)

  assert user.roster_email_mismatch?
  assert user.needs_roster_email_review?
end

test "does not prompt again after keeping current login email for same roster email" do
  person = Person.create!(first_name: "Jane", last_name: "Doe", roster_email_address: "roster@example.com")
  user = User.create!(person: person, email_address: "login@example.com", email_verified_at: Time.current)

  user.keep_current_login_email!

  assert user.roster_email_mismatch?
  assert_not user.needs_roster_email_review?
end

test "prompts again after remind me later" do
  person = Person.create!(first_name: "Jane", last_name: "Doe", roster_email_address: "roster@example.com")
  user = User.create!(person: person, email_address: "login@example.com", email_verified_at: Time.current)

  user.remind_later_about_roster_email!

  assert user.needs_roster_email_review?
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/models/roster_import_test.rb test/models/person_test.rb test/models/user_test.rb
```

Expected: failures mentioning missing `RosterImport`, missing roster columns, and missing email review methods.

- [ ] **Step 3: Add migrations**

Create `db/migrate/*_create_roster_imports.rb`:

```ruby
class CreateRosterImports < ActiveRecord::Migration[8.1]
  def change
    create_table :roster_imports do |t|
      t.string :uploaded_filename, null: false
      t.string :status, null: false, default: "completed"
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :unchanged_count, null: false, default: 0
      t.integer :problem_count, null: false, default: 0
      t.jsonb :summary, null: false, default: {}
      t.datetime :imported_at, null: false

      t.timestamps
    end

    add_index :roster_imports, [ :status, :imported_at ]
  end
end
```

Create `db/migrate/*_add_roster_fields_to_people.rb`:

```ruby
class AddRosterFieldsToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :roster_name, :string
    add_column :people, :roster_post, :string
    add_column :people, :roster_membership_type, :string
    add_column :people, :roster_address, :text
    add_column :people, :roster_undeliverable, :boolean, null: false, default: false
    add_column :people, :roster_email_address, :string
    add_column :people, :roster_phone_number, :string
    add_column :people, :roster_branch, :string
    add_column :people, :roster_war_era, :string
    add_column :people, :roster_continuous_years, :integer
    add_column :people, :roster_paid_through_year, :integer
    add_column :people, :roster_member_status, :string
    add_column :people, :roster_imported_at, :datetime

    add_index :people, :roster_email_address
    add_index :people, :roster_member_status
    add_index :people, :roster_paid_through_year
    remove_index :people, :member_number if index_exists?(:people, :member_number)
    add_index :people, :member_number, unique: true, where: "member_number IS NOT NULL"
  end
end
```

Create `db/migrate/*_add_roster_email_review_to_users.rb`:

```ruby
class AddRosterEmailReviewToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :roster_email_reviewed_address, :string
    add_column :users, :roster_email_review_decision, :string
    add_column :users, :roster_email_reviewed_at, :datetime
  end
end
```

- [ ] **Step 4: Add model code**

Create `app/models/roster_import.rb`:

```ruby
class RosterImport < ApplicationRecord
  STATUSES = %w[completed failed].freeze
  STALE_AFTER = 30.days

  validates :uploaded_filename, :status, :imported_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :created_count, :updated_count, :unchanged_count, :problem_count,
    numericality: { greater_than_or_equal_to: 0 }

  scope :successful, -> { where(status: "completed") }

  def self.latest_successful
    successful.order(imported_at: :desc, id: :desc).first
  end

  def self.roster_stale?
    latest = latest_successful
    latest.blank? || latest.imported_at < STALE_AFTER.ago
  end
end
```

Modify `app/models/person.rb`:

```ruby
class Person < ApplicationRecord
  has_one :user, dependent: :destroy
  has_many :position_assignments, dependent: :destroy
  has_many :position_titles, through: :position_assignments

  normalizes :roster_email_address, with: ->(value) { value&.strip&.downcase }

  validates :first_name, :last_name, presence: true
  validates :member_number, uniqueness: { allow_blank: true }

  def full_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def roster_display_name
    roster_name.presence || full_name
  end

  def current_role_label
    today = Date.current
    position_assignments
      .select { |assignment| assignment.active_on?(today) }
      .map(&:position_title)
      .min_by(&:display_order)
      &.name
  end
end
```

Modify `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  belongs_to :person
  has_many :permission_grants, dependent: :destroy
  has_many :passkey_credentials, dependent: :destroy

  normalizes :email_address, with: ->(value) { value.strip.downcase }

  before_validation :assign_webauthn_id, on: :create

  validates :email_address, presence: true, uniqueness: true
  validates :person_id, uniqueness: true
  validates :webauthn_id, presence: true, uniqueness: true

  def can?(capability)
    permission_grants.exists?(capability: capability.to_s)
  end

  def roster_email_mismatch?
    person.roster_email_address.present? && person.roster_email_address != email_address
  end

  def needs_roster_email_review?
    return false unless roster_email_mismatch?
    return true if roster_email_review_decision == "remind_later"

    roster_email_reviewed_address != person.roster_email_address
  end

  def keep_current_login_email!
    update!(
      roster_email_reviewed_address: person.roster_email_address,
      roster_email_review_decision: "keep_current",
      roster_email_reviewed_at: Time.current
    )
  end

  def remind_later_about_roster_email!
    update!(
      roster_email_reviewed_address: person.roster_email_address,
      roster_email_review_decision: "remind_later",
      roster_email_reviewed_at: Time.current
    )
  end

  def update_login_email_to_roster_email!
    update!(
      email_address: person.roster_email_address,
      roster_email_reviewed_address: person.roster_email_address,
      roster_email_review_decision: "updated_login",
      roster_email_reviewed_at: Time.current
    )
  end

  private

  def assign_webauthn_id
    self.webauthn_id ||= WebAuthn.generate_user_id
  end
end
```

- [ ] **Step 5: Run migrations and focused tests**

Run:

```bash
bin/rails db:migrate
bin/rails test test/models/roster_import_test.rb test/models/person_test.rb test/models/user_test.rb
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add db/migrate app/models test/models db/schema.rb
git commit -m "feat: add roster import data model"
```

---

### Task 2: CSV Parser and Atomic Importer

**Files:**
- Create: `app/services/roster_imports/csv_parser.rb`
- Create: `app/services/roster_imports/importer.rb`
- Test: `test/services/roster_imports/csv_parser_test.rb`
- Test: `test/services/roster_imports/importer_test.rb`
- Fixture: `test/fixtures/files/roster_valid.csv`
- Fixture: `test/fixtures/files/roster_duplicate_member_id.csv`
- Fixture: `test/fixtures/files/roster_missing_member_id.csv`

- [ ] **Step 1: Add CSV fixtures**

Create `test/fixtures/files/roster_valid.csv`:

```csv
"Member ID","Name","Post/Squadron Number","Type","Address","Undeliverable","Email","PhoneNumber","Branch","Conflict/War Era","Continuous Years","Paid Through Year","Member Status"
"000204540637","Alber, Vincent","American Legion WI Post 0165","PUFL renewal","2020 Shangrila Dr Apt 115
Clearwater, FL 33763-4270 ","","vincealber@example.com","(920)242-1400","USCG","VIETNAM","11","2027","Active"
"000205354762","Albright, Doug","American Legion WI Post 0165","1 Year Membership","703 22nd St
Two Rivers, WI 54241-3823 ","","","(920)794-7534","USMC","LEBANON_GRENADA","9","2026","Active"
```

Create `test/fixtures/files/roster_duplicate_member_id.csv`:

```csv
"Member ID","Name","Post/Squadron Number","Type","Address","Undeliverable","Email","PhoneNumber","Branch","Conflict/War Era","Continuous Years","Paid Through Year","Member Status"
"000204540637","Alber, Vincent","American Legion WI Post 0165","PUFL renewal","Address","","vincealber@example.com","(920)242-1400","USCG","VIETNAM","11","2027","Active"
"000204540637","Alber, Vince","American Legion WI Post 0165","PUFL renewal","Address","","vince2@example.com","(920)242-1400","USCG","VIETNAM","11","2027","Active"
```

Create `test/fixtures/files/roster_missing_member_id.csv`:

```csv
"Member ID","Name","Post/Squadron Number","Type","Address","Undeliverable","Email","PhoneNumber","Branch","Conflict/War Era","Continuous Years","Paid Through Year","Member Status"
"","Alber, Vincent","American Legion WI Post 0165","PUFL renewal","Address","","vincealber@example.com","(920)242-1400","USCG","VIETNAM","11","2027","Active"
```

- [ ] **Step 2: Write failing parser/importer tests**

Create `test/services/roster_imports/csv_parser_test.rb`:

```ruby
require "test_helper"

class RosterImports::CsvParserTest < ActiveSupport::TestCase
  test "parses valid national roster csv" do
    result = RosterImports::CsvParser.new(file_fixture("roster_valid.csv").read).parse

    assert result.valid?
    assert_equal 2, result.rows.size
    assert_equal "000204540637", result.rows.first.member_number
    assert_equal "vincealber@example.com", result.rows.first.email_address
    assert_equal false, result.rows.first.undeliverable
  end

  test "rejects duplicate member id within upload" do
    result = RosterImports::CsvParser.new(file_fixture("roster_duplicate_member_id.csv").read).parse

    assert_not result.valid?
    assert_includes result.errors.first, "Duplicate Member ID 000204540637"
  end

  test "rejects rows missing member id" do
    result = RosterImports::CsvParser.new(file_fixture("roster_missing_member_id.csv").read).parse

    assert_not result.valid?
    assert_includes result.errors.first, "Row 2 is missing Member ID"
  end
end
```

Create `test/services/roster_imports/importer_test.rb`:

```ruby
require "test_helper"

class RosterImports::ImporterTest < ActiveSupport::TestCase
  test "imports new people by member id" do
    result = RosterImports::Importer.new(
      csv_text: file_fixture("roster_valid.csv").read,
      filename: "roster_valid.csv"
    ).import

    assert result.success?
    assert_equal 2, result.created_count
    assert_equal "Alber", Person.find_by!(member_number: "000204540637").last_name
    assert_equal "vincealber@example.com", Person.find_by!(member_number: "000204540637").roster_email_address
    assert_equal 1, RosterImport.successful.count
  end

  test "reimport updates roster fields without changing user login email" do
    person = Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_email_address: "old@example.com")
    User.create!(person: person, email_address: "login@example.com", email_verified_at: Time.current)

    result = RosterImports::Importer.new(
      csv_text: file_fixture("roster_valid.csv").read,
      filename: "roster_valid.csv"
    ).import

    person.reload
    assert result.success?
    assert_equal 1, result.updated_count
    assert_equal "vincealber@example.com", person.roster_email_address
    assert_equal "login@example.com", person.user.email_address
  end

  test "invalid upload does not create people" do
    result = RosterImports::Importer.new(
      csv_text: file_fixture("roster_missing_member_id.csv").read,
      filename: "bad.csv"
    ).import

    assert_not result.success?
    assert_equal 0, Person.count
    assert_equal 1, RosterImport.where(status: "failed").count
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
bin/rails test test/services/roster_imports/csv_parser_test.rb test/services/roster_imports/importer_test.rb
```

Expected: failures for missing services.

- [ ] **Step 4: Implement parser**

Create `app/services/roster_imports/csv_parser.rb`:

```ruby
require "csv"
require "set"

module RosterImports
  class CsvParser
    REQUIRED_HEADERS = [
      "Member ID", "Name", "Post/Squadron Number", "Type", "Address", "Undeliverable",
      "Email", "PhoneNumber", "Branch", "Conflict/War Era", "Continuous Years",
      "Paid Through Year", "Member Status"
    ].freeze

    Row = Data.define(
      :member_number, :name, :post, :membership_type, :address, :undeliverable,
      :email_address, :phone_number, :branch, :war_era, :continuous_years,
      :paid_through_year, :member_status
    )

    Result = Data.define(:rows, :errors) do
      def valid? = errors.empty?
    end

    def initialize(csv_text)
      @csv_text = csv_text
    end

    def parse
      parsed = CSV.parse(@csv_text, headers: true)
      errors = header_errors(parsed.headers)
      rows = []
      seen_member_numbers = Set.new

      parsed.each.with_index(2) do |csv_row, line_number|
        member_number = csv_row["Member ID"].to_s.strip
        if member_number.blank?
          errors << "Row #{line_number} is missing Member ID"
          next
        end

        if seen_member_numbers.include?(member_number)
          errors << "Duplicate Member ID #{member_number} in uploaded roster"
          next
        end

        seen_member_numbers << member_number
        rows << build_row(csv_row, member_number)
      end

      Result.new(rows: errors.empty? ? rows : [], errors: errors)
    rescue CSV::MalformedCSVError => error
      Result.new(rows: [], errors: [ "Roster CSV could not be read: #{error.message}" ])
    end

    private

    def header_errors(headers)
      missing = REQUIRED_HEADERS - Array(headers)
      missing.map { |header| "Missing required column #{header}" }
    end

    def build_row(csv_row, member_number)
      Row.new(
        member_number: member_number,
        name: csv_row["Name"].to_s.strip,
        post: csv_row["Post/Squadron Number"].to_s.strip,
        membership_type: csv_row["Type"].to_s.strip,
        address: csv_row["Address"].to_s.strip,
        undeliverable: csv_row["Undeliverable"].to_s.strip.casecmp("Y").zero?,
        email_address: csv_row["Email"].to_s.strip.downcase.presence,
        phone_number: csv_row["PhoneNumber"].to_s.strip.presence,
        branch: csv_row["Branch"].to_s.strip.presence,
        war_era: csv_row["Conflict/War Era"].to_s.strip.presence,
        continuous_years: csv_row["Continuous Years"].to_s.strip.presence&.to_i,
        paid_through_year: csv_row["Paid Through Year"].to_s.strip.presence&.to_i,
        member_status: csv_row["Member Status"].to_s.strip.presence
      )
    end
  end
end
```

- [ ] **Step 5: Implement importer**

Create `app/services/roster_imports/importer.rb`:

```ruby
module RosterImports
  class Importer
    Result = Data.define(:success, :roster_import, :errors) do
      def success? = success
      def created_count = roster_import&.created_count || 0
      def updated_count = roster_import&.updated_count || 0
      def unchanged_count = roster_import&.unchanged_count || 0
      def problem_count = roster_import&.problem_count || errors.size
    end

    def initialize(csv_text:, filename:)
      @csv_text = csv_text
      @filename = filename.presence || "roster.csv"
    end

    def import
      parsed = CsvParser.new(@csv_text).parse
      return failed_import(parsed.errors) unless parsed.valid?

      now = Time.current
      created = 0
      updated = 0
      unchanged = 0

      roster_import = nil
      Person.transaction do
        parsed.rows.each do |row|
          person = Person.find_or_initialize_by(member_number: row.member_number)
          person.assign_attributes(attributes_for(row, now))
          assign_name(person, row.name) if person.new_record?

          if person.new_record?
            created += 1
          elsif person.changed?
            updated += 1
          else
            unchanged += 1
          end

          person.save!
        end

        roster_import = RosterImport.create!(
          uploaded_filename: @filename,
          status: "completed",
          created_count: created,
          updated_count: updated,
          unchanged_count: unchanged,
          problem_count: 0,
          summary: { created: created, updated: updated, unchanged: unchanged, problems: [] },
          imported_at: now
        )
      end

      Result.new(success: true, roster_import: roster_import, errors: [])
    rescue ActiveRecord::RecordInvalid => error
      failed_import([ error.message ])
    end

    private

    def failed_import(errors)
      roster_import = RosterImport.create!(
        uploaded_filename: @filename,
        status: "failed",
        problem_count: errors.size,
        summary: { problems: errors },
        imported_at: Time.current
      )
      Result.new(success: false, roster_import: roster_import, errors: errors)
    end

    def attributes_for(row, imported_at)
      {
        roster_name: row.name,
        roster_post: row.post,
        roster_membership_type: row.membership_type,
        roster_address: row.address,
        roster_undeliverable: row.undeliverable,
        roster_email_address: row.email_address,
        roster_phone_number: row.phone_number,
        roster_branch: row.branch,
        roster_war_era: row.war_era,
        roster_continuous_years: row.continuous_years,
        roster_paid_through_year: row.paid_through_year,
        roster_member_status: row.member_status,
        roster_imported_at: imported_at
      }
    end

    def assign_name(person, roster_name)
      last, first = roster_name.to_s.split(",", 2).map { |part| part.to_s.strip }
      person.first_name = first.presence || roster_name.presence || "Unknown"
      person.last_name = last.presence || "Member"
    end
  end
end
```

- [ ] **Step 6: Run focused tests**

Run:

```bash
bin/rails test test/services/roster_imports/csv_parser_test.rb test/services/roster_imports/importer_test.rb
```

Expected: tests pass.

- [ ] **Step 7: Commit**

```bash
git add app/services test/services test/fixtures/files
git commit -m "feat: import national roster csv"
```

---

### Task 3: Admin Authorization, Routes, and Shell

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Create: `app/controllers/admin/base_controller.rb`
- Create: `app/controllers/admin/dashboard_controller.rb`
- Modify: `config/routes.rb`
- Modify: `app/views/shared/_app_header.html.erb`
- Create: `app/views/admin/dashboard/show.html.erb`
- Test: `test/controllers/admin/dashboard_controller_test.rb`

- [ ] **Step 1: Write failing authorization tests**

Create `test/controllers/admin/dashboard_controller_test.rb`:

```ruby
require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(name: "Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  test "requires sign in" do
    get admin_root_path

    assert_redirected_to new_session_path
  end

  test "requires manage settings permission" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    sign_in_as(user)

    get admin_root_path

    assert_redirected_to root_path
    assert_equal "You do not have permission to open that page.", flash[:alert]
  end

  test "allows manage settings user" do
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)

    get admin_root_path

    assert_response :success
    assert_select "h1", "Administration"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bin/rails test test/controllers/admin/dashboard_controller_test.rb
```

Expected: route/controller missing failures.

- [ ] **Step 3: Implement authorization and admin shell**

Modify `app/controllers/application_controller.rb` by adding this public method before `private`:

```ruby
  def require_capability(capability)
    require_authentication
    return if performed?
    return if current_user&.can?(capability)

    redirect_to root_path, alert: "You do not have permission to open that page."
  end
```

Create `app/controllers/admin/base_controller.rb`:

```ruby
module Admin
  class BaseController < ApplicationController
    before_action :require_authentication
    before_action :require_admin_access

    private

    def require_admin_access
      require_capability("manage_settings")
    end
  end
end
```

Create `app/controllers/admin/dashboard_controller.rb`:

```ruby
module Admin
  class DashboardController < BaseController
    def show
      @latest_roster_import = RosterImport.latest_successful
      @roster_stale = RosterImport.roster_stale?
    end
  end
end
```

Modify `config/routes.rb` inside `Rails.application.routes.draw do`:

```ruby
  namespace :admin do
    root "dashboard#show"
  end
```

Modify `app/views/shared/_app_header.html.erb` to add an Admin link before Settings:

```erb
      <% if current_user.can?("manage_settings") %>
        <%= link_to "Admin", admin_root_path, class: "app-user-link" %>
      <% end %>
```

Create `app/views/admin/dashboard/show.html.erb`:

```erb
<div class="page-lead">
  <h1 class="page-title">Administration</h1>
  <p class="page-sub">Manage the roster import, accounts, permissions, and post roles.</p>
</div>

<section class="card stack">
  <h2>Roster</h2>
  <% if @latest_roster_import.present? %>
    <p>Latest successful roster import: <%= l @latest_roster_import.imported_at.to_date, format: :long %>.</p>
  <% else %>
    <p>No roster has been imported yet.</p>
  <% end %>
  <% if @roster_stale %>
    <p role="alert">The roster is more than 30 days old or has not been imported yet. Upload a current National roster export.</p>
  <% end %>
</section>
```

- [ ] **Step 4: Run focused test**

Run:

```bash
bin/rails test test/controllers/admin/dashboard_controller_test.rb
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/application_controller.rb app/controllers/admin config/routes.rb app/views/shared/_app_header.html.erb app/views/admin test/controllers/admin
git commit -m "feat: add admin authorization shell"
```

---

### Task 4: Roster Import Admin UI

**Files:**
- Create: `app/controllers/admin/roster_imports_controller.rb`
- Modify: `config/routes.rb`
- Modify: `app/views/admin/dashboard/show.html.erb`
- Create: `app/views/admin/roster_imports/new.html.erb`
- Create: `app/views/admin/roster_imports/show.html.erb`
- Test: `test/controllers/admin/roster_imports_controller_test.rb`

- [ ] **Step 1: Write failing controller tests**

Create `test/controllers/admin/roster_imports_controller_test.rb`:

```ruby
require "test_helper"

class Admin::RosterImportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(name: "Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)

    person = Person.create!(first_name: "Admin", last_name: "User")
    @user = User.create!(person: person, email_address: "admin@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: @user, capability: "manage_settings")
    sign_in_as(@user)
  end

  test "shows upload form" do
    get new_admin_roster_import_path

    assert_response :success
    assert_select "h1", "Upload National roster"
  end

  test "imports uploaded roster" do
    file = fixture_file_upload("roster_valid.csv", "text/csv")

    assert_difference -> { Person.count }, 2 do
      post admin_roster_imports_path, params: { roster_import: { file: file } }
    end

    assert_redirected_to admin_roster_import_path(RosterImport.last)
    assert_equal "Roster import completed.", flash[:notice]
  end

  test "shows failed import errors" do
    file = fixture_file_upload("roster_missing_member_id.csv", "text/csv")

    assert_no_difference -> { Person.count } do
      post admin_roster_imports_path, params: { roster_import: { file: file } }
    end

    assert_redirected_to admin_roster_import_path(RosterImport.last)
    assert_equal "Roster import could not be completed.", flash[:alert]
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bin/rails test test/controllers/admin/roster_imports_controller_test.rb
```

Expected: missing route/controller failures.

- [ ] **Step 3: Implement controller, routes, views**

Create `app/controllers/admin/roster_imports_controller.rb`:

```ruby
module Admin
  class RosterImportsController < BaseController
    def new
    end

    def create
      uploaded_file = params.dig(:roster_import, :file)
      if uploaded_file.blank?
        redirect_to new_admin_roster_import_path, alert: "Choose a roster CSV file to upload."
        return
      end

      result = RosterImports::Importer.new(
        csv_text: uploaded_file.read,
        filename: uploaded_file.original_filename
      ).import

      if result.success?
        redirect_to admin_roster_import_path(result.roster_import), notice: "Roster import completed."
      else
        redirect_to admin_roster_import_path(result.roster_import), alert: "Roster import could not be completed."
      end
    end

    def show
      @roster_import = RosterImport.find(params[:id])
    end
  end
end
```

Modify `config/routes.rb` admin namespace:

```ruby
  namespace :admin do
    root "dashboard#show"
    resources :roster_imports, only: %i[new create show]
  end
```

Create `app/views/admin/roster_imports/new.html.erb`:

```erb
<div class="page-lead">
  <h1 class="page-title">Upload National roster</h1>
  <p class="page-sub">Use the current CSV export from the National American Legion website.</p>
</div>

<%= form_with url: admin_roster_imports_path, scope: :roster_import, multipart: true, class: "card stack" do |form| %>
  <div>
    <%= form.label :file, "Roster CSV file" %>
    <%= form.file_field :file, accept: ".csv,text/csv", required: true %>
  </div>
  <%= form.submit "Import roster", class: "btn-primary" %>
<% end %>
```

Create `app/views/admin/roster_imports/show.html.erb`:

```erb
<div class="page-lead">
  <h1 class="page-title">Roster import result</h1>
  <p class="page-sub"><%= @roster_import.uploaded_filename %> imported <%= l @roster_import.imported_at, format: :long %>.</p>
</div>

<section class="card stack">
  <p>Status: <strong><%= @roster_import.status %></strong></p>
  <ul>
    <li>Created: <%= @roster_import.created_count %></li>
    <li>Updated: <%= @roster_import.updated_count %></li>
    <li>Unchanged: <%= @roster_import.unchanged_count %></li>
    <li>Problems: <%= @roster_import.problem_count %></li>
  </ul>
  <% Array(@roster_import.summary["problems"]).each do |problem| %>
    <p role="alert"><%= problem %></p>
  <% end %>
</section>
```

Add link in `app/views/admin/dashboard/show.html.erb` roster card:

```erb
  <%= link_to "Upload roster", new_admin_roster_import_path, class: "btn-primary" %>
```

- [ ] **Step 4: Run focused test**

Run:

```bash
bin/rails test test/controllers/admin/roster_imports_controller_test.rb
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/roster_imports_controller.rb app/views/admin/roster_imports app/views/admin/dashboard/show.html.erb config/routes.rb test/controllers/admin/roster_imports_controller_test.rb
git commit -m "feat: add roster import admin ui"
```

---

### Task 5: People List and Read-Only Roster Detail

**Files:**
- Create: `app/controllers/admin/people_controller.rb`
- Modify: `config/routes.rb`
- Create: `app/views/admin/people/index.html.erb`
- Create: `app/views/admin/people/show.html.erb`
- Test: `test/controllers/admin/people_controller_test.rb`

- [ ] **Step 1: Write failing controller tests**

Create `test/controllers/admin/people_controller_test.rb`:

```ruby
require "test_helper"

class Admin::PeopleControllerTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(name: "Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)

    admin_person = Person.create!(first_name: "Admin", last_name: "User")
    @admin = User.create!(person: admin_person, email_address: "admin@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: @admin, capability: "manage_settings")
    sign_in_as(@admin)

    @member = Person.create!(
      first_name: "Vincent", last_name: "Alber", member_number: "000204540637",
      roster_name: "Alber, Vincent", roster_email_address: "vincealber@example.com",
      roster_member_status: "Active", roster_paid_through_year: 2027,
      roster_branch: "USCG", roster_imported_at: Time.current
    )
  end

  test "lists imported members" do
    get admin_people_path

    assert_response :success
    assert_select "h1", "People"
    assert_select "td", "Alber, Vincent"
  end

  test "searches by name" do
    Person.create!(first_name: "Other", last_name: "Member", roster_name: "Member, Other", member_number: "999")

    get admin_people_path, params: { q: "Alber" }

    assert_response :success
    assert_includes response.body, "Alber, Vincent"
    assert_not_includes response.body, "Member, Other"
  end

  test "shows read only roster detail" do
    get admin_person_path(@member)

    assert_response :success
    assert_select "h1", "Alber, Vincent"
    assert_select "dt", "Member ID"
    assert_select "dd", "000204540637"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bin/rails test test/controllers/admin/people_controller_test.rb
```

Expected: missing route/controller failures.

- [ ] **Step 3: Implement people controller and views**

Create `app/controllers/admin/people_controller.rb`:

```ruby
module Admin
  class PeopleController < BaseController
    def index
      @people = Person.order(:last_name, :first_name)
      if params[:q].present?
        query = "%#{params[:q].strip}%"
        @people = @people.where("first_name ILIKE :query OR last_name ILIKE :query OR roster_name ILIKE :query OR member_number ILIKE :query", query: query)
      end
      @people = @people.limit(100)
      @latest_roster_import = RosterImport.latest_successful
      @roster_stale = RosterImport.roster_stale?
    end

    def show
      @person = Person.find(params[:id])
      @user = @person.user
      @position_assignment = PositionAssignment.new(starts_on: Date.current)
      @position_titles = PositionTitle.where(active: true).order(:display_order, :name)
    end
  end
end
```

Modify `config/routes.rb` admin namespace:

```ruby
    resources :people, only: %i[index show]
```

Create `app/views/admin/people/index.html.erb`:

```erb
<div class="page-lead">
  <h1 class="page-title">People</h1>
  <p class="page-sub">Roster-backed member records. Imported roster fields are read-only.</p>
</div>

<% if @roster_stale %>
  <p class="app-flash app-flash-alert" role="alert">The roster is more than 30 days old or has not been imported yet.</p>
<% end %>

<%= form_with url: admin_people_path, method: :get, class: "card" do |form| %>
  <%= form.label :q, "Search people" %>
  <%= form.search_field :q, value: params[:q], placeholder: "Name or member ID" %>
  <%= form.submit "Search", class: "btn-primary" %>
<% end %>

<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Member ID</th>
      <th>Status</th>
      <th>Paid through</th>
      <th>Login</th>
    </tr>
  </thead>
  <tbody>
    <% @people.each do |person| %>
      <tr>
        <td><%= link_to person.roster_display_name, admin_person_path(person) %></td>
        <td><%= person.member_number %></td>
        <td><%= person.roster_member_status %></td>
        <td><%= person.roster_paid_through_year %></td>
        <td><%= person.user ? "Enabled" : "No login" %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

Create `app/views/admin/people/show.html.erb`:

```erb
<div class="page-lead">
  <h1 class="page-title"><%= @person.roster_display_name %></h1>
  <p class="page-sub">Member details imported from the National roster.</p>
</div>

<section class="card stack">
  <h2>Roster data</h2>
  <dl>
    <dt>Member ID</dt><dd><%= @person.member_number %></dd>
    <dt>Name</dt><dd><%= @person.roster_name %></dd>
    <dt>Post/Squadron</dt><dd><%= @person.roster_post %></dd>
    <dt>Type</dt><dd><%= @person.roster_membership_type %></dd>
    <dt>Status</dt><dd><%= @person.roster_member_status %></dd>
    <dt>Paid through</dt><dd><%= @person.roster_paid_through_year %></dd>
    <dt>Email</dt><dd><%= @person.roster_email_address %></dd>
    <dt>Phone</dt><dd><%= @person.roster_phone_number %></dd>
    <dt>Branch</dt><dd><%= @person.roster_branch %></dd>
    <dt>Conflict/War Era</dt><dd><%= @person.roster_war_era %></dd>
    <dt>Continuous years</dt><dd><%= @person.roster_continuous_years %></dd>
    <dt>Undeliverable</dt><dd><%= @person.roster_undeliverable? ? "Yes" : "No" %></dd>
    <dt>Address</dt><dd><%= simple_format(@person.roster_address) %></dd>
    <dt>Imported</dt><dd><%= @person.roster_imported_at ? l(@person.roster_imported_at.to_date, format: :long) : "Not imported" %></dd>
  </dl>
</section>
```

- [ ] **Step 4: Run focused test**

Run:

```bash
bin/rails test test/controllers/admin/people_controller_test.rb
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/people_controller.rb app/views/admin/people config/routes.rb test/controllers/admin/people_controller_test.rb
git commit -m "feat: show roster-backed people admin"
```

---

### Task 6: User Account and Permission Management

**Files:**
- Create: `app/controllers/admin/user_accounts_controller.rb`
- Create: `app/controllers/admin/permission_grants_controller.rb`
- Modify: `config/routes.rb`
- Modify: `app/views/admin/people/show.html.erb`
- Test: `test/controllers/admin/user_accounts_controller_test.rb`
- Test: `test/controllers/admin/permission_grants_controller_test.rb`

- [ ] **Step 1: Write failing account tests**

Create `test/controllers/admin/user_accounts_controller_test.rb`:

```ruby
require "test_helper"

class Admin::UserAccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(name: "Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)

    admin_person = Person.create!(first_name: "Admin", last_name: "User")
    @admin = User.create!(person: admin_person, email_address: "admin@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: @admin, capability: "manage_settings")
    sign_in_as(@admin)

    @person = Person.create!(first_name: "Vincent", last_name: "Alber", roster_email_address: "vincealber@example.com")
  end

  test "creates user login for person using roster email by default" do
    assert_difference -> { User.count }, 1 do
      post admin_person_user_account_path(@person), params: { user: { email_address: "" } }
    end

    assert_redirected_to admin_person_path(@person)
    assert_equal "vincealber@example.com", @person.reload.user.email_address
  end

  test "disables user login" do
    user = User.create!(person: @person, email_address: "vincealber@example.com", email_verified_at: Time.current)

    delete admin_person_user_account_path(@person)

    assert_redirected_to admin_person_path(@person)
    assert user.reload.disabled_at.present?
  end
end
```

Create `test/controllers/admin/permission_grants_controller_test.rb`:

```ruby
require "test_helper"

class Admin::PermissionGrantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(name: "Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)

    admin_person = Person.create!(first_name: "Admin", last_name: "User")
    @admin = User.create!(person: admin_person, email_address: "admin@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: @admin, capability: "manage_settings")
    sign_in_as(@admin)

    person = Person.create!(first_name: "Vincent", last_name: "Alber")
    @user = User.create!(person: person, email_address: "vincealber@example.com", email_verified_at: Time.current)
  end

  test "replaces user permissions from checked capabilities" do
    patch admin_user_permission_grants_path(@user), params: { capabilities: [ "manage_people", "manage_agendas" ] }

    assert_redirected_to admin_person_path(@user.person)
    assert @user.can?("manage_people")
    assert @user.can?("manage_agendas")
    assert_not @user.can?("manage_minutes")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/admin/user_accounts_controller_test.rb test/controllers/admin/permission_grants_controller_test.rb
```

Expected: missing route/controller failures.

- [ ] **Step 3: Implement account and permission controllers**

Create `app/controllers/admin/user_accounts_controller.rb`:

```ruby
module Admin
  class UserAccountsController < BaseController
    def create
      person = Person.find(params[:person_id])
      email = params.dig(:user, :email_address).presence || person.roster_email_address
      if email.blank?
        redirect_to admin_person_path(person), alert: "Enter a login email address before creating the account."
        return
      end

      if person.user.present?
        person.user.update!(disabled_at: nil, email_address: email)
      else
        User.create!(person: person, email_address: email, email_verified_at: Time.current)
      end

      redirect_to admin_person_path(person), notice: "Login account is enabled."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to admin_person_path(person), alert: error.record.errors.full_messages.to_sentence
    end

    def destroy
      person = Person.find(params[:person_id])
      person.user&.update!(disabled_at: Time.current)

      redirect_to admin_person_path(person), notice: "Login account is disabled."
    end
  end
end
```

Create `app/controllers/admin/permission_grants_controller.rb`:

```ruby
module Admin
  class PermissionGrantsController < BaseController
    def update
      user = User.find(params[:user_id])
      capabilities = Array(params[:capabilities]) & PermissionGrant::CAPABILITIES

      PermissionGrant.transaction do
        user.permission_grants.where.not(capability: capabilities).destroy_all
        capabilities.each do |capability|
          user.permission_grants.find_or_create_by!(capability: capability)
        end
      end

      redirect_to admin_person_path(user.person), notice: "Permissions updated."
    end
  end
end
```

Modify `config/routes.rb` admin namespace:

```ruby
    resources :people, only: %i[index show] do
      resource :user_account, only: %i[create destroy]
    end
    resources :users, only: [] do
      resource :permission_grants, only: %i[update]
    end
```

Add account and permissions sections to `app/views/admin/people/show.html.erb`:

```erb
<section class="card stack">
  <h2>Login account</h2>
  <% if @user.present? %>
    <p>Login email: <%= @user.email_address %></p>
    <p>Status: <%= @user.disabled_at.present? ? "Disabled" : "Enabled" %></p>
    <% if @user.roster_email_mismatch? %>
      <p role="alert">Login email differs from roster email.</p>
    <% end %>
    <%= button_to "Disable login", admin_person_user_account_path(@person), method: :delete, class: "btn-secondary" %>

    <h3>Permissions</h3>
    <%= form_with url: admin_user_permission_grants_path(@user), method: :patch, class: "stack" do |form| %>
      <% PermissionGrant::CAPABILITIES.each do |capability| %>
        <label>
          <%= check_box_tag "capabilities[]", capability, @user.can?(capability) %>
          <%= capability.humanize %>
        </label>
      <% end %>
      <%= form.submit "Update permissions", class: "btn-primary" %>
    <% end %>
  <% else %>
    <%= form_with url: admin_person_user_account_path(@person), scope: :user, class: "stack" do |form| %>
      <%= form.label :email_address, "Login email" %>
      <%= form.email_field :email_address, value: @person.roster_email_address, placeholder: "member@example.com" %>
      <%= form.submit "Enable login", class: "btn-primary" %>
    <% end %>
  <% end %>
</section>
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
bin/rails test test/controllers/admin/user_accounts_controller_test.rb test/controllers/admin/permission_grants_controller_test.rb
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/user_accounts_controller.rb app/controllers/admin/permission_grants_controller.rb app/views/admin/people/show.html.erb config/routes.rb test/controllers/admin/user_accounts_controller_test.rb test/controllers/admin/permission_grants_controller_test.rb
git commit -m "feat: manage user accounts and permissions"
```

---

### Task 7: Post Position Assignments

**Files:**
- Create: `app/controllers/admin/position_assignments_controller.rb`
- Modify: `config/routes.rb`
- Modify: `app/views/admin/people/show.html.erb`
- Test: `test/controllers/admin/position_assignments_controller_test.rb`

- [ ] **Step 1: Write failing position assignment tests**

Create `test/controllers/admin/position_assignments_controller_test.rb`:

```ruby
require "test_helper"

class Admin::PositionAssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)

    admin_person = Person.create!(first_name: "Admin", last_name: "User")
    @admin = User.create!(person: admin_person, email_address: "admin@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: @admin, capability: "manage_settings")
    sign_in_as(@admin)

    @person = Person.create!(first_name: "Vincent", last_name: "Alber")
    @title = PositionTitle.create!(organization: @organization, name: "Adjutant", display_order: 2)
  end

  test "creates position assignment for person" do
    assert_difference -> { PositionAssignment.count }, 1 do
      post admin_person_position_assignments_path(@person), params: {
        position_assignment: { position_title_id: @title.id, starts_on: Date.current }
      }
    end

    assert_redirected_to admin_person_path(@person)
    assert_equal "Adjutant", @person.current_role_label
  end

  test "ends position assignment" do
    assignment = PositionAssignment.create!(person: @person, position_title: @title, starts_on: 1.year.ago)

    patch admin_person_position_assignment_path(@person, assignment), params: {
      position_assignment: { ends_on: Date.current }
    }

    assert_redirected_to admin_person_path(@person)
    assert_equal Date.current, assignment.reload.ends_on
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bin/rails test test/controllers/admin/position_assignments_controller_test.rb
```

Expected: missing route/controller failures.

- [ ] **Step 3: Implement controller, routes, and view section**

Create `app/controllers/admin/position_assignments_controller.rb`:

```ruby
module Admin
  class PositionAssignmentsController < BaseController
    def create
      person = Person.find(params[:person_id])
      assignment = person.position_assignments.new(position_assignment_params)

      if assignment.save
        redirect_to admin_person_path(person), notice: "Post role assigned."
      else
        redirect_to admin_person_path(person), alert: assignment.errors.full_messages.to_sentence
      end
    end

    def update
      person = Person.find(params[:person_id])
      assignment = person.position_assignments.find(params[:id])

      if assignment.update(position_assignment_params.slice(:ends_on))
        redirect_to admin_person_path(person), notice: "Post role updated."
      else
        redirect_to admin_person_path(person), alert: assignment.errors.full_messages.to_sentence
      end
    end

    private

    def position_assignment_params
      params.require(:position_assignment).permit(:position_title_id, :starts_on, :ends_on)
    end
  end
end
```

Modify `config/routes.rb` nested under admin people:

```ruby
      resources :position_assignments, only: %i[create update]
```

Add role section to `app/views/admin/people/show.html.erb`:

```erb
<section class="card stack">
  <h2>Post roles</h2>
  <% @person.position_assignments.includes(:position_title).order(starts_on: :desc).each do |assignment| %>
    <div>
      <p><strong><%= assignment.position_title.name %></strong> from <%= assignment.starts_on %> to <%= assignment.ends_on || "present" %></p>
      <% if assignment.ends_on.blank? %>
        <%= form_with url: admin_person_position_assignment_path(@person, assignment), method: :patch do |form| %>
          <%= form.fields_for :position_assignment do |fields| %>
            <%= fields.label :ends_on, "End date" %>
            <%= fields.date_field :ends_on, value: Date.current %>
          <% end %>
          <%= form.submit "End role", class: "btn-secondary" %>
        <% end %>
      <% end %>
    </div>
  <% end %>

  <h3>Assign role</h3>
  <%= form_with url: admin_person_position_assignments_path(@person), scope: :position_assignment, class: "stack" do |form| %>
    <%= form.label :position_title_id, "Role" %>
    <%= form.collection_select :position_title_id, @position_titles, :id, :name %>
    <%= form.label :starts_on, "Starts on" %>
    <%= form.date_field :starts_on, value: Date.current %>
    <%= form.submit "Assign role", class: "btn-primary" %>
  <% end %>
</section>
```

- [ ] **Step 4: Run focused test**

Run:

```bash
bin/rails test test/controllers/admin/position_assignments_controller_test.rb
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/position_assignments_controller.rb app/views/admin/people/show.html.erb config/routes.rb test/controllers/admin/position_assignments_controller_test.rb
git commit -m "feat: manage post role assignments"
```

---

### Task 8: Roster/Login Email Review Prompt

**Files:**
- Create: `app/controllers/roster_email_reviews_controller.rb`
- Modify: `app/controllers/dashboard_controller.rb`
- Modify: `config/routes.rb`
- Create: `app/views/dashboard/_roster_email_review.html.erb`
- Modify: `app/views/dashboard/show.html.erb`
- Test: `test/controllers/roster_email_reviews_controller_test.rb`
- Test: `test/controllers/dashboard_controller_test.rb`

- [ ] **Step 1: Write failing prompt tests**

Add to `test/controllers/dashboard_controller_test.rb`:

```ruby
test "shows roster email review prompt when needed" do
  Organization.create!(name: "Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
  Installation.singleton.update!(setup_completed_at: Time.current)

  person = Person.create!(first_name: "Jane", last_name: "Doe", roster_email_address: "roster@example.com")
  user = User.create!(person: person, email_address: "login@example.com", email_verified_at: Time.current)
  sign_in_as(user)

  get dashboard_path

  assert_response :success
  assert_select "h2", "Review your login email"
end
```

Create `test/controllers/roster_email_reviews_controller_test.rb`:

```ruby
require "test_helper"

class RosterEmailReviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(name: "Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)

    @person = Person.create!(first_name: "Jane", last_name: "Doe", roster_email_address: "roster@example.com")
    @user = User.create!(person: @person, email_address: "login@example.com", email_verified_at: Time.current)
    sign_in_as(@user)
  end

  test "updates login email to roster email" do
    patch roster_email_review_path, params: { decision: "update_login" }

    assert_redirected_to root_path
    assert_equal "roster@example.com", @user.reload.email_address
  end

  test "keeps current login email and stops prompting" do
    patch roster_email_review_path, params: { decision: "keep_current" }

    assert_redirected_to root_path
    assert_equal "login@example.com", @user.reload.email_address
    assert_not @user.needs_roster_email_review?
  end

  test "remind later keeps prompting" do
    patch roster_email_review_path, params: { decision: "remind_later" }

    assert_redirected_to root_path
    assert @user.reload.needs_roster_email_review?
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/dashboard_controller_test.rb test/controllers/roster_email_reviews_controller_test.rb
```

Expected: missing route/controller/prompt failures.

- [ ] **Step 3: Implement prompt controller and views**

Create `app/controllers/roster_email_reviews_controller.rb`:

```ruby
class RosterEmailReviewsController < ApplicationController
  before_action :require_authentication

  def update
    case params[:decision]
    when "update_login"
      current_user.update_login_email_to_roster_email!
      redirect_to root_path, notice: "Your login email now matches the roster email."
    when "keep_current"
      current_user.keep_current_login_email!
      redirect_to root_path, notice: "Your current login email will be kept."
    when "remind_later"
      current_user.remind_later_about_roster_email!
      redirect_to root_path, notice: "We will remind you next time you sign in."
    else
      redirect_to root_path, alert: "Choose how to handle the roster email difference."
    end
  rescue ActiveRecord::RecordInvalid => error
    redirect_to root_path, alert: error.record.errors.full_messages.to_sentence
  end
end
```

Modify `app/controllers/dashboard_controller.rb` to set prompt state:

```ruby
class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    @organization = Organization.first
    @show_passkey_invite = current_user.passkey_credentials.none?
    @show_roster_email_review = current_user.needs_roster_email_review?
  end
end
```

Modify `config/routes.rb`:

```ruby
  resource :roster_email_review, only: %i[update]
```

Create `app/views/dashboard/_roster_email_review.html.erb`:

```erb
<section class="card stack" role="region" aria-labelledby="roster-email-review-title">
  <h2 id="roster-email-review-title">Review your login email</h2>
  <p>The National roster lists <strong><%= current_user.person.roster_email_address %></strong>.</p>
  <p>Your login email is <strong><%= current_user.email_address %></strong>.</p>
  <p>Choose whether your login email should match the roster email.</p>

  <div class="stack">
    <%= button_to "Update login email to roster email", roster_email_review_path, method: :patch, params: { decision: "update_login" }, class: "btn-primary" %>
    <%= button_to "Keep my current login email", roster_email_review_path, method: :patch, params: { decision: "keep_current" }, class: "btn-secondary" %>
    <%= button_to "Remind me later", roster_email_review_path, method: :patch, params: { decision: "remind_later" }, class: "btn-secondary" %>
  </div>
</section>
```

Modify `app/views/dashboard/show.html.erb` after passkey invite block:

```erb
<% if @show_roster_email_review %>
  <%= render "roster_email_review" %>
<% end %>
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
bin/rails test test/controllers/dashboard_controller_test.rb test/controllers/roster_email_reviews_controller_test.rb
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/roster_email_reviews_controller.rb app/controllers/dashboard_controller.rb app/views/dashboard config/routes.rb test/controllers/dashboard_controller_test.rb test/controllers/roster_email_reviews_controller_test.rb
git commit -m "feat: prompt for roster login email mismatch"
```

---

### Task 9: Final Integration, Documentation, and Verification

**Files:**
- Modify: `docs/ROADMAP.md` if implementation status changes.
- Modify: `docs/ARCHITECTURE.md` to record roster import/user-account boundary.
- Review: all files touched by Tasks 1–8.

- [ ] **Step 1: Add architecture note**

Add a short section to `docs/ARCHITECTURE.md`:

```markdown
## Roster-backed administration

National American Legion roster CSV imports populate read-only roster fields on people, keyed by Member ID. Roster data is dated and refreshed by later imports rather than edited locally. Login accounts remain separate: a person may or may not have a user, roster email remains separate from login email, and app permissions are granted to users rather than imported roster rows. Post positions and committee-lead-style roles are assigned to people with effective dates so officer history is preserved.
```

- [ ] **Step 2: Run all focused tests**

Run:

```bash
bin/rails test test/models/roster_import_test.rb test/models/person_test.rb test/models/user_test.rb test/services/roster_imports/csv_parser_test.rb test/services/roster_imports/importer_test.rb test/controllers/admin/dashboard_controller_test.rb test/controllers/admin/roster_imports_controller_test.rb test/controllers/admin/people_controller_test.rb test/controllers/admin/user_accounts_controller_test.rb test/controllers/admin/permission_grants_controller_test.rb test/controllers/admin/position_assignments_controller_test.rb test/controllers/dashboard_controller_test.rb test/controllers/roster_email_reviews_controller_test.rb
```

Expected: all listed tests pass.

- [ ] **Step 3: Run full Rails test suite**

Run:

```bash
bin/rails test
```

Expected: full suite passes.

- [ ] **Step 4: Run static/security checks if time allows**

Run:

```bash
bin/rubocop
bin/brakeman
bin/bundler-audit
```

Expected: no new offenses or security findings from this work. If existing findings appear, document them separately and do not hide them.

- [ ] **Step 5: Manual smoke test**

Run the server bound off-box:

```bash
bin/rails server -b 0.0.0.0
```

In a browser, verify:

1. Admin link appears for a user with `manage_settings`.
2. Admin link does not appear for a normal signed-in user.
3. Roster upload accepts `docs/reference/RosterData.csv`.
4. People list shows imported members.
5. A person detail page shows roster fields as text, not editable form fields.
6. A user account can be enabled for a person.
7. App permissions can be granted and removed.
8. A post role can be assigned and ended.
9. Changing roster email by re-import triggers the dashboard review prompt without changing login email automatically.

- [ ] **Step 6: Final commit**

```bash
git add docs/ARCHITECTURE.md docs/ROADMAP.md docs/superpowers/specs/2026-07-11-admin-and-roster-import-design.md
git commit -m "docs: record roster administration architecture"
```

---

## Self-Review Notes

- Spec coverage: roster import, Member ID matching, read-only imported fields, 30-day freshness warning, user linking, permission assignment, role assignment, and email mismatch prompt are covered by Tasks 1–8.
- Intentional scope exclusions: no public directory, no local roster editing, no automatic accounts for all members, no AI merge/split handling, and no blocking of meeting work for stale data.
- Type consistency: the plan consistently uses `RosterImport`, `RosterImports::CsvParser`, `RosterImports::Importer`, `roster_email_address`, `member_number`, and `roster_email_review_*` user columns.
- Risk to watch during implementation: the sample views use existing CSS classes where possible, but some generic elements may need light styling to satisfy the readability rule and visual system.
