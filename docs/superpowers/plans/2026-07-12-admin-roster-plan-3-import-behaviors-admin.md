# Admin & Roster Redesign — Plan 3: Import Behaviors + Screens + Admin Landing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax. **Depends on Plan 1** (components/helpers) and reuses Plan 2's `person_path`. Can be built in parallel with Plan 2 except the result page links to `person_path` (Plan 2 Task 3).

**Goal:** Turn the roster importer from all-or-nothing into partial import with per-row problems; detect members dropped from the National roster and auto-disable their sign-in; add an import history/log; and redesign the upload, result, and Admin-landing screens onto the design system.

**Architecture:** Rework `RosterImports::CsvParser` to separate fatal structural errors from per-row problems, and `RosterImports::Importer` to import valid rows, detect removals, auto-disable removed members' logins (respecting the last-admin guard), and write a structured summary plus a `removed_count`. Add `roster_removed_at` to `people` and `removed_count` to `roster_imports`. Redesign the roster screens and Admin landing using Plan 1 components.

**Tech Stack:** Rails (Minitest, ActiveRecord, ERB), Plan 1 component vocabulary.

## Global Constraints

(Inherits all Global Constraints from Plan 1 — readability floors, no full-width, `DD MMM YYYY`/`HH:MM`, red discipline, palette tokens, no new deps, `bin/rails test` / `bin/rubocop` / `bin/brakeman` clean.)

- **Partial import:** structural failures (missing required headers, malformed CSV, bad encoding) still fail the whole import (nothing persisted). Per-row issues (missing Member ID, duplicate Member ID) **skip that row and become problems**; valid rows still import; the import status is `completed`.
- **Removal + auto-disable:** a person previously roster-backed (`roster_imported_at` present) and **absent from the new file** is marked removed (`roster_removed_at` set; roster data retained) and their login is disabled in the same transaction — **unless** they are the last enabled `manage_settings` administrator, in which case sign-in is kept and a problem is recorded. Re-appearing on a later import clears `roster_removed_at` but does **not** re-enable sign-in. Removal detection is **skipped entirely** if the file yielded zero valid rows (never mass-remove on an empty/all-problem file).
- **Visual source of truth (mockups):** `roster-import-upload.html`, `roster-import-result-v2.html`, `admin-landing.html`.
- **View-porting convention:** as Plan 2 — port the mockup markup, substitute Plan 1 partials (`shared/section_panel`, `shared/section_header`, `shared/stat_tile`, `legion_date`, `legion_datetime`), and pin behavior/copy with a controller test.

---

### Task 1: Migration — `roster_removed_at` on people, `removed_count` on roster_imports

**Files:**
- Create: `db/migrate/<timestamp>_add_roster_removal_tracking.rb` (via generator)
- Modify: `db/schema.rb` (by running the migration)

**Interfaces:**
- Produces: `people.roster_removed_at` (datetime, nullable, indexed); `roster_imports.removed_count` (integer, not null, default 0).

- [ ] **Step 1: Generate the migration**

Run: `bin/rails g migration AddRosterRemovalTracking`
Then replace the generated file body with:

```ruby
class AddRosterRemovalTracking < ActiveRecord::Migration[8.0]
  def change
    add_column :people, :roster_removed_at, :datetime
    add_index :people, :roster_removed_at
    add_column :roster_imports, :removed_count, :integer, null: false, default: 0
  end
end
```

(Match the `ActiveRecord::Migration[X.Y]` version to the other files in `db/migrate/`.)

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `schema.rb` now shows `roster_removed_at` on `people` (with an index) and `removed_count` on `roster_imports`.

- [ ] **Step 3: Run the suite to confirm nothing broke**

Run: `bin/rails test`
Expected: PASS (existing tests still green; new columns are additive).

- [ ] **Step 4: Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "feat: add roster removal tracking columns"
```

---

### Task 2: CsvParser — separate fatal errors from per-row problems

**Files:**
- Modify: `app/services/roster_imports/csv_parser.rb`
- Test: `test/services/roster_imports/csv_parser_test.rb`

**Interfaces:**
- Produces: `CsvParser#parse -> Result` where `Result` has `rows`, `problems` (Array of `Problem` structs), `fatal_errors` (Array of String), and `valid?` (= `fatal_errors.empty?`). `Problem = Struct.new(:row, :kind, :member_number, :message, keyword_init: true)`. Missing/duplicate Member ID rows are excluded from `rows` and recorded in `problems`; header/parse/encoding failures populate `fatal_errors` with empty `rows`.

