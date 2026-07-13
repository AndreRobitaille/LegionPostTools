# Meeting Type Templates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the admin Meeting Types workflow where agenda managers create reusable agenda templates from existing catalog items and customize template-specific wording.

**Architecture:** Add `MeetingType` and `MeetingTypeAgendaItem` as organization-scoped template models, with a seeder that creates the PEC Meeting and Membership Meeting defaults from the existing Agenda Item Catalog. Add admin CRUD, a catalog picker, item editing, and move/remove actions under the existing `manage_agendas` capability.

**Tech Stack:** Rails 8.1, PostgreSQL, Minitest, Hotwire/Turbo-compatible server-rendered ERB, Action Text/Lexxy, Tailwind/app CSS conventions.

---

## File Structure

- Create `db/migrate/20260713020000_create_meeting_types.rb`: table, indexes, defaults for meeting types.
- Create `db/migrate/20260713020100_create_meeting_type_agenda_items.rb`: table and indexes for catalog-backed template items.
- Modify `app/models/organization.rb`: associations.
- Create `app/models/meeting_type.rb`: validations, slug derivation, ordering, seeded helper.
- Create `app/models/meeting_type_agenda_item.rb`: catalog copy behavior, validations, Action Text body, and the `MeetingType` association once the target model exists.
- Create `app/services/meeting_type_template_seeder.rb`: idempotent default meeting type/template seeding.
- Modify `config/routes.rb`: admin routes for meeting types, picker, item edit/update, move/remove actions.
- Create `app/controllers/admin/meeting_types_controller.rb`: index/new/create/edit/update and seed-on-index.
- Create `app/controllers/admin/meeting_type_agenda_items_controller.rb`: picker/add/edit/update/move/remove.
- Create admin views under `app/views/admin/meeting_types/` and `app/views/admin/meeting_type_agenda_items/`.
- Modify `app/views/admin/dashboard/show.html.erb` and `app/views/shared/_primary_nav.html.erb`: link agenda managers to Meeting Types as the main structured-agenda entry point.
- Modify `docs/ROADMAP.md`: mark meeting type creator and meeting templates complete after implementation.
- Add tests under `test/models/`, `test/services/`, and `test/controllers/admin/`.

Do not remove `MeetingBody` in this implementation. Leave it unused and unexposed; removal can be a separate cleanup after confirming all dependencies.

---

### Task 1: Add MeetingType model and migration

**Files:**
- Create: `db/migrate/20260713020000_create_meeting_types.rb`
- Create: `app/models/meeting_type.rb`
- Modify: `app/models/organization.rb`
- Test: `test/models/meeting_type_test.rb`

- [ ] **Step 1: Write the failing model test**

Create `test/models/meeting_type_test.rb`:

```ruby
require "test_helper"

class MeetingTypeTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
  end

  test "derives slug from name when none is given" do
    meeting_type = @organization.meeting_types.create!(name: "PEC Meeting", position: 1, active: true)

    assert_equal "pec-meeting", meeting_type.slug
  end

  test "derived slug avoids collisions within the organization" do
    @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)

    second = @organization.meeting_types.create!(name: "Membership Meeting", position: 2, active: true)

    assert_equal "membership-meeting-2", second.slug
  end

  test "slug uniqueness is scoped to organization" do
    other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)

    meeting_type = other_organization.meeting_types.new(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)

    assert meeting_type.valid?
  end

  test "name uniqueness is scoped to organization" do
    other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)

    duplicate = @organization.meeting_types.new(name: "Membership Meeting", position: 2, active: true)
    same_name_elsewhere = other_organization.meeting_types.new(name: "Membership Meeting", position: 1, active: true)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
    assert same_name_elsewhere.valid?
  end

  test "normalizes blank source key to nil" do
    meeting_type = @organization.meeting_types.create!(name: "Local Meeting", position: 1, active: true, source_key: "")

    assert_nil meeting_type.source_key
    assert_not meeting_type.seeded?
  end

  test "orders by position then name" do
    later = @organization.meeting_types.create!(name: "Later", position: 2, active: true)
    earlier = @organization.meeting_types.create!(name: "Earlier", position: 1, active: true)

    assert_equal [ earlier, later ], @organization.meeting_types.ordered.to_a
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bin/rails test test/models/meeting_type_test.rb
```

Expected: failure or error because `Organization#meeting_types` and `MeetingType` do not exist.

- [ ] **Step 3: Create the migration**

Create `db/migrate/20260713020000_create_meeting_types.rb` with:

```ruby
class CreateMeetingTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :meeting_types do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.string :source_key
      t.string :source_label
      t.datetime :seeded_at

      t.timestamps
    end

    add_index :meeting_types, [ :organization_id, :slug ], unique: true
    add_index :meeting_types, [ :organization_id, :name ], unique: true
    add_index :meeting_types, [ :organization_id, :source_key ], unique: true, where: "source_key IS NOT NULL"
    add_index :meeting_types, [ :organization_id, :position ]
  end
end
```

- [ ] **Step 4: Add the association**

Modify `app/models/organization.rb` to include:

```ruby
has_many :meeting_types, dependent: :destroy
```

Keep existing associations unchanged.

- [ ] **Step 5: Add the model**

Create `app/models/meeting_type.rb`:

```ruby
class MeetingType < ApplicationRecord
  belongs_to :organization

  normalizes :slug, with: ->(value) { value.to_s.strip.downcase }
  before_validation :normalize_optional_fields
  before_validation :ensure_slug

  validates :name, :slug, presence: true
  validates :name, uniqueness: { scope: :organization_id }
  validates :slug, uniqueness: { scope: :organization_id }
  validates :source_key, uniqueness: { scope: :organization_id }, allow_blank: true
  validates :position, numericality: { only_integer: true }

  scope :ordered, -> { order(:position, :name) }
  scope :active, -> { where(active: true) }

  def seeded?
    source_key.present?
  end

  private

  def normalize_optional_fields
    self.source_key = source_key&.strip.presence
  end

  def ensure_slug
    return if slug.present?

    base = name.to_s.parameterize
    return if base.blank?

    candidate = base
    suffix = 2
    scope = organization&.meeting_types&.where&.not(id: id)
    while scope&.exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end
end
```

