# Agenda Item Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an organization-owned, admin-managed Agenda Item Catalog seeded with a lean regular-meeting American Legion baseline.

**Architecture:** Add one Rails domain model, `AgendaItemCatalogEntry`, with Action Text body content and enum-like category/behavior values. Seed each organization with local editable copies through a small idempotent service. Expose management under the admin namespace using existing Rails controller/view patterns and the `manage_agendas` capability.

**Tech Stack:** Rails 8.1, PostgreSQL, Minitest, Action Text, Hotwire/Turbo, Tailwind CSS, importmap.

---

## File Structure

- Create `db/migrate/20260713010000_create_agenda_item_catalog_entries.rb`
  - Defines the organization-scoped catalog table, indexes, and constraints.
- Create `app/models/agenda_item_catalog_entry.rb`
  - Owns validations, category/behavior constants, slug normalization, Action Text body.
- Create `test/models/agenda_item_catalog_entry_test.rb`
  - Tests organization scoping, validations, constants, slug behavior, and rich text.
- Create `app/services/agenda_item_catalog_seeder.rb`
  - Idempotently creates local editable catalog entries for one organization without overwriting local edits.
- Create `test/services/agenda_item_catalog_seeder_test.rb`
  - Tests baseline entry count, metadata, full body text, and no-overwrite behavior.
- Modify `app/models/organization.rb`
  - Adds `has_many :agenda_item_catalog_entries`.
- Create `app/controllers/admin/agenda_item_catalog_entries_controller.rb`
  - Provides index/new/create/edit/update plus activate/deactivate updates.
- Create `test/controllers/admin/agenda_item_catalog_entries_controller_test.rb`
  - Tests permission protection, listing, create, update, deactivate/reactivate, and organization scoping.
- Modify `config/routes.rb`
  - Adds admin catalog routes.
- Create `app/views/admin/agenda_item_catalog_entries/index.html.erb`
  - Catalog management table grouped by category.
- Create `app/views/admin/agenda_item_catalog_entries/new.html.erb`
  - New local catalog entry page.
- Create `app/views/admin/agenda_item_catalog_entries/edit.html.erb`
  - Edit page with seeded-local-copy notice.
- Create `app/views/admin/agenda_item_catalog_entries/_form.html.erb`
  - Shared catalog form with Action Text editor.
- Modify `app/views/admin/dashboard/show.html.erb`
  - Adds a link/card to the Agenda Item Catalog admin page.
- Modify `docs/ROADMAP.md`
  - Marks the catalog foundation as in progress/completed only after implementation is verified.

## Task 1: Model and Migration

**Files:**
- Create: `db/migrate/20260713010000_create_agenda_item_catalog_entries.rb`
- Create: `app/models/agenda_item_catalog_entry.rb`
- Create: `test/models/agenda_item_catalog_entry_test.rb`
- Modify: `app/models/organization.rb`

- [ ] **Step 1: Write the failing model test**

Create `test/models/agenda_item_catalog_entry_test.rb`:

```ruby
require "test_helper"

class AgendaItemCatalogEntryTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
  end

  test "validates category and behavior type" do
    entry = @organization.agenda_item_catalog_entries.new(
      title: "Opening Ceremony",
      slug: "opening-ceremony",
      category: "not_a_category",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true
    )

    assert_not entry.valid?
    assert_includes entry.errors[:category], "is not included in the list"
  end

  test "normalizes slug and enforces organization scoped uniqueness" do
    @organization.agenda_item_catalog_entries.create!(
      title: "Opening Ceremony",
      slug: " Opening-Ceremony ",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true
    )

    duplicate = @organization.agenda_item_catalog_entries.new(
      title: "Opening Ceremony Copy",
      slug: "opening-ceremony",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 2,
      active: true
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "same slug can be reused by a different organization" do
    other_organization = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")

    @organization.agenda_item_catalog_entries.create!(
      title: "Opening Ceremony",
      slug: "opening-ceremony",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true
    )

    entry = other_organization.agenda_item_catalog_entries.new(
      title: "Opening Ceremony",
      slug: "opening-ceremony",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      position: 1,
      active: true
    )

    assert entry.valid?
  end

  test "supports rich text body" do
    entry = @organization.agenda_item_catalog_entries.create!(
      title: "Preamble",
      slug: "preamble",
      category: "ceremony",
      behavior_type: "reading_recitation",
      position: 1,
      active: true,
      body: "For God and Country"
    )

    assert_includes entry.body.to_plain_text, "For God and Country"
  end
end
```

- [ ] **Step 2: Run the model test to verify it fails**

Run:

```bash
bin/rails test test/models/agenda_item_catalog_entry_test.rb
```

Expected: FAIL with `uninitialized constant AgendaItemCatalogEntry` or missing association/table errors.

- [ ] **Step 3: Add the migration**

Create `db/migrate/20260713010000_create_agenda_item_catalog_entries.rb`:

```ruby
class CreateAgendaItemCatalogEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :agenda_item_catalog_entries do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.text :summary, null: false, default: ""
      t.string :category, null: false
      t.string :behavior_type, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.string :source_key
      t.string :source_label
      t.datetime :seeded_at

      t.timestamps
    end

    add_index :agenda_item_catalog_entries, [ :organization_id, :slug ], unique: true
    add_index :agenda_item_catalog_entries, [ :organization_id, :source_key ], unique: true, where: "source_key IS NOT NULL"
    add_index :agenda_item_catalog_entries, [ :organization_id, :category, :position ], name: "idx_agenda_catalog_on_org_category_position"
  end
end
```

- [ ] **Step 4: Add the model and organization association**

Create `app/models/agenda_item_catalog_entry.rb`:

```ruby
class AgendaItemCatalogEntry < ApplicationRecord
  CATEGORIES = {
    "ceremony" => "Ceremony",
    "business" => "Business",
    "reports" => "Reports",
    "membership" => "Membership",
    "memorial" => "Memorial",
    "administration" => "Administration"
  }.freeze

  BEHAVIOR_TYPES = {
    "scripted_ceremony" => "Scripted ceremony",
    "section_heading" => "Section heading",
    "report_slot" => "Report slot",
    "business_item" => "Business item",
    "motion_vote_item" => "Motion/vote item",
    "reading_recitation" => "Reading/recitation"
  }.freeze

  belongs_to :organization
  has_rich_text :body

  normalizes :slug, with: ->(value) { value.to_s.strip.downcase }

  validates :title, :slug, :category, :behavior_type, presence: true
  validates :summary, presence: true, allow_blank: true
  validates :category, inclusion: { in: CATEGORIES.keys }
  validates :behavior_type, inclusion: { in: BEHAVIOR_TYPES.keys }
  validates :slug, uniqueness: { scope: :organization_id }
  validates :source_key, uniqueness: { scope: :organization_id }, allow_blank: true
  validates :position, numericality: { only_integer: true }

  scope :ordered, -> { order(:category, :position, :title) }
  scope :active, -> { where(active: true) }

  def category_label
    CATEGORIES.fetch(category)
  end

  def behavior_type_label
    BEHAVIOR_TYPES.fetch(behavior_type)
  end

  def seeded?
    source_key.present?
  end
end
```

Modify `app/models/organization.rb`:

```ruby
class Organization < ApplicationRecord
  has_many :position_titles, dependent: :destroy
  has_many :meeting_bodies, dependent: :destroy
  has_many :agenda_item_catalog_entries, dependent: :destroy

  validates :name, :unit_type, :timezone, presence: true
end
```

- [ ] **Step 5: Run migration and model test**

Run:

```bash
bin/rails db:migrate
bin/rails test test/models/agenda_item_catalog_entry_test.rb
```

Expected: PASS for `AgendaItemCatalogEntryTest`.

- [ ] **Step 6: Commit**

```bash
git add db/migrate/20260713010000_create_agenda_item_catalog_entries.rb db/schema.rb app/models/agenda_item_catalog_entry.rb app/models/organization.rb test/models/agenda_item_catalog_entry_test.rb
git commit -m "feat: add agenda item catalog model"
```

## Task 2: Idempotent Baseline Seeder

**Files:**
- Create: `app/services/agenda_item_catalog_seeder.rb`
- Create: `test/services/agenda_item_catalog_seeder_test.rb`

- [ ] **Step 1: Write the failing seeder test**

Create `test/services/agenda_item_catalog_seeder_test.rb`:

```ruby
require "test_helper"

class AgendaItemCatalogSeederTest < ActiveSupport::TestCase
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
  end

  test "creates the lean regular meeting baseline" do
    assert_difference -> { @organization.agenda_item_catalog_entries.count }, 17 do
      AgendaItemCatalogSeeder.seed_for!(@organization)
    end

    titles = @organization.agenda_item_catalog_entries.order(:position).pluck(:title)
    assert_includes titles, "Opening Ceremony"
    assert_includes titles, "POW/MIA Empty Chair"
    assert_includes titles, "Unfinished / Old Business"
    assert_includes titles, "Good of The American Legion"
  end

  test "stores full script text for ceremony entries" do
    AgendaItemCatalogSeeder.seed_for!(@organization)

    preamble = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.preamble")
    assert_equal "ceremony", preamble.category
    assert_equal "reading_recitation", preamble.behavior_type
    assert_includes preamble.body.to_plain_text, "For God and Country"
    assert_includes preamble.body.to_plain_text, "mutual helpfulness"
  end

  test "does not overwrite local edits when run again" do
    AgendaItemCatalogSeeder.seed_for!(@organization)
    entry = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.opening_prayer")
    entry.update!(title: "Local Opening Prayer", body: "Locally edited prayer text")

    AgendaItemCatalogSeeder.seed_for!(@organization)

    entry.reload
    assert_equal "Local Opening Prayer", entry.title
    assert_equal "Locally edited prayer text", entry.body.to_plain_text.strip
  end

  test "can seed a second organization independently" do
    AgendaItemCatalogSeeder.seed_for!(@organization)
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")

    assert_difference -> { AgendaItemCatalogEntry.count }, 17 do
      AgendaItemCatalogSeeder.seed_for!(other)
    end
  end
end
```

- [ ] **Step 2: Run the seeder test to verify it fails**

Run:

```bash
bin/rails test test/services/agenda_item_catalog_seeder_test.rb
```

Expected: FAIL with `uninitialized constant AgendaItemCatalogSeeder`.

- [ ] **Step 3: Implement the seeder**

Create `app/services/agenda_item_catalog_seeder.rb`:

```ruby
class AgendaItemCatalogSeeder
  SOURCE_LABEL = "Officer's Guide regular meeting seed"

  ENTRIES = [
    {
      source_key: "regular_meeting.opening_ceremony",
      title: "Opening Ceremony",
      slug: "opening-ceremony",
      summary: "Begins the regular meeting with colors, prayer, POW/MIA recognition, pledge, and preamble.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "The commander announces that the meeting is about to open. Officers take their stations. The sergeant-at-arms closes the doors of the meeting hall. The commander gives three raps of the gavel and all present stand at attention. The color bearers advance the colors. The commander commands: Hand salute. After the colors are posted, the commander commands: Two. The chaplain offers prayer. The meeting continues with the POW/MIA Empty Chair ceremony, Pledge of Allegiance, and American Legion Preamble."
    },
    {
      source_key: "regular_meeting.opening_prayer",
      title: "Opening Prayer",
      slug: "opening-prayer",
      summary: "Suggested nonsectarian opening prayer from the regular meeting ceremony.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "Almighty God, Father of all mankind and Judge over nations, we pray Thee to guide our work in this meeting and in all our days. Send Thy peace to our nation and to all nations. Hasten the fulfillment of Thy promise of peace that shall have no end.\n\nWe pray for those who serve the people and guard the public welfare, that by Thy blessing they may be enabled to discharge their duties honestly and well. We pray that by Thy help they may observe the strictest justice, keep alight the fires of freedom, strive earnestly for the spirit of democracy, and preserve untarnished our loyalty to our country and to Thee. Finally, O God of mercy, we ask Thy blessing and comfort for those who are suffering mental and physical disability. Cheer them and bring them the blessings of health and happiness. Amen."
    },
    {
      source_key: "regular_meeting.pow_mia_empty_chair",
      title: "POW/MIA Empty Chair",
      slug: "pow-mia-empty-chair",
      summary: "Recognition of American POW/MIAs still unaccounted for.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "A POW/MIA empty chair is placed at all official meetings of The American Legion as a physical symbol of many American POW/MIAs still unaccounted for from all wars and conflicts involving the United States of America. This is a reminder for all of us to spare no effort to secure the release of any American prisoners from captivity, the repatriation of the remains of those who died bravely in defense of liberty, and a full accounting of those missing. Let us rededicate ourselves to this vital endeavor!\n\nPlace the POW/MIA flag on the empty chair."
    },
    {
      source_key: "regular_meeting.pledge_of_allegiance",
      title: "Pledge of Allegiance",
      slug: "pledge-of-allegiance",
      summary: "The Pledge of Allegiance recited during the opening ceremony.",
      category: "ceremony",
      behavior_type: "reading_recitation",
      body: "I pledge allegiance to the Flag of the United States of America and to the Republic for which it stands, one Nation under God, indivisible, with liberty and justice for all."
    },
    {
      source_key: "regular_meeting.preamble",
      title: "American Legion Preamble",
      slug: "american-legion-preamble",
      summary: "The Preamble to the Constitution of The American Legion.",
      category: "ceremony",
      behavior_type: "reading_recitation",
      body: "For God and Country, we associate ourselves together for the following purposes:\n\nTo uphold and defend the Constitution of the United States of America;\nTo maintain law and order;\nTo foster and perpetuate a one hundred percent Americanism;\nTo preserve the memories and incidents of our associations in all wars;\nTo inculcate a sense of individual obligation to the community, state and nation;\nTo combat the autocracy of both the classes and the masses;\nTo make right the master of might;\nTo promote peace and goodwill on earth;\nTo safeguard and transmit to posterity the principles of justice, freedom and democracy;\nTo consecrate and sanctify our comradeship by our devotion to mutual helpfulness."
    },
    {
      source_key: "regular_meeting.closing_ceremony",
      title: "Closing Ceremony",
      slug: "closing-ceremony",
      summary: "Closes the regular meeting with memorial service, POW/MIA flag recovery, colors, and adjournment.",
      category: "ceremony",
      behavior_type: "scripted_ceremony",
      body: "The commander asks: Is there any further business to come before the meeting? If not, the chaplain will lead us in memorial service.\n\nThe membership rises, uncovers, and stands in silence. The chaplain offers the memorial prayer. The commander directs the sergeant-at-arms to recover the POW/MIA flag. The commander reminds members that service to community, state, and nation is a main objective of The American Legion. The color bearers retire the flag of our country. The commander declares the meeting adjourned with one rap of the gavel."
    },
    { source_key: "regular_meeting.roll_call_quorum", title: "Roll Call and Quorum", slug: "roll-call-and-quorum", summary: "Determine whether enough members are present to conduct authorized business.", category: "administration", behavior_type: "business_item", body: "Roll call to determine if a quorum is present before conducting official business." },
    { source_key: "regular_meeting.previous_minutes", title: "Previous Meeting Minutes", slug: "previous-meeting-minutes", summary: "Read, correct, and approve the previous meeting minutes.", category: "administration", behavior_type: "motion_vote_item", body: "The adjutant reads the minutes of the previous meeting. The chair asks for corrections. If there are no corrections, the minutes stand approved as read; if corrected, they stand approved as corrected." },
    { source_key: "regular_meeting.introductions", title: "Introduction of Guests and Prospective/New Members", slug: "introduction-of-guests-and-prospective-new-members", summary: "Welcome guests, prospective members, and new members.", category: "membership", behavior_type: "business_item", body: "Introduce guests, prospective members, and new members so they are recognized and welcomed by the post." },
    { source_key: "regular_meeting.committee_reports", title: "Committee Reports", slug: "committee-reports", summary: "Reports from standing or special committees scheduled to report.", category: "reports", behavior_type: "section_heading", body: "The agenda should list committees scheduled to report. Confirm that a chairperson is ready before placing the report on the agenda." },
    { source_key: "regular_meeting.balloting_on_applications", title: "Balloting on Applications", slug: "balloting-on-applications", summary: "Act on membership applications when required by post procedure.", category: "membership", behavior_type: "motion_vote_item", body: "Ballot on applications for membership according to the post constitution, by-laws, and applicable American Legion procedures." },
    { source_key: "regular_meeting.sick_call_relief_employment", title: "Sick Call, Relief, and Employment", slug: "sick-call-relief-and-employment", summary: "Share member welfare, relief, employment, or assistance needs.", category: "business", behavior_type: "business_item", body: "Use this time for sick call, relief, employment, and other member welfare matters appropriate for the meeting." },
    { source_key: "regular_meeting.service_officer_report", title: "Post Service Officer Report", slug: "post-service-officer-report", summary: "Standard report from the post service officer.", category: "reports", behavior_type: "report_slot", body: "The post service officer reports on veteran service matters, benefits awareness, claims support, and related assistance." },
    { source_key: "regular_meeting.unfinished_old_business", title: "Unfinished / Old Business", slug: "unfinished-old-business", summary: "Business carried over from earlier meetings.", category: "business", behavior_type: "section_heading", body: "Bring forward business postponed from previous meetings or matters introduced earlier where action was not completed." },
    { source_key: "regular_meeting.new_business_correspondence", title: "New Business and Correspondence", slug: "new-business-and-correspondence", summary: "New business, correspondence, and motions for post action.", category: "business", behavior_type: "section_heading", body: "Introduce new business, communications, correspondence, and motions calling for action by the post." },
    { source_key: "regular_meeting.memorial_departed_member", title: "Memorial to a Departed Post Member", slug: "memorial-to-a-departed-post-member", summary: "Memorial recognition for a departed post member when needed.", category: "memorial", behavior_type: "scripted_ceremony", body: "Use this item when the post needs to recognize a departed member during the regular meeting. The post may use an appropriate memorial, charter-draping, or Post Everlasting ceremony when applicable." },
    { source_key: "regular_meeting.good_of_legion", title: "Good of The American Legion", slug: "good-of-the-american-legion", summary: "Suggestions and remarks for the good of The American Legion.", category: "business", behavior_type: "business_item", body: "Members may make suggestions of any kind, character, or description, save religion or partisan politics." }
  ].freeze

  def self.seed_for!(organization)
    new(organization).seed!
  end

  def initialize(organization)
    @organization = organization
  end

  def seed!
    ENTRIES.each_with_index do |entry_attributes, index|
      next if @organization.agenda_item_catalog_entries.exists?(source_key: entry_attributes.fetch(:source_key))

      @organization.agenda_item_catalog_entries.create!(
        entry_attributes.except(:body).merge(
          position: index + 1,
          active: true,
          source_label: SOURCE_LABEL,
          seeded_at: Time.current,
          body: entry_attributes.fetch(:body)
        )
      )
    end
  end
end
```