- [ ] **Step 1: Write the failing test** (rewrite `test/services/roster_imports/csv_parser_test.rb` expectations for the new shape; keep any header/malformed cases as fatal)

```ruby
require "test_helper"

class RosterImports::CsvParserTest < ActiveSupport::TestCase
  HEADERS = "Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status"

  test "missing member id becomes a problem, not fatal; other rows still parse" do
    csv = "#{HEADERS}\n,\"No, Id\",165,Member,1 A St,,a@x.com,555,Army,Vietnam,5,2026,Active\n000204540637,\"Ok, Person\",165,Member,2 B St,,b@x.com,555,Navy,Korea,6,2026,Active\n"
    result = RosterImports::CsvParser.new(csv).parse
    assert result.valid?
    assert_equal 1, result.rows.size
    assert_equal "000204540637", result.rows.first.member_number
    assert_equal 1, result.problems.size
    assert_equal "missing_member_id", result.problems.first.kind
    assert_equal 2, result.problems.first.row
  end

  test "duplicate member id keeps the first row and problems the rest" do
    csv = "#{HEADERS}\n000204540637,\"A, One\",165,Member,1 A St,,a@x.com,555,Army,Vietnam,5,2026,Active\n000204540637,\"A, Dup\",165,Member,2 B St,,b@x.com,555,Navy,Korea,6,2026,Active\n"
    result = RosterImports::CsvParser.new(csv).parse
    assert result.valid?
    assert_equal 1, result.rows.size
    assert_equal 1, result.problems.size
    assert_equal "duplicate_member_id", result.problems.first.kind
  end

  test "missing required headers is fatal" do
    csv = "Member ID,Name\n000204540637,\"A, One\"\n"
    result = RosterImports::CsvParser.new(csv).parse
    assert_not result.valid?
    assert_equal [], result.rows
    assert_match(/Missing required columns/, result.fatal_errors.first)
  end

  test "malformed csv is fatal" do
    csv = "#{HEADERS}\n000204540637,\"Smith, John,165,Member\n"
    result = RosterImports::CsvParser.new(csv).parse
    assert_not result.valid?
    assert_not_empty result.fatal_errors
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/roster_imports/csv_parser_test.rb`
Expected: FAIL (`Result` has no `problems`/`fatal_errors`).

- [ ] **Step 3: Rewrite the parser Result + row handling**

Replace the `Row`/`Result` structs and the `parse` method's collection/return in `app/services/roster_imports/csv_parser.rb`:

```ruby
    Problem = Struct.new(:row, :kind, :member_number, :message, keyword_init: true)

    Result = Struct.new(:rows, :problems, :fatal_errors, keyword_init: true) do
      def valid?
        fatal_errors.empty?
      end
    end
```

In `parse`, replace the `errors = []` accumulation and the two `errors << …; next` branches, and the return values:

```ruby
      rows = []
      problems = []
      seen_member_numbers = {}

      csv.each_with_index do |row, index|
        row_number = index + 2
        member_number = row["Member ID"]&.strip

        if member_number.blank?
          problems << Problem.new(row: row_number, kind: "missing_member_id", member_number: nil,
            message: "No Member ID in the row — skipped. A member can't be matched without a Member ID.")
          next
        end

        if seen_member_numbers[member_number]
          problems << Problem.new(row: row_number, kind: "duplicate_member_id", member_number: member_number,
            message: "Member ID #{member_number} appears more than once in the file — kept the first, skipped this one.")
          next
        end

        seen_member_numbers[member_number] = true
        rows << Row.new(...) # unchanged Row.new(...) block
      end

      Result.new(rows: rows, problems: problems, fatal_errors: [])
    rescue ArgumentError => e
      Result.new(rows: [], problems: [], fatal_errors: [ e.message ])
    rescue CSV::MalformedCSVError => e
      Result.new(rows: [], problems: [], fatal_errors: [ e.message ])
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
      Result.new(rows: [], problems: [], fatal_errors: [ e.message ])
    end
```

(Leave the `Row.new(...)` keyword block exactly as it is today.)

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/roster_imports/csv_parser_test.rb`
Expected: PASS (4 runs, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add app/services/roster_imports/csv_parser.rb test/services/roster_imports/csv_parser_test.rb
git commit -m "feat: parser records per-row problems instead of failing wholesale"
```

---

### Task 3: User — reusable last-admin guard