Do not add `has_many :meeting_type_agenda_items` in Task 1. Add it in Task 2 when `MeetingTypeAgendaItem` exists, so the app does not have a temporarily broken association.

- [ ] **Step 6: Run migration and model test**

Run:

```bash
bin/rails db:migrate
bin/rails test test/models/meeting_type_test.rb
```

Expected: migration succeeds and tests pass.

- [ ] **Step 7: Commit**

```bash
git add db/migrate app/models/organization.rb app/models/meeting_type.rb test/models/meeting_type_test.rb db/schema.rb
git commit -m "feat: add meeting type model"
```

---

### Task 2: Add MeetingTypeAgendaItem model and copy behavior

**Files:**
- Create: `db/migrate/20260713020100_create_meeting_type_agenda_items.rb`
- Create: `app/models/meeting_type_agenda_item.rb`
- Modify: `app/models/meeting_type.rb`
- Test: `test/models/meeting_type_agenda_item_test.rb`

- [ ] **Step 1: Write the failing model test**

Create `test/models/meeting_type_agenda_item_test.rb`:

```ruby
require "test_helper"

class MeetingTypeAgendaItemTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @catalog_entry = @organization.agenda_item_catalog_entries.create!(
      title: "Opening Ceremony",
      summary: "Open the meeting",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true,
      body: "Original opening wording"
    )
  end

  test "copies title summary and body from catalog entry" do
    item = @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(@catalog_entry, position: 1)

    assert_equal "Opening Ceremony", item.title
    assert_equal "Open the meeting", item.summary
    assert_equal "Original opening wording", item.body.to_plain_text
  end

  test "template edits do not modify the catalog entry" do
    item = @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(@catalog_entry, position: 1)

    item.update!(title: "Local Opening", summary: "Local summary", body: "Local wording")

    assert_equal "Opening Ceremony", @catalog_entry.reload.title
    assert_equal "Open the meeting", @catalog_entry.summary
    assert_equal "Original opening wording", @catalog_entry.body.to_plain_text
  end

  test "prevents duplicate catalog entry in same meeting type" do
    @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(@catalog_entry, position: 1)
    duplicate = @meeting_type.meeting_type_agenda_items.new(agenda_item_catalog_entry: @catalog_entry, position: 2, title: "Duplicate", active: true)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:agenda_item_catalog_entry_id], "has already been taken"
  end

  test "same catalog entry can be used by another meeting type in same organization" do
    other_meeting_type = @organization.meeting_types.create!(name: "PEC Meeting", position: 2, active: true)
    @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(@catalog_entry, position: 1)

    item = other_meeting_type.meeting_type_agenda_items.new(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "Opening", active: true)

    assert item.valid?
  end

  test "rejects catalog entries from another organization" do
    other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_entry = other_organization.agenda_item_catalog_entries.create!(
      title: "Other Entry",
      category: "business",
      behavior_type: "business_item",
      position: 1,
      active: true
    )

    item = @meeting_type.meeting_type_agenda_items.new(agenda_item_catalog_entry: other_entry, position: 1, title: "Bad", active: true)

    assert_not item.valid?
    assert_includes item.errors[:agenda_item_catalog_entry], "must belong to the same organization"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bin/rails test test/models/meeting_type_agenda_item_test.rb
```

Expected: failure or error because `MeetingTypeAgendaItem` does not exist.

- [ ] **Step 3: Create the migration**

Create `db/migrate/20260713020100_create_meeting_type_agenda_items.rb` with:

```ruby
class CreateMeetingTypeAgendaItems < ActiveRecord::Migration[8.1]
  def change
    create_table :meeting_type_agenda_items do |t|
      t.references :meeting_type, null: false, foreign_key: true
      t.references :agenda_item_catalog_entry, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :title, null: false
      t.text :summary, null: false, default: ""
      t.boolean :active, null: false, default: true
      t.string :source_key
      t.string :source_label
      t.datetime :seeded_at

      t.timestamps
    end

    add_index :meeting_type_agenda_items, [ :meeting_type_id, :position ], name: "index_mt_agenda_items_on_meeting_type_and_position"
    add_index :meeting_type_agenda_items, [ :meeting_type_id, :agenda_item_catalog_entry_id ], unique: true, name: "index_mt_agenda_items_on_type_and_catalog_entry"
    add_index :meeting_type_agenda_items, [ :meeting_type_id, :source_key ], unique: true, where: "source_key IS NOT NULL", name: "index_mt_agenda_items_on_type_and_source_key"
  end
end
```

- [ ] **Step 4: Create the model**

Create `app/models/meeting_type_agenda_item.rb`:

```ruby
class MeetingTypeAgendaItem < ApplicationRecord
  belongs_to :meeting_type
  belongs_to :agenda_item_catalog_entry
  has_rich_text :body

  before_validation :normalize_optional_fields

  validates :title, presence: true
  validates :position, numericality: { only_integer: true }
  validates :agenda_item_catalog_entry_id, uniqueness: { scope: :meeting_type_id }
  validates :source_key, uniqueness: { scope: :meeting_type_id }, allow_blank: true
  validate :catalog_entry_belongs_to_same_organization

  scope :ordered, -> { order(:position, :title) }
  scope :active, -> { where(active: true) }

  def self.create_from_catalog_entry!(catalog_entry, position:)
    create!(
      agenda_item_catalog_entry: catalog_entry,
      position: position,
      title: catalog_entry.title,
      summary: catalog_entry.summary,
      active: true,
      body: catalog_entry.body.to_s
    )
  end

  def seeded?
    source_key.present?
  end

  private

  def normalize_optional_fields
    self.summary = summary.to_s
    self.source_key = source_key&.strip.presence
  end

  def catalog_entry_belongs_to_same_organization
    return if meeting_type.blank? || agenda_item_catalog_entry.blank?
    return if meeting_type.organization_id == agenda_item_catalog_entry.organization_id

    errors.add(:agenda_item_catalog_entry, "must belong to the same organization")
  end
end
```