- [ ] **Step 4: Run the seeder test**

Run:

```bash
bin/rails test test/services/agenda_item_catalog_seeder_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/agenda_item_catalog_seeder.rb test/services/agenda_item_catalog_seeder_test.rb
git commit -m "feat: seed agenda item catalog baseline"
```

## Task 3: Admin Controller and Routes

**Files:**
- Create: `app/controllers/admin/agenda_item_catalog_entries_controller.rb`
- Create: `test/controllers/admin/agenda_item_catalog_entries_controller_test.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write the failing controller test**

Create `test/controllers/admin/agenda_item_catalog_entries_controller_test.rb`:

```ruby
require "test_helper"

class Admin::AgendaItemCatalogEntriesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  test "index requires manage agendas permission" do
    user = create_user_with_capability("view_internal_records")
    sign_in_as(user)

    get admin_agenda_item_catalog_entries_path

    assert_redirected_to root_path
  end

  test "index seeds and lists catalog entries for agenda managers" do
    user = create_user_with_capability("manage_agendas")
    sign_in_as(user)

    assert_difference -> { @organization.agenda_item_catalog_entries.count }, 17 do
      get admin_agenda_item_catalog_entries_path
    end

    assert_response :success
    assert_select "h1", /Agenda Item Catalog/
    assert_select "td", text: "Opening Ceremony"
  end

  test "create adds local catalog entry" do
    user = create_user_with_capability("manage_agendas")
    sign_in_as(user)

    assert_difference -> { @organization.agenda_item_catalog_entries.count }, 1 do
      post admin_agenda_item_catalog_entries_path, params: {
        agenda_item_catalog_entry: {
          title: "Finance Officer Report",
          slug: "finance-officer-report",
          summary: "Monthly finance report.",
          category: "reports",
          behavior_type: "report_slot",
          position: 50,
          active: "1",
          body: "Report on balances, income, expenses, and bills."
        }
      }
    end

    assert_redirected_to admin_agenda_item_catalog_entries_path
    assert_equal "Finance Officer Report", @organization.agenda_item_catalog_entries.last.title
  end

  test "update edits local copy including rich text body" do
    user = create_user_with_capability("manage_agendas")
    sign_in_as(user)
    AgendaItemCatalogSeeder.seed_for!(@organization)
    entry = @organization.agenda_item_catalog_entries.find_by!(source_key: "regular_meeting.opening_prayer")

    patch admin_agenda_item_catalog_entry_path(entry), params: {
      agenda_item_catalog_entry: {
        title: "Local Prayer",
        summary: "Local wording.",
        category: "ceremony",
        behavior_type: "scripted_ceremony",
        active: "1",
        body: "Local body text"
      }
    }

    assert_redirected_to admin_agenda_item_catalog_entries_path
    entry.reload
    assert_equal "Local Prayer", entry.title
    assert_equal "Local body text", entry.body.to_plain_text.strip
  end

  test "update can deactivate an entry" do
    user = create_user_with_capability("manage_agendas")
    sign_in_as(user)
    entry = @organization.agenda_item_catalog_entries.create!(title: "Test", slug: "test", category: "business", behavior_type: "business_item", active: true)

    patch admin_agenda_item_catalog_entry_path(entry), params: { agenda_item_catalog_entry: { active: "0" } }

    assert_redirected_to admin_agenda_item_catalog_entries_path
    assert_not entry.reload.active
  end

  test "cannot edit another organization catalog entry" do
    user = create_user_with_capability("manage_agendas")
    sign_in_as(user)
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    entry = other.agenda_item_catalog_entries.create!(title: "Other", slug: "other", category: "business", behavior_type: "business_item")

    patch admin_agenda_item_catalog_entry_path(entry), params: { agenda_item_catalog_entry: { title: "Changed" } }

    assert_response :not_found
  end

  private

  def create_user_with_capability(capability)
    person = Person.create!(first_name: "Jane", last_name: SecureRandom.hex(4))
    user = User.create!(person: person, email_address: "#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: capability)
    user
  end
end
```

- [ ] **Step 2: Run the controller test to verify it fails**

Run:

```bash
bin/rails test test/controllers/admin/agenda_item_catalog_entries_controller_test.rb
```

Expected: FAIL with missing route/controller errors.

- [ ] **Step 3: Add routes**

Modify `config/routes.rb` inside the `namespace :admin do` block:

```ruby
resources :agenda_item_catalog_entries, except: %i[show destroy]
```

- [ ] **Step 4: Add controller**

Create `app/controllers/admin/agenda_item_catalog_entries_controller.rb`:

```ruby
module Admin
  class AgendaItemCatalogEntriesController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_entry, only: %i[edit update]

    def index
      AgendaItemCatalogSeeder.seed_for!(@organization)
      @entries_by_category = @organization.agenda_item_catalog_entries.ordered.group_by(&:category)
    end

    def new
      @entry = @organization.agenda_item_catalog_entries.new(active: true, position: next_position)
    end

    def create
      @entry = @organization.agenda_item_catalog_entries.new(entry_params)

      if @entry.save
        redirect_to admin_agenda_item_catalog_entries_path, notice: "Agenda catalog item added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @entry.update(entry_params)
        redirect_to admin_agenda_item_catalog_entries_path, notice: "Agenda catalog item updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_entry
      @entry = @organization.agenda_item_catalog_entries.find(params[:id])
    end

    def next_position
      @organization.agenda_item_catalog_entries.maximum(:position).to_i + 1
    end

    def entry_params
      params.require(:agenda_item_catalog_entry).permit(:title, :slug, :summary, :category, :behavior_type, :position, :active, :body)
    end
  end
end
```

- [ ] **Step 5: Run the controller test**

Run:

```bash
bin/rails test test/controllers/admin/agenda_item_catalog_entries_controller_test.rb
```

Expected: It may still fail because views are missing. If missing templates are the only failure, continue to Task 4 before committing. If controller assertions fail for permissions/scoping, fix them before Task 4.

## Task 4: Admin Views and Navigation

**Files:**
- Create: `app/views/admin/agenda_item_catalog_entries/index.html.erb`
- Create: `app/views/admin/agenda_item_catalog_entries/new.html.erb`
- Create: `app/views/admin/agenda_item_catalog_entries/edit.html.erb`
- Create: `app/views/admin/agenda_item_catalog_entries/_form.html.erb`
- Modify: `app/views/admin/dashboard/show.html.erb`
- Test: `test/controllers/admin/agenda_item_catalog_entries_controller_test.rb`
- Test: `test/controllers/admin/dashboard_controller_test.rb`

- [ ] **Step 1: Add dashboard link assertion**

Modify `test/controllers/admin/dashboard_controller_test.rb` by adding this test:

```ruby
test "admin dashboard links to agenda item catalog" do
  prepare_setup_complete_state
  sign_in_admin

  get admin_root_path

  assert_response :success
  assert_select "a[href='#{admin_agenda_item_catalog_entries_path}']", text: /Agenda Item Catalog/
end
```

- [ ] **Step 2: Run dashboard test to verify it fails**

Run:

```bash
bin/rails test test/controllers/admin/dashboard_controller_test.rb
```

Expected: FAIL because the link is not present yet.

- [ ] **Step 3: Add shared form partial**

Create `app/views/admin/agenda_item_catalog_entries/_form.html.erb`:

```erb
<%= form_with model: [ :admin, entry ], class: "space-y-6" do |form| %>
  <% if entry.errors.any? %>
    <div class="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
      <p class="font-semibold">Please fix the following:</p>
      <ul class="mt-2 list-disc pl-5">
        <% entry.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <% if entry.seeded? %>
    <div class="rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">
      This changes your post's local copy only. It will not affect the original seed.
    </div>
  <% end %>

  <div class="grid gap-4 md:grid-cols-2">
    <div>
      <%= form.label :title, class: "block text-sm font-semibold text-slate-900" %>
      <%= form.text_field :title, class: "mt-1 w-full rounded-lg border border-slate-300 px-3 py-2" %>
    </div>

    <div>
      <%= form.label :slug, class: "block text-sm font-semibold text-slate-900" %>
      <%= form.text_field :slug, class: "mt-1 w-full rounded-lg border border-slate-300 px-3 py-2" %>
    </div>

    <div>
      <%= form.label :category, class: "block text-sm font-semibold text-slate-900" %>
      <%= form.select :category, AgendaItemCatalogEntry::CATEGORIES.map { |value, label| [ label, value ] }, {}, class: "mt-1 w-full rounded-lg border border-slate-300 px-3 py-2" %>
    </div>

    <div>
      <%= form.label :behavior_type, class: "block text-sm font-semibold text-slate-900" %>
      <%= form.select :behavior_type, AgendaItemCatalogEntry::BEHAVIOR_TYPES.map { |value, label| [ label, value ] }, {}, class: "mt-1 w-full rounded-lg border border-slate-300 px-3 py-2" %>
    </div>

    <div>
      <%= form.label :position, class: "block text-sm font-semibold text-slate-900" %>
      <%= form.number_field :position, class: "mt-1 w-full rounded-lg border border-slate-300 px-3 py-2" %>
    </div>

    <label class="flex items-center gap-2 self-end text-sm font-semibold text-slate-900">
      <%= form.check_box :active, class: "rounded border-slate-300" %>
      Active
    </label>
  </div>

  <div>
    <%= form.label :summary, "Short guidance", class: "block text-sm font-semibold text-slate-900" %>
    <%= form.text_area :summary, rows: 3, class: "mt-1 w-full rounded-lg border border-slate-300 px-3 py-2" %>
  </div>

  <div>
    <%= form.label :body, "Full text or script", class: "block text-sm font-semibold text-slate-900" %>
    <div class="mt-1 rounded-lg border border-slate-300 bg-white">
      <%= form.rich_text_area :body %>
    </div>
  </div>

  <div class="flex gap-3">
    <%= form.submit "Save catalog item", class: "rounded-lg bg-blue-900 px-4 py-2 text-sm font-semibold text-white" %>
    <%= link_to "Cancel", admin_agenda_item_catalog_entries_path, class: "rounded-lg border border-slate-300 px-4 py-2 text-sm font-semibold text-slate-700" %>
  </div>
<% end %>
```

- [ ] **Step 4: Add index/new/edit views**

Create `app/views/admin/agenda_item_catalog_entries/index.html.erb`:

```erb
<div class="space-y-8">
  <div class="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
    <div>
      <p class="text-sm font-semibold uppercase tracking-wide text-blue-900">Admin</p>
      <h1 class="text-3xl font-bold text-slate-950">Agenda Item Catalog</h1>
      <p class="mt-2 max-w-3xl text-slate-700">These are the standard building blocks your post can use when creating meeting templates later.</p>
    </div>
    <%= link_to "Add catalog item", new_admin_agenda_item_catalog_entry_path, class: "rounded-lg bg-blue-900 px-4 py-2 text-sm font-semibold text-white" %>
  </div>

  <% AgendaItemCatalogEntry::CATEGORIES.each do |category, label| %>
    <% entries = @entries_by_category.fetch(category, []) %>
    <% next if entries.empty? %>

    <section class="rounded-2xl border border-slate-200 bg-white shadow-sm">
      <div class="border-b border-slate-200 px-5 py-4">
        <h2 class="text-xl font-semibold text-slate-950"><%= label %></h2>
      </div>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50 text-left text-xs font-semibold uppercase tracking-wide text-slate-600">
            <tr>
              <th class="px-5 py-3">Title</th>
              <th class="px-5 py-3">Behavior</th>
              <th class="px-5 py-3">Status</th>
              <th class="px-5 py-3">Source</th>
              <th class="px-5 py-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <% entries.each do |entry| %>
              <tr>
                <td class="px-5 py-4 font-medium text-slate-950"><%= entry.title %></td>
                <td class="px-5 py-4 text-slate-700"><%= entry.behavior_type_label %></td>
                <td class="px-5 py-4"><%= entry.active? ? "Active" : "Inactive" %></td>
                <td class="px-5 py-4 text-slate-600"><%= entry.source_label.presence || "Local" %></td>
                <td class="px-5 py-4 text-right"><%= link_to "Edit", edit_admin_agenda_item_catalog_entry_path(entry), class: "font-semibold text-blue-900" %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </section>
  <% end %>
</div>
```

Create `app/views/admin/agenda_item_catalog_entries/new.html.erb`:

```erb
<div class="mx-auto max-w-4xl space-y-6">
  <div>
    <p class="text-sm font-semibold uppercase tracking-wide text-blue-900">Agenda Item Catalog</p>
    <h1 class="text-3xl font-bold text-slate-950">Add catalog item</h1>
  </div>

  <%= render "form", entry: @entry %>
</div>
```

Create `app/views/admin/agenda_item_catalog_entries/edit.html.erb`:

```erb
<div class="mx-auto max-w-4xl space-y-6">
  <div>
    <p class="text-sm font-semibold uppercase tracking-wide text-blue-900">Agenda Item Catalog</p>
    <h1 class="text-3xl font-bold text-slate-950">Edit <%= @entry.title %></h1>
  </div>

  <%= render "form", entry: @entry %>
</div>
```

- [ ] **Step 5: Add dashboard link**

Modify `app/views/admin/dashboard/show.html.erb`. Add a card or link near other admin tools:

```erb
<%= link_to admin_agenda_item_catalog_entries_path, class: "block rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition hover:border-blue-300 hover:shadow-md" do %>
  <p class="text-sm font-semibold uppercase tracking-wide text-blue-900">Meetings</p>
  <h2 class="mt-2 text-xl font-bold text-slate-950">Agenda Item Catalog</h2>
  <p class="mt-2 text-sm text-slate-700">Manage the standard ceremony, report, and business items your post can use in meeting templates later.</p>
<% end %>
```

Place it inside the existing admin dashboard layout without disturbing existing roster/positions/admin management sections.

- [ ] **Step 6: Run controller and dashboard tests**

Run:

```bash
bin/rails test test/controllers/admin/agenda_item_catalog_entries_controller_test.rb test/controllers/admin/dashboard_controller_test.rb
```

Expected: PASS.

- [ ] **Step 7: Commit controller and views together**

```bash
git add config/routes.rb app/controllers/admin/agenda_item_catalog_entries_controller.rb app/views/admin/agenda_item_catalog_entries app/views/admin/dashboard/show.html.erb test/controllers/admin/agenda_item_catalog_entries_controller_test.rb test/controllers/admin/dashboard_controller_test.rb
git commit -m "feat: manage agenda item catalog in admin"
```

## Task 5: Roadmap Update and Full Verification

**Files:**
- Modify: `docs/ROADMAP.md`

- [ ] **Step 1: Update roadmap after implementation**

Modify `docs/ROADMAP.md` under `## Immediate Next: Structured Agendas` so it distinguishes completed catalog foundation from remaining agenda work:

```markdown
Completed for Structured Agendas foundation:

- Organization-owned agenda item catalog with editable local copies.
- Lean regular-meeting baseline seeded from The American Legion Officer's Guide and Manual of Ceremonies.
- Admin management for catalog categories, behavior types, active status, and rich text/script bodies.

Still pending:

- Meeting type creator.
- Agenda templates.
- Agenda sections.
- Structured agenda items.
- Item-level rich notes.
- Reordering and moving agenda items.
- Browser/HTML printable agenda rendering for on-screen review and printing.
```

- [ ] **Step 2: Run focused tests**

Run:

```bash
bin/rails test test/models/agenda_item_catalog_entry_test.rb test/services/agenda_item_catalog_seeder_test.rb test/controllers/admin/agenda_item_catalog_entries_controller_test.rb test/controllers/admin/dashboard_controller_test.rb
```

Expected: PASS.

- [ ] **Step 3: Run full Rails test suite**

Run:

```bash
bin/rails test
```

Expected: PASS.

- [ ] **Step 4: Run lint/security checks**

Run:

```bash
bin/rubocop
bin/brakeman
bin/bundler-audit
```

Expected: all exit 0. If `bin/bundler-audit` needs advisory DB update, run the project-standard update command only if already established in the repo; otherwise report the exact failure.

- [ ] **Step 5: Commit roadmap update**

```bash
git add docs/ROADMAP.md
git commit -m "docs: update structured agendas roadmap"
```

## Self-Review Checklist

- Spec coverage: Tasks cover organization-scoped catalog records, category/behavior metadata, full rich text/script body, idempotent non-overwriting seed behavior, admin management, `manage_agendas` permission, and roadmap update.
- Intentional exclusions: meeting types, templates, actual agendas, ad hoc items, tracked annual topics, and minutes lifecycle are not implemented.
- No hard-coded Post 165 behavior: tests use generic organization names except existing project tests may keep historical Post 165 setup context.
- Type consistency: use `AgendaItemCatalogEntry`, `AgendaItemCatalogSeeder`, `category`, `behavior_type`, `source_key`, `source_label`, `seeded_at`, and `body` consistently.