**Files:**
- Modify: `app/models/user.rb`
- Test: `test/models/user_test.rb` (create if absent)

**Interfaces:**
- Produces: `User.another_enabled_manage_settings_user_exists?(user) -> Boolean` — true if some *other* enabled user holds `manage_settings`. `User#only_enabled_administrator? -> Boolean` — true if this user is enabled, holds `manage_settings`, and no other enabled admin exists.

- [ ] **Step 1: Write the failing test**

```ruby
# test/models/user_test.rb
require "test_helper"

class UserTest < ActiveSupport::TestCase
  def admin(email)
    u = User.create!(person: Person.create!(first_name: email, last_name: "X"), email_address: "#{email}@x.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: u, capability: "manage_settings")
    u
  end

  test "only_enabled_administrator? is true when this is the sole enabled admin" do
    a = admin("a")
    assert a.only_enabled_administrator?
  end

  test "only_enabled_administrator? is false when another enabled admin exists" do
    a = admin("a")
    admin("b")
    assert_not a.only_enabled_administrator?
  end

  test "another_enabled_manage_settings_user_exists? ignores the given user and disabled users" do
    a = admin("a")
    b = admin("b")
    assert User.another_enabled_manage_settings_user_exists?(a)
    b.update!(disabled_at: Time.current)
    assert_not User.another_enabled_manage_settings_user_exists?(a)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/user_test.rb`
Expected: FAIL (`undefined method 'only_enabled_administrator?'`).

- [ ] **Step 3: Implement** (add to `app/models/user.rb`)

```ruby
  def self.another_enabled_manage_settings_user_exists?(user)
    where(disabled_at: nil)
      .where.not(id: user.id)
      .joins(:permission_grants)
      .where(permission_grants: { capability: "manage_settings" })
      .exists?
  end

  def only_enabled_administrator?
    disabled_at.blank? && can?("manage_settings") && !self.class.another_enabled_manage_settings_user_exists?(self)
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/user_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/models/user.rb test/models/user_test.rb
git commit -m "feat: add reusable last-administrator guard to User"
```

---

### Task 4: Importer — partial import, removal detection, auto-disable, structured summary

**Files:**
- Modify: `app/services/roster_imports/importer.rb`
- Modify: `app/models/roster_import.rb` (validate `removed_count`)
- Test: rewrite affected cases in `test/services/roster_imports/importer_test.rb`; add removal cases

**Interfaces:**
- Consumes: `CsvParser::Result` (Task 2), `User.another_enabled_manage_settings_user_exists?` (Task 3), `roster_removed_at`/`removed_count` (Task 1).
- Produces: `Importer#import -> Result` with `removed_count` added; imports valid rows, records problems, detects/marks removals, auto-disables removed logins (guarded), writes structured `summary` (`rows, created, updated, unchanged, removed, problems: [{row, kind, message}], removed_members: [{name, member_number, user_disabled}]`).

- [ ] **Step 1: Write the failing tests** (rewrite the two cases that assumed wholesale failure, and add removal cases)

Replace the `"invalid upload does not create people…"` test and add these; keep the header/malformed/rollback tests as-is (they remain fatal):