- [ ] **Step 5: Run migration and model test**

Run:

```bash
bin/rails db:migrate
bin/rails test test/models/meeting_type_agenda_item_test.rb
```

Expected: migration succeeds and tests pass.

- [ ] **Step 6: Commit**

```bash
git add db/migrate app/models/meeting_type_agenda_item.rb test/models/meeting_type_agenda_item_test.rb db/schema.rb
git commit -m "feat: add meeting type agenda items"
```

---

### Task 3: Add idempotent default meeting type template seeding

**Files:**
- Create: `app/services/meeting_type_template_seeder.rb`
- Test: `test/services/meeting_type_template_seeder_test.rb`

- [ ] **Step 1: Write the failing service test**

Create `test/services/meeting_type_template_seeder_test.rb`:

```ruby
require "test_helper"

class MeetingTypeTemplateSeederTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    AgendaItemCatalogSeeder.seed_for!(@organization)
  end

  test "seeds default meeting types" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    assert_equal [ "PEC Meeting", "Membership Meeting" ], @organization.meeting_types.ordered.pluck(:name)
    assert @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting").seeded?
    assert @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting").seeded?
  end

  test "seeds membership meeting with ceremony and reports" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    titles = membership.meeting_type_agenda_items.ordered.pluck(:title)

    assert_includes titles, "Opening Ceremony"
    assert_includes titles, "Committee Reports"
    assert_includes titles, "Closing Ceremony"
  end

  test "seeds pec meeting without ceremony or officer reports" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    titles = pec.meeting_type_agenda_items.ordered.pluck(:title)

    assert_includes titles, "Roll Call and Quorum"
    assert_includes titles, "Previous Meeting Minutes"
    assert_includes titles, "Unfinished / Old Business"
    assert_includes titles, "New Business and Correspondence"
    assert_not_includes titles, "Opening Ceremony"
    assert_not_includes titles, "Closing Ceremony"
    assert_not_includes titles, "Committee Reports"
  end

  test "reseeding does not overwrite local edits" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    membership = @organization.meeting_types.find_by!(source_key: "american_legion_post:membership_meeting")
    item = membership.meeting_type_agenda_items.ordered.first

    membership.update!(name: "Local Membership Meeting", active: false)
    item.update!(title: "Local Template Item", summary: "Local summary", body: "Local body", position: 99, active: false)

    MeetingTypeTemplateSeeder.seed_for!(@organization)

    assert_equal "Local Membership Meeting", membership.reload.name
    assert_not membership.active?
    assert_equal "Local Template Item", item.reload.title
    assert_equal "Local summary", item.summary
    assert_equal "Local body", item.body.to_plain_text
    assert_equal 99, item.position
    assert_not item.active?
  end

  test "seeding is independent by organization" do
    other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    AgendaItemCatalogSeeder.seed_for!(other_organization)

    MeetingTypeTemplateSeeder.seed_for!(@organization)
    MeetingTypeTemplateSeeder.seed_for!(other_organization)

    assert_equal 2, @organization.meeting_types.count
    assert_equal 2, other_organization.meeting_types.count
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bin/rails test test/services/meeting_type_template_seeder_test.rb
```

Expected: failure because `MeetingTypeTemplateSeeder` does not exist.

- [ ] **Step 3: Create the seeder**

Create `app/services/meeting_type_template_seeder.rb`:

```ruby
class MeetingTypeTemplateSeeder
  SOURCE_LABEL = "American Legion meeting type template seed".freeze

  MEETING_TYPES = [
    {
      name: "PEC Meeting",
      source_key: "american_legion_post:pec_meeting",
      position: 1,
      item_source_keys: [
        "regular_meeting.roll_call_quorum",
        "regular_meeting.previous_minutes",
        "regular_meeting.unfinished_old_business",
        "regular_meeting.new_business_correspondence",
        "regular_meeting.good_of_legion"
      ]
    },
    {
      name: "Membership Meeting",
      source_key: "american_legion_post:membership_meeting",
      position: 2,
      item_source_keys: [
        "regular_meeting.opening_ceremony",
        "regular_meeting.opening_prayer",
        "regular_meeting.pow_mia_empty_chair",
        "regular_meeting.pledge_of_allegiance",
        "regular_meeting.preamble",
        "regular_meeting.roll_call_quorum",
        "regular_meeting.previous_minutes",
        "regular_meeting.introductions",
        "regular_meeting.committee_reports",
        "regular_meeting.balloting_on_applications",
        "regular_meeting.sick_call_relief_employment",
        "regular_meeting.service_officer_report",
        "regular_meeting.unfinished_old_business",
        "regular_meeting.new_business_correspondence",
        "regular_meeting.memorial_departed_member",
        "regular_meeting.good_of_legion",
        "regular_meeting.closing_ceremony"
      ]
    }
  ].freeze

  def self.seed_for!(organization)
    new(organization).seed!
  end

  def initialize(organization)
    @organization = organization
  end

  def seed!
    AgendaItemCatalogSeeder.seed_for!(organization)

    ApplicationRecord.transaction do
      MEETING_TYPES.each { |definition| seed_meeting_type(definition) }
    end
  end

  private

  attr_reader :organization

  def seed_meeting_type(definition)
    meeting_type = organization.meeting_types.find_or_initialize_by(source_key: definition.fetch(:source_key))
    if meeting_type.new_record?
      meeting_type.name = definition.fetch(:name)
      meeting_type.position = definition.fetch(:position)
      meeting_type.active = true
      meeting_type.source_label = SOURCE_LABEL
      meeting_type.seeded_at = Time.current
      meeting_type.save!
    end

    definition.fetch(:item_source_keys).each_with_index do |catalog_source_key, index|
      seed_template_item(meeting_type, catalog_source_key, index + 1)
    end
  end

  def seed_template_item(meeting_type, catalog_source_key, position)
    catalog_entry = organization.agenda_item_catalog_entries.find_by!(source_key: catalog_source_key)
    source_key = "#{meeting_type.source_key}:#{catalog_source_key}"
    item = meeting_type.meeting_type_agenda_items.find_or_initialize_by(source_key: source_key)
    return unless item.new_record?

    item.agenda_item_catalog_entry = catalog_entry
    item.position = position
    item.title = catalog_entry.title
    item.summary = catalog_entry.summary
    item.active = true
    item.source_label = SOURCE_LABEL
    item.seeded_at = Time.current
    item.body = catalog_entry.body.to_s
    item.save!
  end
end
```