```ruby
  test "row with missing member id is a problem but valid rows still import" do
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      ,"No, Id",165,Member,1 A St,,a@x.com,555,Army,Vietnam,5,2026,Active
      000204540637,"Ok, Person",165,Member,2 B St,,b@x.com,555,Navy,Korea,6,2026,Active
    CSV
    result = RosterImports::Importer.new(csv_text: csv, filename: "partial.csv").import
    assert result.success?
    assert_equal "completed", result.roster_import.status
    assert_equal 1, result.created_count
    assert_equal 1, result.problem_count
    assert_equal 1, Person.where(member_number: "000204540637").count
    assert_equal 1, result.roster_import.summary["problems"].size
  end

  test "member absent from a new import is marked removed and their sign-in disabled" do
    gone = Person.create!(first_name: "Gone", last_name: "Member", member_number: "000000000001", roster_imported_at: 10.days.ago)
    gone_user = User.create!(person: gone, email_address: "gone@x.com", email_verified_at: Time.current)
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Ok, Person",165,Member,2 B St,,b@x.com,555,Navy,Korea,6,2026,Active
    CSV
    result = RosterImports::Importer.new(csv_text: csv, filename: "removal.csv").import
    assert result.success?
    assert_equal 1, result.removed_count
    gone.reload; gone_user.reload
    assert gone.roster_removed_at.present?
    assert gone_user.disabled_at.present?
    assert_equal "000000000001", result.roster_import.summary["removed_members"].first["member_number"]
  end

  test "the last enabled administrator is not disabled on removal; a problem is recorded" do
    admin_person = Person.create!(first_name: "Sole", last_name: "Admin", member_number: "000000000009", roster_imported_at: 10.days.ago)
    admin_user = User.create!(person: admin_person, email_address: "admin@x.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: admin_user, capability: "manage_settings")
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Ok, Person",165,Member,2 B St,,b@x.com,555,Navy,Korea,6,2026,Active
    CSV
    result = RosterImports::Importer.new(csv_text: csv, filename: "last-admin.csv").import
    admin_user.reload
    assert_nil admin_user.disabled_at
    assert(result.roster_import.summary["problems"].any? { |p| p["kind"] == "last_admin" })
  end

  test "returning member clears roster_removed_at but does not re-enable sign-in" do
    back = Person.create!(first_name: "Back", last_name: "Again", member_number: "000204540637",
      roster_imported_at: 20.days.ago, roster_removed_at: 5.days.ago)
    back_user = User.create!(person: back, email_address: "back@x.com", email_verified_at: Time.current, disabled_at: 5.days.ago)
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      000204540637,"Back, Again",165,Member,2 B St,,b@x.com,555,Navy,Korea,6,2026,Active
    CSV
    RosterImports::Importer.new(csv_text: csv, filename: "return.csv").import
    back.reload; back_user.reload
    assert_nil back.roster_removed_at
    assert back_user.disabled_at.present?, "sign-in stays off until an officer re-enables it"
  end

  test "a file with zero valid rows never mass-removes" do
    keep = Person.create!(first_name: "Keep", last_name: "Me", member_number: "000000000002", roster_imported_at: 10.days.ago)
    csv = <<~CSV
      Member ID,Name,Post/Squadron Number,Type,Address,Undeliverable,Email,PhoneNumber,Branch,Conflict/War Era,Continuous Years,Paid Through Year,Member Status
      ,"No, Id",165,Member,1 A St,,a@x.com,555,Army,Vietnam,5,2026,Active
    CSV
    result = RosterImports::Importer.new(csv_text: csv, filename: "all-problems.csv").import
    assert_equal 0, result.removed_count
    keep.reload
    assert_nil keep.roster_removed_at
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/roster_imports/importer_test.rb`
Expected: FAIL (no `removed_count`; missing-id row currently fails the import).

- [ ] **Step 3: Rewrite the importer**

Update the `Result` struct to add `removed_count`, and replace `import`, `import_rows`, and `failed_import`:

```ruby
    Result = Struct.new(
      :roster_import, :errors, :created_count, :updated_count, :unchanged_count, :removed_count, :problem_count,
      keyword_init: true
    ) do
      def success?
        errors.empty? && roster_import&.status == "completed"
      end
    end
```