- [ ] **Step 4: Run service tests**

Run:

```bash
bin/rails test test/services/meeting_type_template_seeder_test.rb
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/meeting_type_template_seeder.rb test/services/meeting_type_template_seeder_test.rb
git commit -m "feat: seed meeting type templates"
```

---

### Task 4: Add admin meeting type CRUD

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/admin/meeting_types_controller.rb`
- Create: `app/views/admin/meeting_types/index.html.erb`
- Create: `app/views/admin/meeting_types/new.html.erb`
- Create: `app/views/admin/meeting_types/edit.html.erb`
- Create: `app/views/admin/meeting_types/_form.html.erb`
- Test: `test/controllers/admin/meeting_types_controller_test.rb`

- [ ] **Step 1: Write the failing controller test**

Create `test/controllers/admin/meeting_types_controller_test.rb`:

```ruby
require "test_helper"

class Admin::MeetingTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  test "signed out users are redirected" do
    get admin_meeting_types_path

    assert_redirected_to new_session_path
  end

  test "users without manage_agendas are denied" do
    sign_in_as(user_with_capabilities)

    get admin_meeting_types_path

    assert_redirected_to root_path
    assert_equal "You do not have permission to open that page.", flash[:alert]
  end

  test "index seeds and lists meeting types" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get admin_meeting_types_path

    assert_response :success
    assert_select "h1", text: /Meeting Types/
    assert_select "body", text: /PEC Meeting/
    assert_select "body", text: /Membership Meeting/
  end

  test "create meeting type" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    assert_difference -> { @organization.meeting_types.count }, 1 do
      post admin_meeting_types_path, params: { meeting_type: { name: "Special Ceremony Meeting", active: true } }
    end

    meeting_type = @organization.meeting_types.find_by!(slug: "special-ceremony-meeting")
    assert_redirected_to edit_admin_meeting_type_path(meeting_type)
    assert_equal "Meeting type created.", flash[:notice]
  end

  test "invalid create returns unprocessable entity" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    post admin_meeting_types_path, params: { meeting_type: { name: "", active: true } }

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /Name can't be blank/
  end

  test "update meeting type" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    meeting_type = @organization.meeting_types.create!(name: "Old Name", position: 1, active: true)

    patch admin_meeting_type_path(meeting_type), params: { meeting_type: { name: "New Name", active: false } }

    assert_redirected_to edit_admin_meeting_type_path(meeting_type)
    assert_equal "Meeting type updated.", flash[:notice]
    assert_equal "New Name", meeting_type.reload.name
    assert_not meeting_type.active?
  end

  test "edit form hides developer fields" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)

    get edit_admin_meeting_type_path(meeting_type)

    assert_response :success
    assert_select "input[name=?]", "meeting_type[name]"
    assert_select "input[name=?]", "meeting_type[active]"
    assert_select "input[name=?]", "meeting_type[slug]", count: 0
    assert_select "input[name=?]", "meeting_type[position]", count: 0
  end

  test "cannot edit another organization meeting type" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    meeting_type = other.meeting_types.create!(name: "Other Meeting", position: 1, active: true)

    get edit_admin_meeting_type_path(meeting_type)
    assert_response :not_found
  end

  private

  def user_with_capabilities(*capabilities)
    person = Person.create!(first_name: "Test", last_name: "User")
    user = User.create!(person: person, email_address: "test-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bin/rails test test/controllers/admin/meeting_types_controller_test.rb
```

Expected: route/controller errors.

- [ ] **Step 3: Add routes**

Modify `config/routes.rb` inside `namespace :admin do`:

```ruby
resources :meeting_types, except: %i[show destroy]
```

- [ ] **Step 4: Add controller**

Create `app/controllers/admin/meeting_types_controller.rb`:

```ruby
module Admin
  class MeetingTypesController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_meeting_type, only: %i[edit update]

    def index
      MeetingTypeTemplateSeeder.seed_for!(@organization)
      @meeting_types = @organization.meeting_types.ordered.includes(:meeting_type_agenda_items)
    end

    def new
      @meeting_type = @organization.meeting_types.new(active: true)
    end

    def create
      @meeting_type = @organization.meeting_types.new(meeting_type_params)
      @meeting_type.position = next_position if @meeting_type.position.to_i.zero?

      if @meeting_type.save
        redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Meeting type created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @template_items = @meeting_type.meeting_type_agenda_items.ordered
    end

    def update
      if @meeting_type.update(meeting_type_params)
        redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Meeting type updated."
      else
        @template_items = @meeting_type.meeting_type_agenda_items.ordered
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_meeting_type
      @meeting_type = @organization.meeting_types.find(params[:id])
    end

    def next_position
      @organization.meeting_types.maximum(:position).to_i + 1
    end

    def meeting_type_params
      params.require(:meeting_type).permit(:name, :active)
    end
  end
end
```

- [ ] **Step 5: Add views**

Create `app/views/admin/meeting_types/index.html.erb`:

```erb
<% content_for :title, "Meeting Types" %>
<% back_path = current_user.can?("manage_settings") ? admin_root_path : root_path %>
<% back_label = current_user.can?("manage_settings") ? "Administration" : "Dashboard" %>
<a class="back" href="<%= back_path %>">&larr; <%= back_label %></a>

<div class="page-lead">
  <h1 class="page-title">Meeting Types</h1>
  <p class="page-sub">Create reusable agenda templates for the kinds of meetings your post holds.</p>
</div>

<div class="btnrow">
  <%= link_to "Add meeting type", new_admin_meeting_type_path, class: "btn-primary" %>
</div>

<div class="mrow-list">
  <% @meeting_types.each do |meeting_type| %>
    <%= link_to edit_admin_meeting_type_path(meeting_type), class: "mrow catrow#{' mrow--inactive' unless meeting_type.active?}", aria: { label: "Edit #{meeting_type.name}" } do %>
      <span class="mrow-id">
        <span class="mrow-name"><%= meeting_type.name %></span>
        <span class="mrow-sub"><%= pluralize(meeting_type.meeting_type_agenda_items.size, "template item") %></span>
      </span>
      <span class="catrow-meta">
        <% unless meeting_type.active? %><%= agenda_active_tag(false) %><% end %>
        <% unless meeting_type.seeded? %><span class="catrow-flag">Added by your post</span><% end %>
        <span class="catrow-edit">Edit<span class="catrow-caret" aria-hidden="true">&rsaquo;</span></span>
      </span>
    <% end %>
  <% end %>
</div>
```

Create `app/views/admin/meeting_types/new.html.erb`:

```erb
<% content_for :title, "Add Meeting Type" %>
<a class="back" href="<%= admin_meeting_types_path %>">&larr; Meeting Types</a>

<div class="page-lead">
  <h1 class="page-title">Add Meeting Type</h1>
  <p class="page-sub">Create a reusable agenda template for another kind of post meeting.</p>
</div>

<div class="panel form-panel">
  <%= render "form", meeting_type: @meeting_type %>
</div>
```

Create `app/views/admin/meeting_types/edit.html.erb`:

```erb
<% content_for :title, @meeting_type.name %>
<a class="back" href="<%= admin_meeting_types_path %>">&larr; Meeting Types</a>

<div class="page-lead">
  <h1 class="page-title"><%= @meeting_type.name %></h1>
  <p class="page-sub">Choose catalog items, set their order, and customize the wording for this meeting type only.</p>
</div>

<div class="panel form-panel">
  <%= render "form", meeting_type: @meeting_type %>
</div>

<div class="sec-head-row" style="margin-top: 22px">
  <%= render "shared/section_header", label: "Template agenda" %>
</div>

<div class="btnrow">
  <%= link_to "Add catalog item", new_admin_meeting_type_agenda_item_path(@meeting_type), class: "btn-primary" %>
</div>

<div class="mrow-list">
  <% @template_items.each do |item| %>
    <%= link_to edit_admin_meeting_type_agenda_item_path(@meeting_type, item), class: "mrow catrow#{' mrow--inactive' unless item.active?}" do %>
      <span class="mrow-id">
        <span class="mrow-name"><%= item.title %></span>
        <% if item.summary.present? %><span class="mrow-sub"><%= item.summary %></span><% end %>
      </span>
      <span class="catrow-meta">
        <% unless item.active? %><%= agenda_active_tag(false) %><% end %>
        <span class="catrow-edit">Edit<span class="catrow-caret" aria-hidden="true">&rsaquo;</span></span>
      </span>
    <% end %>
  <% end %>
</div>
```

Create `app/views/admin/meeting_types/_form.html.erb`:

```erb
<%= form_with model: [:admin, meeting_type], class: "stacked-form" do |form| %>
  <% if meeting_type.errors.any? %>
    <div class="error-summary">
      <h2><%= pluralize(meeting_type.errors.count, "error") %> prohibited this meeting type from being saved:</h2>
      <ul>
        <% meeting_type.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="fl">
    <%= form.label :name %>
    <%= form.text_field :name, class: "f" %>
  </div>

  <label class="form-toggle">
    <%= form.check_box :active %>
    <span>
      <span class="ft-label">Active</span>
      <span class="ft-help">Inactive meeting types stay saved but are hidden from future agenda creation.</span>
    </span>
  </label>

  <div class="btnrow">
    <%= form.submit "Save changes", class: "btn-primary" %>
    <%= link_to "Cancel", admin_meeting_types_path, class: "btn-secondary" %>
  </div>
<% end %>
```

- [ ] **Step 6: Run controller test**

Run:

```bash
bin/rails test test/controllers/admin/meeting_types_controller_test.rb
```

Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/admin/meeting_types_controller.rb app/views/admin/meeting_types test/controllers/admin/meeting_types_controller_test.rb
git commit -m "feat: add admin meeting types"
```

---

### Task 5: Add picker, template item editing, move, and remove actions

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/admin/meeting_type_agenda_items_controller.rb`
- Create: `app/views/admin/meeting_type_agenda_items/new.html.erb`
- Create: `app/views/admin/meeting_type_agenda_items/edit.html.erb`
- Create: `app/views/admin/meeting_type_agenda_items/_form.html.erb`
- Modify: `app/views/admin/meeting_types/edit.html.erb`
- Test: `test/controllers/admin/meeting_type_agenda_items_controller_test.rb`

- [ ] **Step 1: Write the failing controller test**

Create `test/controllers/admin/meeting_type_agenda_items_controller_test.rb`:

```ruby
require "test_helper"

class Admin::MeetingTypeAgendaItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @catalog_entry = @organization.agenda_item_catalog_entries.create!(
      title: "Opening Ceremony",
      summary: "Open the meeting",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true,
      body: "Opening words"
    )
    @inactive_entry = @organization.agenda_item_catalog_entries.create!(
      title: "Inactive Entry",
      category: "business",
      behavior_type: "business_item",
      position: 2,
      active: false
    )
  end

  test "picker requires manage_agendas" do
    sign_in_as(user_with_capabilities)

    get new_admin_meeting_type_agenda_item_path(@meeting_type)
    assert_redirected_to root_path
  end

  test "picker lists active catalog entries and excludes inactive entries" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get new_admin_meeting_type_agenda_item_path(@meeting_type)

    assert_response :success
    assert_select "h1", text: /Add Catalog Item/
    assert_select "body", text: /Opening Ceremony/
    assert_select "body", text: { count: 0, text: /Inactive Entry/ }
  end

  test "add catalog item copies it into meeting type" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    assert_difference -> { @meeting_type.meeting_type_agenda_items.count }, 1 do
      post admin_meeting_type_agenda_items_path(@meeting_type), params: { agenda_item_catalog_entry_id: @catalog_entry.id }
    end

    item = @meeting_type.meeting_type_agenda_items.find_by!(agenda_item_catalog_entry: @catalog_entry)
    assert_redirected_to edit_admin_meeting_type_path(@meeting_type)
    assert_equal "Opening Ceremony", item.title
    assert_equal "Opening words", item.body.to_plain_text
  end

  test "duplicate add is rejected" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(@catalog_entry, position: 1)

    assert_no_difference -> { @meeting_type.meeting_type_agenda_items.count } do
      post admin_meeting_type_agenda_items_path(@meeting_type), params: { agenda_item_catalog_entry_id: @catalog_entry.id }
    end

    assert_redirected_to new_admin_meeting_type_agenda_item_path(@meeting_type)
    assert_equal "That catalog item is already in this meeting type.", flash[:alert]
  end

  test "update template item wording without changing catalog" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(@catalog_entry, position: 1)

    patch admin_meeting_type_agenda_item_path(@meeting_type, item), params: {
      meeting_type_agenda_item: { title: "Local Opening", summary: "Local summary", active: false, body: "Local wording" }
    }

    assert_redirected_to edit_admin_meeting_type_path(@meeting_type)
    assert_equal "Template item updated.", flash[:notice]
    assert_equal "Local Opening", item.reload.title
    assert_equal "Local wording", item.body.to_plain_text
    assert_equal "Opening Ceremony", @catalog_entry.reload.title
    assert_equal "Opening words", @catalog_entry.body.to_plain_text
  end

  test "move item up and down" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    first = @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(@catalog_entry, position: 1)
    second_catalog = @organization.agenda_item_catalog_entries.create!(title: "New Business", category: "business", behavior_type: "business_item", position: 3, active: true)
    second = @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(second_catalog, position: 2)

    patch move_admin_meeting_type_agenda_item_path(@meeting_type, second), params: { direction: "up" }

    assert_equal 2, first.reload.position
    assert_equal 1, second.reload.position

    patch move_admin_meeting_type_agenda_item_path(@meeting_type, second), params: { direction: "down" }

    assert_equal 1, first.reload.position
    assert_equal 2, second.reload.position
  end

  test "remove deletes only template item" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(@catalog_entry, position: 1)

    assert_difference -> { @meeting_type.meeting_type_agenda_items.count }, -1 do
      delete admin_meeting_type_agenda_item_path(@meeting_type, item)
    end

    assert @organization.agenda_item_catalog_entries.exists?(@catalog_entry.id)
    assert_redirected_to edit_admin_meeting_type_path(@meeting_type)
  end

  private

  def user_with_capabilities(*capabilities)
    person = Person.create!(first_name: "Test", last_name: "User")
    user = User.create!(person: person, email_address: "test-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bin/rails test test/controllers/admin/meeting_type_agenda_items_controller_test.rb
```

Expected: route/controller errors.

- [ ] **Step 3: Add nested routes**

Modify `config/routes.rb` so meeting types use this block:

```ruby
resources :meeting_types, except: %i[show destroy] do
  resources :agenda_items, controller: "meeting_type_agenda_items", as: :agenda_items, only: %i[new create edit update destroy] do
    patch :move, on: :member
  end
end
```

Use the route helpers generated by Rails. If helper names differ from the test names above, update the test to match `bin/rails routes | grep meeting_type`.

- [ ] **Step 4: Add controller**

Create `app/controllers/admin/meeting_type_agenda_items_controller.rb`:

```ruby
module Admin
  class MeetingTypeAgendaItemsController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_meeting_type
    before_action :set_item, only: %i[edit update destroy move]

    def new
      existing_ids = @meeting_type.meeting_type_agenda_items.pluck(:agenda_item_catalog_entry_id)
      grouped = @organization.agenda_item_catalog_entries.active.ordered.group_by(&:category)
      @entries_by_category = AgendaItemCatalogEntry::CATEGORIES.keys.filter_map do |category|
        entries = grouped[category]
        [ category, entries ] if entries.present?
      end
      @existing_catalog_entry_ids = existing_ids.to_set
    end

    def create
      catalog_entry = @organization.agenda_item_catalog_entries.active.find(params[:agenda_item_catalog_entry_id])
      if @meeting_type.meeting_type_agenda_items.exists?(agenda_item_catalog_entry: catalog_entry)
        redirect_to new_admin_meeting_type_agenda_item_path(@meeting_type), alert: "That catalog item is already in this meeting type."
        return
      end

      @meeting_type.meeting_type_agenda_items.create_from_catalog_entry!(catalog_entry, position: next_position)
      redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Catalog item added."
    end

    def edit; end

    def update
      if @item.update(item_params)
        redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Template item updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @item.destroy!
      redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Template item removed."
    end

    def move
      swap_with_neighbor(params[:direction])
      redirect_to edit_admin_meeting_type_path(@meeting_type)
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_meeting_type
      @meeting_type = @organization.meeting_types.find(params[:meeting_type_id])
    end

    def set_item
      @item = @meeting_type.meeting_type_agenda_items.find(params[:id])
    end

    def next_position
      @meeting_type.meeting_type_agenda_items.maximum(:position).to_i + 1
    end

    def item_params
      params.require(:meeting_type_agenda_item).permit(:title, :summary, :active, :body)
    end

    def swap_with_neighbor(direction)
      ordered_items = @meeting_type.meeting_type_agenda_items.ordered.to_a
      index = ordered_items.index(@item)
      neighbor = direction == "up" ? ordered_items[index - 1] : ordered_items[index + 1]
      return if neighbor.blank? || (direction == "up" && index.zero?)

      @item_position = @item.position
      @item.update!(position: neighbor.position)
      neighbor.update!(position: @item_position)
    end
  end
end
```

- [ ] **Step 5: Add picker and edit views**

Create `app/views/admin/meeting_type_agenda_items/new.html.erb`:

```erb
<% content_for :title, "Add Catalog Item" %>
<a class="back" href="<%= edit_admin_meeting_type_path(@meeting_type) %>">&larr; <%= @meeting_type.name %></a>

<div class="page-lead">
  <h1 class="page-title">Add Catalog Item</h1>
  <p class="page-sub">Choose an existing catalog item to copy into this meeting type.</p>
</div>

<% @entries_by_category.each do |category, entries| %>
  <div class="sec-head-row" style="margin-top: 22px">
    <%= render "shared/section_header", label: AgendaItemCatalogEntry::CATEGORIES.fetch(category) %>
  </div>
  <div class="mrow-list">
    <% entries.each do |entry| %>
      <% already_added = @existing_catalog_entry_ids.include?(entry.id) %>
      <% if already_added %>
        <div class="mrow catrow mrow--inactive">
          <span class="mrow-id">
            <span class="mrow-name"><%= entry.title %></span>
            <% if entry.summary.present? %><span class="mrow-sub"><%= entry.summary %></span><% end %>
          </span>
          <span class="catrow-meta"><span class="catrow-flag">Already added</span></span>
        </div>
      <% else %>
        <%= button_to admin_meeting_type_agenda_items_path(@meeting_type), params: { agenda_item_catalog_entry_id: entry.id }, class: "mrow catrow", form_class: "button-to-mrow" do %>
          <span class="mrow-id">
            <span class="mrow-name"><%= entry.title %></span>
            <% if entry.summary.present? %><span class="mrow-sub"><%= entry.summary %></span><% end %>
          </span>
          <span class="catrow-meta"><span class="catrow-edit">Add<span class="catrow-caret" aria-hidden="true">&rsaquo;</span></span></span>
        <% end %>
      <% end %>
    <% end %>
  </div>
<% end %>
```

Create `app/views/admin/meeting_type_agenda_items/edit.html.erb`:

```erb
<% content_for :title, "Edit #{@item.title}" %>
<a class="back" href="<%= edit_admin_meeting_type_path(@meeting_type) %>">&larr; <%= @meeting_type.name %></a>

<div class="page-lead">
  <h1 class="page-title"><%= @item.title %></h1>
  <p class="page-sub">This changes this meeting type only. It will not change the Agenda Item Catalog.</p>
</div>

<div class="panel form-panel">
  <%= render "form", meeting_type: @meeting_type, item: @item %>
</div>
```

Create `app/views/admin/meeting_type_agenda_items/_form.html.erb`:

```erb
<%= form_with model: [:admin, meeting_type, item], class: "stacked-form" do |form| %>
  <% if item.errors.any? %>
    <div class="error-summary">
      <h2><%= pluralize(item.errors.count, "error") %> prohibited this template item from being saved:</h2>
      <ul>
        <% item.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="fl">
    <%= form.label :title %>
    <%= form.text_field :title, class: "f" %>
  </div>
  <div class="fl">
    <%= form.label :summary, "Summary or guidance" %>
    <%= form.text_area :summary, class: "f", rows: 3 %>
  </div>
  <div class="fl">
    <%= form.label :body, "Wording" %>
    <p class="fl-help">This wording is used for this meeting type only.</p>
    <%= form.rich_text_area :body, attachments: "false" %>
  </div>
  <label class="form-toggle">
    <%= form.check_box :active %>
    <span>
      <span class="ft-label">Included</span>
      <span class="ft-help">Turn this off to keep the item saved here but hidden from future agendas.</span>
    </span>
  </label>
  <div class="btnrow">
    <%= form.submit "Save changes", class: "btn-primary" %>
    <%= link_to "Cancel", edit_admin_meeting_type_path(meeting_type), class: "btn-secondary" %>
  </div>
<% end %>
```

- [ ] **Step 6: Add move/remove controls to template item rows**

Modify each item row in `app/views/admin/meeting_types/edit.html.erb` so the row body includes controls after the edit link:

```erb
<span class="catrow-meta">
  <% unless item.active? %><%= agenda_active_tag(false) %><% end %>
  <%= button_to "Up", move_admin_meeting_type_agenda_item_path(@meeting_type, item), params: { direction: "up" }, method: :patch, class: "btn-secondary" %>
  <%= button_to "Down", move_admin_meeting_type_agenda_item_path(@meeting_type, item), params: { direction: "down" }, method: :patch, class: "btn-secondary" %>
  <%= button_to "Remove", admin_meeting_type_agenda_item_path(@meeting_type, item), method: :delete, class: "btn-secondary", data: { turbo_confirm: "Remove this item from this meeting type?" } %>
  <span class="catrow-edit">Edit<span class="catrow-caret" aria-hidden="true">&rsaquo;</span></span>
</span>
```

If nested `button_to` inside `link_to` produces invalid HTML, replace the row link with a non-link `.mrow` container and a separate `Edit` link in `catrow-meta`.

- [ ] **Step 7: Run controller test**

Run:

```bash
bin/rails test test/controllers/admin/meeting_type_agenda_items_controller_test.rb
```

Expected: pass.

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/admin/meeting_type_agenda_items_controller.rb app/views/admin/meeting_type_agenda_items app/views/admin/meeting_types/edit.html.erb test/controllers/admin/meeting_type_agenda_items_controller_test.rb
git commit -m "feat: manage meeting type template items"
```

---

### Task 6: Wire navigation and roadmap

**Files:**
- Modify: `app/views/admin/dashboard/show.html.erb`
- Modify: `app/views/shared/_primary_nav.html.erb`
- Modify: `docs/ROADMAP.md`
- Test: `test/controllers/admin/dashboard_controller_test.rb`
- Test: `test/integration/primary_nav_test.rb`

- [ ] **Step 1: Update existing navigation tests**

Modify existing assertions that point agenda managers directly to the Agenda Item Catalog so they now point to `admin_meeting_types_path`. Keep the Agenda Item Catalog reachable from the admin dashboard or Meeting Types workflow for users with `manage_agendas`.

Use assertions like:

```ruby
assert_select "a[href=?]", admin_meeting_types_path, text: /Meeting Types/
assert_select "a[href=?]", admin_agenda_item_catalog_entries_path, text: /Agenda Item Catalog/
```

- [ ] **Step 2: Run tests to verify they fail before view changes**

Run:

```bash
bin/rails test test/controllers/admin/dashboard_controller_test.rb test/integration/primary_nav_test.rb
```

Expected: failures where links still target the old catalog-only entry point.

- [ ] **Step 3: Update dashboard links**

In `app/views/admin/dashboard/show.html.erb`, add or update a card for agenda managers:

```erb
<%= link_to admin_meeting_types_path, class: "admin-card" do %>
  <span class="admin-card-title">Meeting Types</span>
  <span class="admin-card-sub">Build reusable agenda templates from the catalog.</span>
<% end %>
```

Keep a secondary Agenda Item Catalog link for managing the reusable source items:

```erb
<%= link_to admin_agenda_item_catalog_entries_path, class: "admin-card" do %>
  <span class="admin-card-title">Agenda Item Catalog</span>
  <span class="admin-card-sub">Edit the reusable building blocks used by meeting templates.</span>
<% end %>
```

- [ ] **Step 4: Update primary nav**

In `app/views/shared/_primary_nav.html.erb`, make the agenda-manager admin link prefer Meeting Types:

```erb
<% if current_user.can?("manage_settings") %>
  <%= link_to "Admin", admin_root_path %>
<% elsif current_user.can?("manage_agendas") %>
  <%= link_to "Meeting Types", admin_meeting_types_path %>
<% end %>
```

Preserve surrounding nav markup and active classes already present in the file.

- [ ] **Step 5: Update roadmap after implementation**

In `docs/ROADMAP.md`, move these items from pending to completed Structured Agendas foundation:

```markdown
- Meeting type templates: seeded PEC Meeting and Membership Meeting, admin-created meeting types, catalog-item picker, template-specific rich text wording overrides, and item ordering/removal.
```

Remove these pending bullets if fully satisfied by the implementation:

```markdown
- Meeting type creator.
- Meeting templates.
- Structured agenda items.
- Item-level rich notes.
- Reordering and moving agenda items.
```

Leave pending:

```markdown
- Agenda sections.
- Browser/HTML printable agenda rendering for on-screen review and printing.
- Later guided workflow to create a new catalog item from the meeting type/template editor and add it directly to that template.
```

- [ ] **Step 6: Run navigation tests**

Run:

```bash
bin/rails test test/controllers/admin/dashboard_controller_test.rb test/integration/primary_nav_test.rb
```

Expected: pass.

- [ ] **Step 7: Commit**

```bash
git add app/views/admin/dashboard/show.html.erb app/views/shared/_primary_nav.html.erb docs/ROADMAP.md test/controllers/admin/dashboard_controller_test.rb test/integration/primary_nav_test.rb
git commit -m "feat: surface meeting type templates"
```

---

### Task 7: Full verification and polish

**Files:**
- Review changed files from Tasks 1-6.

- [ ] **Step 1: Run focused tests**

Run:

```bash
bin/rails test test/models/meeting_type_test.rb test/models/meeting_type_agenda_item_test.rb test/services/meeting_type_template_seeder_test.rb test/controllers/admin/meeting_types_controller_test.rb test/controllers/admin/meeting_type_agenda_items_controller_test.rb test/controllers/admin/dashboard_controller_test.rb test/integration/primary_nav_test.rb
```

Expected: pass.

- [ ] **Step 2: Run full test suite**

Run:

```bash
bin/rails test
```

Expected: pass.

- [ ] **Step 3: Run static checks**

Run:

```bash
bin/rubocop
bin/brakeman
bin/bundler-audit
```

Expected: all pass. If a check reports existing unrelated warnings, record the exact output before deciding whether to fix or defer.

- [ ] **Step 4: Browser smoke test when practical**

Start the Rails server bound for off-box access:

```bash
bin/rails server -b 0.0.0.0
```

In the browser, verify:

1. Sign in as a user with `manage_agendas`.
2. Open Meeting Types from navigation.
3. Confirm PEC Meeting and Membership Meeting are seeded.
4. Create a new meeting type.
5. Add an existing active catalog item.
6. Edit that template item's wording.
7. Confirm the source catalog item did not change.
8. Move the item up/down when there are at least two items.
9. Remove the item and confirm the catalog entry remains.

- [ ] **Step 5: Inspect git diff**

Run:

```bash
git status --short
git diff --stat
git diff
```

Expected: only intended files changed; no secrets, generated logs, or `.superpowers/` files staged.

- [ ] **Step 6: Final commit if verification changes were needed**

If Task 7 required fixes, inspect `git status --short`, stage only the files changed by those fixes, and commit them:

```bash
git commit -m "fix: polish meeting type templates"
```

If no fixes were needed, do not create an empty commit.

---

## Plan Self-Review

- Spec coverage: Tasks 1-2 cover the data model; Task 3 covers seeded PEC/Membership defaults and idempotency; Tasks 4-5 cover admin CRUD, picker, template-specific overrides, duplicate prevention, ordering, and removal; Task 6 covers navigation and roadmap; Task 7 covers verification.
- Scope check: The plan intentionally excludes inline creation of new catalog items from the meeting type editor and keeps that as a roadmap item.
- Type consistency: The plan consistently uses `MeetingType`, `MeetingTypeAgendaItem`, `meeting_types`, `meeting_type_agenda_items`, `manage_agendas`, and Action Text `body`.