```ruby
    def import
      parsed = CsvParser.new(@csv_text).parse
      if parsed.valid?
        import_rows(parsed.rows, parsed.problems)
      else
        failed_import(parsed.fatal_errors)
      end
    end

    private

    def import_rows(rows, row_problems)
      created = updated = unchanged = removed = 0
      imported_member_numbers = []
      problems = row_problems.map { |p| { row: p.row, kind: p.kind, message: p.message } }
      removed_members = []
      roster_import = nil

      ActiveRecord::Base.transaction do
        rows.each do |row|
          person = Person.find_or_initialize_by(member_number: row.member_number)
          was_new = person.new_record?
          assign_roster_fields(person, row)
          split_name(person, row.name) if was_new
          person.roster_removed_at = nil if person.roster_removed_at.present?

          if person.changed?
            person.roster_imported_at = Time.current
            person.save!
            was_new ? created += 1 : updated += 1
          else
            person.update_column(:roster_imported_at, Time.current) if person.persisted?
            unchanged += 1
          end
          imported_member_numbers << row.member_number
        end

        if imported_member_numbers.any?
          Person.where(roster_removed_at: nil)
                .where.not(roster_imported_at: nil)
                .where.not(member_number: imported_member_numbers)
                .includes(:user).find_each do |person|
            person.update_column(:roster_removed_at, Time.current)
            removed += 1
            user = person.user
            disabled = false
            if user && user.disabled_at.blank?
              if user.only_enabled_administrator?
                problems << { row: nil, kind: "last_admin",
                  message: "#{person.roster_display_name} left the roster but is the last administrator — sign-in kept on; review manually." }
              else
                user.update_column(:disabled_at, Time.current)
                disabled = true
              end
            end
            removed_members << { name: person.roster_display_name, member_number: person.member_number, user_disabled: disabled }
          end
        end

        roster_import = RosterImport.create!(
          status: "completed", imported_at: Time.current, uploaded_filename: @filename,
          created_count: created, updated_count: updated, unchanged_count: unchanged,
          removed_count: removed, problem_count: problems.size,
          summary: { rows: rows.size, created: created, updated: updated, unchanged: unchanged,
                     removed: removed, problems: problems, removed_members: removed_members }
        )
      end

      Result.new(roster_import: roster_import, errors: [], created_count: created, updated_count: updated,
                 unchanged_count: unchanged, removed_count: removed, problem_count: problems.size)
    rescue ActiveRecord::RecordInvalid => e
      failed_import([ e.message ])
    end

    def failed_import(errors)
      roster_import = RosterImport.create!(
        status: "failed", imported_at: Time.current, uploaded_filename: @filename,
        created_count: 0, updated_count: 0, unchanged_count: 0, removed_count: 0, problem_count: errors.size,
        summary: { problems: errors.map { |message| { row: nil, kind: "fatal", message: message } } }
      )
      Result.new(roster_import: roster_import, errors: errors, created_count: 0, updated_count: 0,
                 unchanged_count: 0, removed_count: 0, problem_count: errors.size)
    end
```

(Keep `assign_roster_fields` and `split_name` unchanged.) Add `removed_count` to the numericality validation in `app/models/roster_import.rb`:

```ruby
  validates :created_count, :updated_count, :unchanged_count, :removed_count, :problem_count,
    numericality: { greater_than_or_equal_to: 0 }
```

- [ ] **Step 4: Reconcile the remaining importer tests**

The old `"invalid upload does not create people and creates failed roster import"` test (using `roster_missing_member_id.csv`) asserted wholesale failure. With partial import that fixture now yields a completed import with a problem. Update that test to assert `result.success?`, `status == "completed"`, and `result.problem_count >= 1`, and that valid rows (if any in the fixture) imported. Run the fixture through and assert accordingly. Keep the missing-headers, malformed, shared-emails, and rollback tests unchanged.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/services/roster_imports/importer_test.rb test/models/roster_import_test.rb`
Expected: PASS (all importer + model tests green).

- [ ] **Step 6: Commit**

```bash
git add app/services/roster_imports/importer.rb app/models/roster_import.rb test/services/roster_imports/importer_test.rb test/models/roster_import_test.rb
git commit -m "feat: partial import with problems, removal detection, and auto-disable on removal"
```

---

### Task 5: RosterImport — summary accessors + history scope

**Files:**
- Modify: `app/models/roster_import.rb`
- Test: `test/models/roster_import_test.rb`

**Interfaces:**
- Produces: `RosterImport#problems -> Array<Hash>`, `#removed_members -> Array<Hash>` (safe readers over `summary`); `RosterImport.history -> ActiveRecord::Relation` ordered newest-first.

- [ ] **Step 1: Write the failing test** (append)

```ruby
  test "problems and removed_members read from summary safely" do
    ri = RosterImport.create!(status: "completed", imported_at: Time.current, uploaded_filename: "x.csv",
      summary: { "problems" => [ { "row" => 4, "message" => "m" } ], "removed_members" => [ { "name" => "N" } ] })
    assert_equal 1, ri.problems.size
    assert_equal "N", ri.removed_members.first["name"]
    blank = RosterImport.create!(status: "completed", imported_at: Time.current, uploaded_filename: "y.csv")
    assert_equal [], blank.problems
    assert_equal [], blank.removed_members
  end

  test "history orders newest first" do
    older = RosterImport.create!(status: "completed", imported_at: 2.days.ago, uploaded_filename: "old.csv")
    newer = RosterImport.create!(status: "completed", imported_at: 1.hour.ago, uploaded_filename: "new.csv")
    assert_equal [ newer, older ], RosterImport.history.to_a.first(2)
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/roster_import_test.rb`
Expected: FAIL (`undefined method 'problems'`).

- [ ] **Step 3: Implement** (add to `app/models/roster_import.rb`)

```ruby
  scope :history, -> { order(imported_at: :desc, id: :desc) }

  def problems
    Array(summary&.fetch("problems", nil))
  end

  def removed_members
    Array(summary&.fetch("removed_members", nil))
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/roster_import_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/models/roster_import.rb test/models/roster_import_test.rb
git commit -m "feat: RosterImport summary accessors and history scope"
```

---

### Task 6: Roster imports controller — history index + redesigned result

**Files:**
- Modify: `config/routes.rb` (add `index` to admin roster_imports)
- Modify: `app/controllers/admin/roster_imports_controller.rb`
- Test: `test/controllers/admin/roster_imports_controller_test.rb`

**Interfaces:**
- Consumes: `RosterImport.history` (Task 5).
- Produces: `GET admin_roster_imports_path` (history), and `show` exposing `@roster_import` with `problems`/`removed_members`.

- [ ] **Step 1: Add the route**

In `config/routes.rb`, change the admin roster_imports line to:

```ruby
    resources :roster_imports, only: %i[index new create show]
```

- [ ] **Step 2: Write the failing test** (append)

```ruby
  test "index lists past imports newest first" do
    prepare_setup_complete_state
    sign_in_admin
    RosterImport.create!(status: "completed", imported_at: 2.days.ago, uploaded_filename: "old.csv")
    RosterImport.create!(status: "completed", imported_at: 1.hour.ago, uploaded_filename: "new.csv")
    get admin_roster_imports_path
    assert_response :success
    assert_select ".imp", minimum: 2
  end
```

(Use the `sign_in_admin`/`prepare_setup_complete_state` helpers already in this test file.)

- [ ] **Step 3: Implement the controller**

```ruby
    def index
      @roster_imports = RosterImport.history
    end
```

Change `show` to read the structured summary:

```ruby
    def show
      @roster_import = RosterImport.find(params[:id])
      @problems = @roster_import.problems
      @removed_members = @roster_import.removed_members
    end
```

- [ ] **Step 4: Redesign the result view**

Port `app/views/admin/roster_imports/show.html.erb` to `roster-import-result-v2.html`: the green confirmation (`legion_datetime(@roster_import.imported_at)`), a `.tiles` row of four `shared/stat_tile` (`created`, `updated`, `removed`, `problems` variants using the summary counts), a `shared/section_panel` "Removed from the roster" listing `@removed_members` (name, member_number, "sign-in turned off" when `user_disabled`, link to `person_path`), a `shared/section_panel` "N rows need attention" listing `@problems` (message text), and the action links (View People → `people_path`, Import another → `new_admin_roster_import_path`, View import history → `admin_roster_imports_path`). Add the `.tiles`/`.done`/`.item` CSS from the mockup.

- [ ] **Step 5: Create the history view**

`app/views/admin/roster_imports/index.html.erb` — port the "Recent imports" list from `admin-landing.html`: each `RosterImport` as an `.imp` row (link to `admin_roster_import_path`) showing `legion_datetime(imported_at)`, status word (Complete/Failed), filename, and the `+created / updated / removed / problems` summary. Add `.imp` CSS from the mockup.

- [ ] **Step 6: Run tests**

Run: `bin/rails test test/controllers/admin/roster_imports_controller_test.rb`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/admin/roster_imports_controller.rb app/views/admin/roster_imports/ app/assets/tailwind/application.css test/controllers/admin/roster_imports_controller_test.rb
git commit -m "feat: roster import history + redesigned result summary"
```

---

### Task 7: Roster upload screen redesign

**Files:**
- Modify: `app/views/admin/roster_imports/new.html.erb`
- Test: `test/controllers/admin/roster_imports_controller_test.rb` (append a copy assertion)

**Interfaces:**
- Consumes: existing `create` contract (multipart `roster_import[file]`).

- [ ] **Step 1: Write the failing test** (append)

```ruby
  test "new upload page states the removal consequence" do
    prepare_setup_complete_state
    sign_in_admin
    get new_admin_roster_import_path
    assert_response :success
    assert_select "h1", text: /Import roster/
    assert_select "body", text: /sign-in is turned off/
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/admin/roster_imports_controller_test.rb -n /new upload page/`
Expected: FAIL (copy not present).

- [ ] **Step 3: Port the view**

Port `app/views/admin/roster_imports/new.html.erb` to `roster-import-upload.html`: three step cards, the file-choose area (`form_with url: admin_roster_imports_path, multipart: true`, `file_field_tag "roster_import[file]", accept: ".csv,text/csv"`), and the "what happens" note including the line "Anyone not in this file is marked removed, and their sign-in is turned off." Keep the freshness line (`@latest_roster_import`, `@roster_stale`). Add the `.steps`/`.drop`/`.whatnext` CSS from the mockup.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/admin/roster_imports_controller_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/views/admin/roster_imports/new.html.erb app/assets/tailwind/application.css test/controllers/admin/roster_imports_controller_test.rb
git commit -m "feat: redesign roster upload screen with guided steps and consequences"
```

---

### Task 8: Post Positions management (PositionTitles CRUD)

**Files:**
- Modify: `config/routes.rb` (add `resources :position_titles, only: %i[create update]` in admin namespace)
- Create: `app/controllers/admin/position_titles_controller.rb`
- Test: `test/controllers/admin/position_titles_controller_test.rb`

**Interfaces:**
- Produces: `POST admin_position_titles_path` (create title), `PATCH admin_position_title_path(title)` (rename / reorder / toggle active).

- [ ] **Step 1: Write the failing test**

```ruby
# test/controllers/admin/position_titles_controller_test.rb
require "test_helper"

class Admin::PositionTitlesControllerTest < ActionDispatch::IntegrationTest
  def prepare_setup_complete_state
    @org = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_admin
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
  end

  test "create adds a position title for the organization" do
    prepare_setup_complete_state
    sign_in_admin
    assert_difference -> { PositionTitle.count }, 1 do
      post admin_position_titles_path, params: { position_title: { name: "Chaplain", display_order: 5 } }
    end
    assert_redirected_to admin_root_path
    assert_equal @org.id, PositionTitle.last.organization_id
  end

  test "update can deactivate a title" do
    prepare_setup_complete_state
    sign_in_admin
    title = PositionTitle.create!(organization: @org, name: "Historian", display_order: 9, active: true)
    patch admin_position_title_path(title), params: { position_title: { active: "0" } }
    assert_not title.reload.active
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/admin/position_titles_controller_test.rb`
Expected: FAIL (no route/controller).

- [ ] **Step 3: Add route + controller**

Route (in `namespace :admin`): `resources :position_titles, only: %i[create update]`.

```ruby
# app/controllers/admin/position_titles_controller.rb
module Admin
  class PositionTitlesController < BaseController
    def create
      title = Organization.first.position_titles.new(position_title_params)
      if title.save
        redirect_to admin_root_path, notice: "Post position added."
      else
        redirect_to admin_root_path, alert: title.errors.full_messages.to_sentence
      end
    end

    def update
      title = PositionTitle.find(params[:id])
      if title.update(position_title_params)
        redirect_to admin_root_path, notice: "Post position updated."
      else
        redirect_to admin_root_path, alert: title.errors.full_messages.to_sentence
      end
    end

    private

    def position_title_params
      params.require(:position_title).permit(:name, :display_order, :active)
    end
  end
end
```

Note: `Organization.first.position_titles` requires `Organization has_many :position_titles`. Confirm; if absent, add `has_many :position_titles, dependent: :destroy` to `app/models/organization.rb` in this step.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/admin/position_titles_controller_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add config/routes.rb app/controllers/admin/position_titles_controller.rb app/models/organization.rb test/controllers/admin/position_titles_controller_test.rb
git commit -m "feat: manage post positions (create + update)"
```

---

### Task 9: Admin landing redesign (roster · positions · administrators)

**Files:**
- Modify: `app/controllers/admin/dashboard_controller.rb`
- Modify: `app/views/admin/dashboard/show.html.erb`
- Test: `test/controllers/admin/dashboard_controller_test.rb` (create if absent)

**Interfaces:**
- Consumes: `RosterImport.history`/`latest_successful`/`roster_stale?`, `PositionTitle`, `PermissionGrant`, `legion_date`, `shared/section_panel`.
- Produces: `GET admin_root_path` renders the roster panel (freshness + import + recent imports), Post Positions, and Administrators.

- [ ] **Step 1: Write the failing test**

```ruby
# test/controllers/admin/dashboard_controller_test.rb
require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  def prepare_setup_complete_state
    @org = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_admin
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
    user
  end

  test "landing shows roster, positions, and administrators panels" do
    prepare_setup_complete_state
    admin = sign_in_admin
    RosterImport.create!(status: "completed", imported_at: 1.hour.ago, uploaded_filename: "latest.csv")
    PositionTitle.create!(organization: @org, name: "Commander", display_order: 1, active: true)
    get admin_root_path
    assert_response :success
    assert_select ".card-head-label", text: /Roster/
    assert_select ".card-head-label", text: /Post Positions/
    assert_select ".card-head-label", text: /Administrators/
    assert_select "body", text: /Commander/
    assert_select "body", text: /#{admin.person.full_name}/
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/admin/dashboard_controller_test.rb`
Expected: FAIL (panels/copy not present).

- [ ] **Step 3: Load the data**

```ruby
# app/controllers/admin/dashboard_controller.rb
module Admin
  class DashboardController < BaseController
    def show
      @latest_roster_import = RosterImport.latest_successful
      @roster_stale = RosterImport.roster_stale?
      @recent_imports = RosterImport.history.limit(5)
      @position_titles = PositionTitle.where(organization: Organization.first).order(:display_order, :name)
      @administrators = User.where(disabled_at: nil).joins(:permission_grants)
        .where(permission_grants: { capability: "manage_settings" }).includes(:person).distinct
    end
  end
end
```

- [ ] **Step 4: Port the view**

Port `app/views/admin/dashboard/show.html.erb` to `admin-landing.html` using `shared/section_panel`: the **Roster** panel (freshness banner using `@roster_stale`/`legion_date(@latest_roster_import&.imported_at)`, an "Import roster" link to `new_admin_roster_import_path`, and `@recent_imports` as `.imp` rows linking to `admin_roster_import_path`, plus "View all imports →" to `admin_roster_imports_path`); the **Post Positions** panel (`@position_titles` rows with active/inactive state, an inline `update` form to toggle active, and a "+ Add position" `create` form); and the **Administrators** panel (`@administrators` names + `current_role_label`, with the last-admin safety note). Reuse the `.imp`, `.pos`, `.admrow`, `.fresh` CSS added in Task 6 / the mockup.

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/admin/dashboard_controller_test.rb`
Expected: PASS.

- [ ] **Step 6: Full suite, lint, security, commit**

Run: `bin/rails test` → PASS (all green). Run: `bin/rubocop` → no offenses. Run: `bin/brakeman` → 0 warnings.

```bash
git add app/controllers/admin/dashboard_controller.rb app/views/admin/dashboard/show.html.erb app/assets/tailwind/application.css test/controllers/admin/dashboard_controller_test.rb
git commit -m "feat: redesign Admin landing with roster, positions, and administrators"
```

---

## Self-Review

**Spec coverage (Plan 3 scope):**
- Partial import with per-row problems → Tasks 2, 4. ✓
- Removal detection + `roster_removed_at` → Tasks 1, 4. ✓
- Auto-disable on removal, last-admin guarded, no auto-re-enable, no mass-remove on empty → Tasks 3, 4. ✓
- `removed_count` migration + structured summary → Tasks 1, 4, 5. ✓
- Import history/log → Tasks 5, 6, 9. ✓
- Result screen (tiles/removed/problems), upload screen, Admin landing → Tasks 6, 7, 9. ✓
- Post Positions management → Task 8. ✓
- Administrators overview + last-admin note → Task 9. ✓

**Placeholder scan:** Logic tasks (2–6, 8) carry complete code; view-porting tasks (6, 7, 9) reference the persisted mockups (visual source of truth) and each pins behavior/copy with a controller test. Task 4 Step 4 and Task 8 Step 3 include a conditional (reconcile fixture-based test; confirm/add an association) with the exact check and change — an adaptation instruction, not a placeholder.

**Type consistency:** `CsvParser::Result#{rows,problems,fatal_errors,valid?}` (Task 2) consumed by Importer (Task 4); `Result#removed_count` (Task 4) consumed by result view (Task 6); `User.another_enabled_manage_settings_user_exists?`/`only_enabled_administrator?` (Task 3) consumed by Importer (Task 4); `RosterImport#{problems,removed_members,history}` (Task 5) consumed by controller/views (Tasks 6, 9); `person_path`/`people_path` from Plan 2; `shared/stat_tile`/`shared/section_panel`/`legion_datetime` from Plan 1.

**Cross-plan note:** Task 6's result view links to `person_path` (Plan 2 Task 3). If Plan 3 is executed before Plan 2, substitute `admin_person_path` temporarily or land Plan 2's routes first.

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-12-admin-roster-plan-3-import-behaviors-admin.md`.** All three plans are now written. Recommended execution order: Plan 1 → Plan 2 → Plan 3, subagent-driven (fresh subagent per task, review between).
