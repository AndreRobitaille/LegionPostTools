# Dated Agendas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build dated agendas so officers can create a real meeting agenda from a meeting type template, edit it, approve it, publish it, and let members view or print the published agenda.

**Architecture:** Add `DatedAgenda` and `DatedAgendaItem` as meeting-instance records copied from existing `MeetingType` templates. Keep admin/officer editing under the existing `manage_agendas` capability, expose a narrow read-only member view for published agendas, and use Rails optimistic locking plus simple lifecycle methods to prevent silent conflicts and accidental edits after approval/publication.

**Tech Stack:** Rails 8.1, PostgreSQL, Minitest, Action Text, Hotwire/Turbo server-rendered ERB, Tailwind CSS, existing passwordless authenticated app shell.

---

## File Structure

- Add `db/migrate/20260718001000_create_dated_agendas.rb`: create `dated_agendas` and `dated_agenda_items`, including `lock_version` columns and scoped indexes.
- Add `app/models/dated_agenda.rb`: organization/body/type associations, lifecycle enum helpers, copy-from-template behavior, lock checks, display helpers.
- Add `app/models/dated_agenda_item.rb`: agenda association, optional source references, Action Text body, ordering, copy helpers, same-organization validation.
- Modify `app/models/organization.rb`: add `has_many :dated_agendas`.
- Modify `app/models/meeting_body.rb`: add `has_many :dated_agendas`.
- Modify `app/models/meeting_type.rb`: add `has_many :dated_agendas`.
- Modify `app/models/agenda_item_catalog_entry.rb`: add `has_many :dated_agenda_items`.
- Modify `config/routes.rb`: add officer routes under `admin`, add authenticated read-only member routes, and add printable route.
- Add `app/controllers/admin/dated_agendas_controller.rb`: create/edit/update/approve/publish/reopen and officer printable view.
- Add `app/controllers/admin/dated_agenda_items_controller.rb`: edit/update/add-from-catalog/reorder/remove copied items.
- Add `app/controllers/dated_agendas_controller.rb`: member-facing published agenda index/show/print.
- Add `app/views/admin/dated_agendas/*`: officer index/new/edit/show/print views and form partials.
- Add `app/views/admin/dated_agenda_items/*`: edit form and catalog picker.
- Add `app/views/dated_agendas/*`: member index/show/print views.
- Add `test/models/dated_agenda_test.rb`: copying, independence, lifecycle, lock-state model behavior.
- Add `test/models/dated_agenda_item_test.rb`: copy helpers, org validation, Action Text copy.
- Add `test/controllers/admin/dated_agendas_controller_test.rb`: authorization, creation, editing, lifecycle, lock behavior.
- Add `test/controllers/admin/dated_agenda_items_controller_test.rb`: item editing, catalog add, move, remove, conflict handling.
- Add `test/controllers/dated_agendas_controller_test.rb`: member visibility and printable view.

---

### Task 1: Add dated agenda models and database schema

**Files:**
- Create: `db/migrate/20260718001000_create_dated_agendas.rb`
- Create: `app/models/dated_agenda.rb`
- Create: `app/models/dated_agenda_item.rb`
- Modify: `app/models/organization.rb`
- Modify: `app/models/meeting_body.rb`
- Modify: `app/models/meeting_type.rb`
- Modify: `app/models/agenda_item_catalog_entry.rb`
- Test: `test/models/dated_agenda_test.rb`
- Test: `test/models/dated_agenda_item_test.rb`

- [ ] **Step 1: Write model tests for template copying and independence**

Create `test/models/dated_agenda_test.rb`:

```ruby
require "test_helper"

class DatedAgendaTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", description: "Regular membership meeting")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @catalog_entry = @organization.agenda_item_catalog_entries.create!(title: "Opening Ceremony", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true, summary: "Open the meeting", body: "Opening words")
    @template_item = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "Opening", summary: "Template summary", active: true, body: "Template body")
  end

  test "create_from_template copies active template items into a dated agenda" do
    agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))

    assert_equal "Membership Meeting — August 4, 2026", agenda.title
    assert agenda.draft?
    assert_equal 1, agenda.dated_agenda_items.count

    item = agenda.dated_agenda_items.first
    assert_equal @template_item, item.meeting_type_agenda_item
    assert_equal @catalog_entry, item.agenda_item_catalog_entry
    assert_equal "Opening", item.title
    assert_equal "Template summary", item.summary
    assert_equal "scripted_ceremony", item.behavior_type
    assert_includes item.body.to_s, "Template body"
  end

  test "copied dated agenda items are independent from later template edits" do
    agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
    item = agenda.dated_agenda_items.first

    @template_item.update!(title: "Changed Template", summary: "Changed summary", body: "Changed body")

    assert_equal "Opening", item.reload.title
    assert_equal "Template summary", item.summary
    assert_includes item.body.to_s, "Template body"
  end

  test "editing a dated agenda item does not change the template item" do
    agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))

    agenda.dated_agenda_items.first.update!(title: "Meeting-specific Opening", body: "Meeting-specific body")

    assert_equal "Opening", @template_item.reload.title
    assert_includes @template_item.body.to_s, "Template body"
  end

  test "locked agendas reject ordinary item changes" do
    agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
    agenda.approve!(User.create!(person: Person.create!(first_name: "Pat", last_name: "Commander"), email_address: "pat@example.com", email_verified_at: Time.current))

    item = agenda.dated_agenda_items.first
    assert_not item.update(title: "Changed after approval")
    assert_includes item.errors.full_messages.join, "agenda is locked"
  end
end
```

Create `test/models/dated_agenda_item_test.rb`:

```ruby
require "test_helper"

class DatedAgendaItemTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership Meeting — August 4, 2026", status: "draft")
    @catalog_entry = @organization.agenda_item_catalog_entries.create!(title: "Reports", category: "reports", behavior_type: "report_slot", position: 1, active: true, body: "Report text")
  end

  test "catalog entry must belong to the same organization as the dated agenda" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_entry = other.agenda_item_catalog_entries.create!(title: "Other", category: "reports", behavior_type: "report_slot", position: 1, active: true)

    item = @agenda.dated_agenda_items.build(agenda_item_catalog_entry: other_entry, position: 1, title: "Other", behavior_type: "report_slot")

    assert_not item.valid?
    assert_includes item.errors[:agenda_item_catalog_entry], "must belong to the same organization"
  end

  test "create_from_catalog_entry copies rich text body" do
    item = DatedAgendaItem.create_from_catalog_entry!(@catalog_entry, position: 1, dated_agenda: @agenda)

    assert_equal "Reports", item.title
    assert_equal "report_slot", item.behavior_type
    assert_includes item.body.to_s, "Report text"
  end
end
```

- [ ] **Step 2: Run model tests to verify they fail**

Run:

```bash
bin/rails test test/models/dated_agenda_test.rb test/models/dated_agenda_item_test.rb
```

Expected: failures because `DatedAgenda` and `DatedAgendaItem` are not defined.

- [ ] **Step 3: Add the migration**

Create `db/migrate/20260718001000_create_dated_agendas.rb`:

```ruby
class CreateDatedAgendas < ActiveRecord::Migration[8.1]
  def change
    create_table :dated_agendas do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :meeting_body, null: false, foreign_key: true
      t.references :meeting_type, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.string :title, null: false
      t.string :status, null: false, default: "draft"
      t.references :approved_by, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.references :published_by, foreign_key: { to_table: :users }
      t.datetime :published_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :dated_agendas, [ :organization_id, :starts_at ]
    add_index :dated_agendas, [ :organization_id, :status ]

    create_table :dated_agenda_items do |t|
      t.references :dated_agenda, null: false, foreign_key: true
      t.references :meeting_type_agenda_item, foreign_key: true
      t.references :agenda_item_catalog_entry, foreign_key: true
      t.integer :position, null: false
      t.string :title, null: false
      t.text :summary, null: false, default: ""
      t.string :behavior_type, null: false
      t.boolean :active, null: false, default: true
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :dated_agenda_items, [ :dated_agenda_id, :position ], unique: true
  end
end
```

- [ ] **Step 4: Add model associations and behavior**

Create `app/models/dated_agenda.rb`:

```ruby
class DatedAgenda < ApplicationRecord
  STATUSES = %w[draft approved published].freeze

  belongs_to :organization
  belongs_to :meeting_body
  belongs_to :meeting_type
  belongs_to :approved_by, class_name: "User", optional: true
  belongs_to :published_by, class_name: "User", optional: true
  has_many :dated_agenda_items, dependent: :destroy

  validates :starts_at, :title, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :meeting_body_belongs_to_organization
  validate :meeting_type_belongs_to_organization

  scope :ordered, -> { order(starts_at: :desc, title: :asc) }
  scope :published, -> { where(status: "published") }
  scope :upcoming, -> { where("starts_at >= ?", Time.zone.today.beginning_of_day).order(:starts_at, :title) }

  def self.create_from_template!(organization:, meeting_body:, meeting_type:, starts_at:, title: nil)
    create!(organization: organization, meeting_body: meeting_body, meeting_type: meeting_type, starts_at: starts_at, title: title.presence || default_title(meeting_type, starts_at)).tap do |agenda|
      agenda.copy_template_items!
    end
  end

  def self.default_title(meeting_type, starts_at)
    "#{meeting_type.name} — #{starts_at.to_date.to_fs(:long)}"
  end

  def copy_template_items!
    meeting_type.with_lock do
      meeting_type.meeting_type_agenda_items.active.ordered.each_with_index do |template_item, index|
        dated_agenda_items.create!(DatedAgendaItem.attributes_from_template_item(template_item).merge(position: index + 1))
      end
    end
  end

  def draft?
    status == "draft"
  end

  def approved?
    status == "approved"
  end

  def published?
    status == "published"
  end

  def locked_for_editing?
    approved? || published?
  end

  def approve!(user)
    update!(status: "approved", approved_by: user, approved_at: Time.current, published_by: nil, published_at: nil)
  end

  def publish!(user)
    raise ActiveRecord::RecordInvalid.new(self) unless approved?

    update!(status: "published", published_by: user, published_at: Time.current)
  end

  def reopen!
    update!(status: "draft", approved_by: nil, approved_at: nil, published_by: nil, published_at: nil)
  end

  private

  def meeting_body_belongs_to_organization
    return if meeting_body.blank? || meeting_body.organization_id == organization_id

    errors.add(:meeting_body, "must belong to the same organization")
  end

  def meeting_type_belongs_to_organization
    return if meeting_type.blank? || meeting_type.organization_id == organization_id

    errors.add(:meeting_type, "must belong to the same organization")
  end
end
```

Create `app/models/dated_agenda_item.rb`:

```ruby
class DatedAgendaItem < ApplicationRecord
  belongs_to :dated_agenda
  belongs_to :meeting_type_agenda_item, optional: true
  belongs_to :agenda_item_catalog_entry, optional: true
  has_rich_text :body

  before_validation :normalize_optional_fields
  validate :agenda_is_editable, on: :update
  validate :catalog_entry_belongs_to_same_organization
  validate :template_item_belongs_to_same_meeting_type

  validates :title, :behavior_type, presence: true
  validates :position, numericality: { only_integer: true }
  validates :position, uniqueness: { scope: :dated_agenda_id }

  scope :ordered, -> { order(:position, :title) }
  scope :active, -> { where(active: true) }

  def self.attributes_from_template_item(template_item)
    {
      meeting_type_agenda_item: template_item,
      agenda_item_catalog_entry: template_item.agenda_item_catalog_entry,
      title: template_item.title,
      summary: template_item.summary,
      behavior_type: template_item.agenda_item_catalog_entry.behavior_type,
      active: true,
      body: template_item.body.to_s
    }
  end

  def self.create_from_catalog_entry!(catalog_entry, position:, dated_agenda: nil)
    attributes = {
      agenda_item_catalog_entry: catalog_entry,
      position: position,
      title: catalog_entry.title,
      summary: catalog_entry.summary,
      behavior_type: catalog_entry.behavior_type,
      active: true,
      body: catalog_entry.body.to_s
    }

    dated_agenda ? dated_agenda.dated_agenda_items.create!(attributes) : create!(attributes)
  end

  private

  def normalize_optional_fields
    self.summary = summary.to_s
  end

  def agenda_is_editable
    return if dated_agenda.blank? || dated_agenda.draft?

    errors.add(:base, "agenda is locked")
  end

  def catalog_entry_belongs_to_same_organization
    return if dated_agenda.blank? || agenda_item_catalog_entry.blank?
    return if dated_agenda.organization_id == agenda_item_catalog_entry.organization_id

    errors.add(:agenda_item_catalog_entry, "must belong to the same organization")
  end

  def template_item_belongs_to_same_meeting_type
    return if dated_agenda.blank? || meeting_type_agenda_item.blank?
    return if dated_agenda.meeting_type_id == meeting_type_agenda_item.meeting_type_id

    errors.add(:meeting_type_agenda_item, "must belong to the same meeting type")
  end
end
```

Modify `app/models/organization.rb` to include:

```ruby
has_many :dated_agendas, dependent: :destroy
```

Modify `app/models/meeting_body.rb` to include:

```ruby
has_many :dated_agendas, dependent: :restrict_with_exception
```

Modify `app/models/meeting_type.rb` to include:

```ruby
has_many :dated_agendas, dependent: :restrict_with_exception
```

Modify `app/models/agenda_item_catalog_entry.rb` to include:

```ruby
has_many :dated_agenda_items, dependent: :restrict_with_exception
```

- [ ] **Step 5: Run migrations and focused model tests**

Run:

```bash
bin/rails db:migrate
bin/rails test test/models/dated_agenda_test.rb test/models/dated_agenda_item_test.rb
```

Expected: all new model tests pass.

- [ ] **Step 6: Commit model foundation**

Run:

```bash
git add db/migrate/20260718001000_create_dated_agendas.rb app/models/dated_agenda.rb app/models/dated_agenda_item.rb app/models/organization.rb app/models/meeting_body.rb app/models/meeting_type.rb app/models/agenda_item_catalog_entry.rb test/models/dated_agenda_test.rb test/models/dated_agenda_item_test.rb db/schema.rb
git commit -m "feat: add dated agenda model foundation"
```

---

### Task 2: Add officer create/edit routes and controller shell

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/admin/dated_agendas_controller.rb`
- Create: `app/views/admin/dated_agendas/index.html.erb`
- Create: `app/views/admin/dated_agendas/new.html.erb`
- Create: `app/views/admin/dated_agendas/edit.html.erb`
- Create: `app/views/admin/dated_agendas/_form.html.erb`
- Test: `test/controllers/admin/dated_agendas_controller_test.rb`

- [ ] **Step 1: Write controller tests for authorization and create-from-template**

Create `test/controllers/admin/dated_agendas_controller_test.rb`:

```ruby
require "test_helper"

class Admin::DatedAgendasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @catalog_entry = @organization.agenda_item_catalog_entries.create!(title: "Opening Ceremony", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true, body: "Opening words")
    @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "Opening", active: true, body: "Template body")
  end

  test "signed out users are redirected" do
    get admin_dated_agendas_path

    assert_redirected_to new_session_path
  end

  test "users without manage_agendas are denied" do
    sign_in_as(user_with_capabilities)

    get admin_dated_agendas_path

    assert_redirected_to root_path
    assert_equal "You do not have permission to open that page.", flash[:alert]
  end

  test "index lists dated agendas" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership Meeting", status: "draft")

    get admin_dated_agendas_path

    assert_response :success
    assert_select "h1", text: /Dated Agendas/
    assert_select "a[href=?]", new_admin_dated_agenda_path, text: /New Dated Agenda/
    assert_select "body", text: /#{agenda.title}/
  end

  test "new form includes meeting body, meeting type, date time, and title fields" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get new_admin_dated_agenda_path

    assert_response :success
    assert_select "select[name='dated_agenda[meeting_body_id]']"
    assert_select "select[name='dated_agenda[meeting_type_id]']"
    assert_select "input[name='dated_agenda[starts_at]']"
    assert_select "input[name='dated_agenda[title]']"
  end

  test "create copies meeting type agenda items" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    assert_difference -> { @organization.dated_agendas.count }, 1 do
      assert_difference -> { DatedAgendaItem.count }, 1 do
        post admin_dated_agendas_path, params: { dated_agenda: { meeting_body_id: @meeting_body.id, meeting_type_id: @meeting_type.id, starts_at: "2026-08-04T19:00", title: "" } }
      end
    end

    agenda = @organization.dated_agendas.last
    assert_redirected_to edit_admin_dated_agenda_path(agenda)
    assert_equal "Dated agenda created.", flash[:notice]
    assert_equal "Membership Meeting — August 4, 2026", agenda.title
    assert_equal "Opening", agenda.dated_agenda_items.first.title
  end

  test "create rejects another organization's meeting type" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    other_type = other.meeting_types.create!(name: "Other Meeting", position: 1, active: true)

    post admin_dated_agendas_path, params: { dated_agenda: { meeting_body_id: @meeting_body.id, meeting_type_id: other_type.id, starts_at: "2026-08-04T19:00", title: "Other" } }

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

- [ ] **Step 2: Run controller test to verify it fails**

Run:

```bash
bin/rails test test/controllers/admin/dated_agendas_controller_test.rb
```

Expected: failures because routes/controller/views do not exist.

- [ ] **Step 3: Add admin routes**

In `config/routes.rb`, inside `namespace :admin`, add this block after `resources :meeting_types`:

```ruby
resources :dated_agendas, except: %i[destroy] do
  member do
    patch :approve
    patch :publish
    patch :reopen
    get :print
  end
  resources :agenda_items, controller: "dated_agenda_items", as: :agenda_items, only: %i[new create edit update destroy] do
    patch :move, on: :member
  end
end
```

- [ ] **Step 4: Add the officer dated agendas controller**

Create `app/controllers/admin/dated_agendas_controller.rb`:

```ruby
module Admin
  class DatedAgendasController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_dated_agenda, only: %i[edit update approve publish reopen print]
    before_action :set_form_collections, only: %i[new create edit update]

    def index
      @dated_agendas = @organization.dated_agendas.includes(:meeting_body, :meeting_type).ordered
    end

    def new
      @dated_agenda = @organization.dated_agendas.build(starts_at: default_starts_at, status: "draft")
    end

    def create
      meeting_body = @organization.meeting_bodies.find(dated_agenda_params[:meeting_body_id])
      meeting_type = @organization.meeting_types.active.find(dated_agenda_params[:meeting_type_id])
      starts_at = Time.zone.parse(dated_agenda_params[:starts_at].to_s)
      @dated_agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: meeting_body, meeting_type: meeting_type, starts_at: starts_at, title: dated_agenda_params[:title])
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Dated agenda created."
    rescue ActiveRecord::RecordInvalid, ArgumentError
      @dated_agenda ||= @organization.dated_agendas.build(dated_agenda_params.except(:meeting_body_id, :meeting_type_id))
      @dated_agenda.errors.add(:base, "Choose a meeting body, meeting type, and date/time.") if @dated_agenda.errors.empty?
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      return redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "Reopen this agenda before editing." if @dated_agenda.locked_for_editing?

      if @dated_agenda.update(dated_agenda_params.except(:meeting_body_id, :meeting_type_id))
        redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Dated agenda updated."
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::StaleObjectError
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "This agenda was changed by someone else. Review the latest version before saving."
    end

    def approve
      @dated_agenda.approve!(current_user)
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Agenda approved."
    end

    def publish
      @dated_agenda.publish!(current_user)
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Agenda published."
    rescue ActiveRecord::RecordInvalid
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "Approve this agenda before publishing it."
    end

    def reopen
      @dated_agenda.reopen!
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Agenda reopened for editing."
    end

    def print
      render layout: "application"
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_dated_agenda
      @dated_agenda = @organization.dated_agendas.find(params[:id])
    end

    def set_form_collections
      @meeting_bodies = @organization.meeting_bodies.order(:name)
      @meeting_types = @organization.meeting_types.active.ordered
    end

    def default_starts_at
      Time.zone.now.change(hour: 19, min: 0) + 1.week
    end

    def dated_agenda_params
      params.require(:dated_agenda).permit(:meeting_body_id, :meeting_type_id, :starts_at, :title, :lock_version)
    end
  end
end
```

- [ ] **Step 5: Add minimal officer views**

Create `app/views/admin/dated_agendas/index.html.erb`:

```erb
<section class="mx-auto max-w-5xl space-y-6 px-4 py-8">
  <div class="flex items-center justify-between gap-4">
    <div>
      <p class="text-sm font-semibold uppercase tracking-wide text-blue-800">Meeting records</p>
      <h1 class="text-3xl font-bold text-slate-950">Dated Agendas</h1>
      <p class="mt-2 text-slate-700">Create and prepare agendas for actual meeting dates.</p>
    </div>
    <%= link_to "New Dated Agenda", new_admin_dated_agenda_path, class: "rounded bg-blue-900 px-4 py-2 font-semibold text-white" %>
  </div>

  <div class="space-y-3">
    <% @dated_agendas.each do |agenda| %>
      <article class="rounded border border-slate-200 bg-white p-4 shadow-sm">
        <div class="flex items-center justify-between gap-4">
          <div>
            <h2 class="text-xl font-semibold text-slate-950"><%= agenda.title %></h2>
            <p class="text-sm text-slate-600"><%= agenda.meeting_body.name %> · <%= agenda.starts_at.to_fs(:long) %> · <%= agenda.status.titleize %></p>
          </div>
          <%= link_to "Open", edit_admin_dated_agenda_path(agenda), class: "font-semibold text-blue-900" %>
        </div>
      </article>
    <% end %>
  </div>
</section>
```

Create `app/views/admin/dated_agendas/new.html.erb`:

```erb
<section class="mx-auto max-w-3xl space-y-6 px-4 py-8">
  <div>
    <p class="text-sm font-semibold uppercase tracking-wide text-blue-800">New meeting agenda</p>
    <h1 class="text-3xl font-bold text-slate-950">Create a Dated Agenda</h1>
    <p class="mt-2 text-slate-700">Choose the meeting body, template, and date. The agenda items will be copied into this meeting's draft agenda.</p>
  </div>
  <%= render "form", dated_agenda: @dated_agenda %>
</section>
```

Create `app/views/admin/dated_agendas/edit.html.erb`:

```erb
<section class="mx-auto max-w-5xl space-y-6 px-4 py-8">
  <div class="flex items-start justify-between gap-4">
    <div>
      <p class="text-sm font-semibold uppercase tracking-wide text-blue-800"><%= @dated_agenda.status.titleize %> agenda</p>
      <h1 class="text-3xl font-bold text-slate-950"><%= @dated_agenda.title %></h1>
      <p class="mt-2 text-slate-700"><%= @dated_agenda.meeting_body.name %> · <%= @dated_agenda.starts_at.to_fs(:long) %></p>
    </div>
    <div class="flex flex-wrap justify-end gap-2">
      <%= link_to "Print", print_admin_dated_agenda_path(@dated_agenda), class: "rounded border border-slate-300 px-3 py-2 font-semibold text-slate-800" %>
      <% if @dated_agenda.draft? %>
        <%= button_to "Approve", approve_admin_dated_agenda_path(@dated_agenda), method: :patch, class: "rounded bg-blue-900 px-3 py-2 font-semibold text-white" %>
      <% elsif @dated_agenda.approved? %>
        <%= button_to "Publish", publish_admin_dated_agenda_path(@dated_agenda), method: :patch, class: "rounded bg-green-800 px-3 py-2 font-semibold text-white" %>
        <%= button_to "Reopen for editing", reopen_admin_dated_agenda_path(@dated_agenda), method: :patch, data: { turbo_confirm: "Reopen this approved agenda for editing?" }, class: "rounded border border-amber-500 px-3 py-2 font-semibold text-amber-800" %>
      <% else %>
        <%= button_to "Reopen for editing", reopen_admin_dated_agenda_path(@dated_agenda), method: :patch, data: { turbo_confirm: "Reopen this published agenda for editing? Members will not see draft changes until it is published again." }, class: "rounded border border-amber-500 px-3 py-2 font-semibold text-amber-800" %>
      <% end %>
    </div>
  </div>

  <%= render "form", dated_agenda: @dated_agenda %>

  <div class="rounded border border-slate-200 bg-white p-4 shadow-sm">
    <div class="mb-4 flex items-center justify-between">
      <h2 class="text-xl font-semibold text-slate-950">Agenda Items</h2>
      <% if @dated_agenda.draft? %>
        <%= link_to "Add from catalog", new_admin_dated_agenda_agenda_item_path(@dated_agenda), class: "font-semibold text-blue-900" %>
      <% end %>
    </div>
    <ol class="space-y-3">
      <% @dated_agenda.dated_agenda_items.active.ordered.each do |item| %>
        <li class="rounded border border-slate-200 p-3">
          <div class="flex items-start justify-between gap-4">
            <div>
              <p class="font-semibold text-slate-950"><%= item.position %>. <%= item.title %></p>
              <p class="text-sm text-slate-600"><%= item.summary %></p>
            </div>
            <% if @dated_agenda.draft? %>
              <%= link_to "Edit", edit_admin_dated_agenda_agenda_item_path(@dated_agenda, item), class: "font-semibold text-blue-900" %>
            <% end %>
          </div>
        </li>
      <% end %>
    </ol>
  </div>
</section>
```

Create `app/views/admin/dated_agendas/_form.html.erb`:

```erb
<%= form_with model: [ :admin, dated_agenda ], class: "space-y-4 rounded border border-slate-200 bg-white p-4 shadow-sm" do |form| %>
  <% if dated_agenda.errors.any? %>
    <div class="error-summary rounded border border-red-300 bg-red-50 p-3 text-red-900">
      <p class="font-semibold">Please fix these agenda details:</p>
      <ul class="list-disc pl-5">
        <% dated_agenda.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>
  <%= form.hidden_field :lock_version %>
  <div>
    <%= form.label :meeting_body_id, "Meeting body", class: "block font-semibold text-slate-900" %>
    <%= form.collection_select :meeting_body_id, @meeting_bodies, :id, :name, {}, class: "mt-1 w-full rounded border border-slate-300" %>
  </div>
  <div>
    <%= form.label :meeting_type_id, "Meeting type template", class: "block font-semibold text-slate-900" %>
    <%= form.collection_select :meeting_type_id, @meeting_types, :id, :name, {}, class: "mt-1 w-full rounded border border-slate-300", disabled: dated_agenda.persisted? %>
  </div>
  <div>
    <%= form.label :starts_at, "Meeting date and time", class: "block font-semibold text-slate-900" %>
    <%= form.datetime_local_field :starts_at, class: "mt-1 w-full rounded border border-slate-300" %>
  </div>
  <div>
    <%= form.label :title, "Agenda title", class: "block font-semibold text-slate-900" %>
    <%= form.text_field :title, placeholder: "Leave blank to use the meeting type and date", class: "mt-1 w-full rounded border border-slate-300" %>
  </div>
  <% if dated_agenda.draft? %>
    <%= form.submit dated_agenda.persisted? ? "Save agenda details" : "Create dated agenda", class: "rounded bg-blue-900 px-4 py-2 font-semibold text-white" %>
  <% else %>
    <p class="rounded bg-amber-50 p-3 text-amber-900">This agenda is locked. Reopen it before editing.</p>
  <% end %>
<% end %>
```

- [ ] **Step 6: Run focused controller test**

Run:

```bash
bin/rails test test/controllers/admin/dated_agendas_controller_test.rb
```

Expected: all tests in the new controller file pass.

- [ ] **Step 7: Commit officer create/edit shell**

Run:

```bash
git add config/routes.rb app/controllers/admin/dated_agendas_controller.rb app/views/admin/dated_agendas test/controllers/admin/dated_agendas_controller_test.rb
git commit -m "feat: add officer dated agenda workflow"
```

---

### Task 3: Add copied agenda item editing, catalog add, move, and remove

**Files:**
- Create: `app/controllers/admin/dated_agenda_items_controller.rb`
- Create: `app/views/admin/dated_agenda_items/new.html.erb`
- Create: `app/views/admin/dated_agenda_items/edit.html.erb`
- Test: `test/controllers/admin/dated_agenda_items_controller_test.rb`

- [ ] **Step 1: Write item controller tests**

Create `test/controllers/admin/dated_agenda_items_controller_test.rb` using the same `setup` and `user_with_capabilities` style as `test/controllers/admin/meeting_type_agenda_items_controller_test.rb`. Include these tests exactly:

```ruby
test "update copied item does not change template item or catalog entry" do
  sign_in_as(user_with_capabilities("manage_agendas"))
  item = @agenda.dated_agenda_items.first

  patch admin_dated_agenda_agenda_item_path(@agenda, item), params: { dated_agenda_item: { title: "Meeting-specific", summary: "New summary", body: "New body", lock_version: item.lock_version } }

  assert_redirected_to edit_admin_dated_agenda_path(@agenda)
  assert_equal "Agenda item updated.", flash[:notice]
  assert_equal "Meeting-specific", item.reload.title
  assert_equal "Opening", @template_item.reload.title
  assert_equal "Opening Ceremony", @catalog_entry.reload.title
end

test "add catalog item copies it into dated agenda" do
  sign_in_as(user_with_capabilities("manage_agendas"))
  new_entry = @organization.agenda_item_catalog_entries.create!(title: "Commander Report", category: "reports", behavior_type: "report_slot", position: 2, active: true, body: "Report body")

  assert_difference -> { @agenda.dated_agenda_items.count }, 1 do
    post admin_dated_agenda_agenda_items_path(@agenda), params: { agenda_item_catalog_entry_id: new_entry.id }
  end

  item = @agenda.dated_agenda_items.find_by!(agenda_item_catalog_entry: new_entry)
  assert_equal 2, item.position
  assert_includes item.body.to_s, "Report body"
  assert_redirected_to edit_admin_dated_agenda_path(@agenda)
end

test "move item up and down swaps positions" do
  sign_in_as(user_with_capabilities("manage_agendas"))
  first = @agenda.dated_agenda_items.first
  second_entry = @organization.agenda_item_catalog_entries.create!(title: "Second", category: "business", behavior_type: "business_item", position: 2, active: true)
  second = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: second_entry, position: 2, title: "Second", behavior_type: "business_item", active: true)

  patch move_admin_dated_agenda_agenda_item_path(@agenda, second, direction: "up")
  assert_equal [ 2, 1 ], [ first.reload.position, second.reload.position ]

  patch move_admin_dated_agenda_agenda_item_path(@agenda, second, direction: "down")
  assert_equal [ 1, 2 ], [ first.reload.position, second.reload.position ]
end

test "locked agenda item edit redirects with alert" do
  sign_in_as(user_with_capabilities("manage_agendas"))
  @agenda.approve!(User.last)
  item = @agenda.dated_agenda_items.first

  patch admin_dated_agenda_agenda_item_path(@agenda, item), params: { dated_agenda_item: { title: "Blocked", lock_version: item.lock_version } }

  assert_redirected_to edit_admin_dated_agenda_path(@agenda)
  assert_equal "Reopen this agenda before editing items.", flash[:alert]
  assert_not_equal "Blocked", item.reload.title
end
```

In the same file, define `setup` before these tests:

```ruby
setup do
  @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
  Installation.singleton.update!(setup_completed_at: Time.current)
  @meeting_body = @organization.meeting_bodies.create!(name: "Membership")
  @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
  @catalog_entry = @organization.agenda_item_catalog_entries.create!(title: "Opening Ceremony", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true, body: "Opening words")
  @template_item = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "Opening", active: true, body: "Template body")
  @agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
end
```

- [ ] **Step 2: Run item tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/admin/dated_agenda_items_controller_test.rb
```

Expected: failures because the controller and views do not exist.

- [ ] **Step 3: Add item controller**

Create `app/controllers/admin/dated_agenda_items_controller.rb`:

```ruby
module Admin
  class DatedAgendaItemsController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_dated_agenda
    before_action :ensure_draft_agenda, except: %i[new]
    before_action :set_item, only: %i[edit update destroy move]

    def new
      existing_ids = @dated_agenda.dated_agenda_items.pluck(:agenda_item_catalog_entry_id).compact.to_set
      grouped = @organization.agenda_item_catalog_entries.active.ordered.group_by(&:category)
      @entries_by_category = AgendaItemCatalogEntry::CATEGORIES.keys.filter_map do |category|
        entries = grouped[category]
        next if entries.blank?

        [ category, entries.map { |entry| [ entry, existing_ids.include?(entry.id) ] } ]
      end.to_h
    end

    def create
      catalog_entry = @organization.agenda_item_catalog_entries.active.find(params[:agenda_item_catalog_entry_id])
      @dated_agenda.with_lock do
        DatedAgendaItem.create_from_catalog_entry!(catalog_entry, position: next_position, dated_agenda: @dated_agenda)
      end
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Catalog item added."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      redirect_to new_admin_dated_agenda_agenda_item_path(@dated_agenda), alert: "Catalog item could not be added."
    end

    def edit; end

    def update
      if @item.update(item_params)
        redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Agenda item updated."
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::StaleObjectError
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "This agenda item was changed by someone else. Review the latest version before saving."
    end

    def destroy
      @item.destroy
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Agenda item removed."
    end

    def move
      @dated_agenda.with_lock do
        @item.reload
        current_position = @item.position
        neighbor = case params[:direction]
        when "up" then @dated_agenda.dated_agenda_items.where("position < ?", current_position).ordered.last
        when "down" then @dated_agenda.dated_agenda_items.where("position > ?", current_position).ordered.first
        end
        if neighbor.present?
          neighbor_position = neighbor.position
          temp_position = next_position
          @item.update!(position: temp_position)
          neighbor.update!(position: current_position)
          @item.update!(position: neighbor_position)
        end
      end
      redirect_to edit_admin_dated_agenda_path(@dated_agenda)
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_dated_agenda
      @dated_agenda = @organization.dated_agendas.find(params[:dated_agenda_id])
    end

    def set_item
      @item = @dated_agenda.dated_agenda_items.find(params[:id])
    end

    def ensure_draft_agenda
      return if @dated_agenda.draft?

      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "Reopen this agenda before editing items."
    end

    def next_position
      @dated_agenda.dated_agenda_items.maximum(:position).to_i + 1
    end

    def item_params
      params.require(:dated_agenda_item).permit(:title, :summary, :body, :lock_version)
    end
  end
end
```

- [ ] **Step 4: Add item views**

Create `app/views/admin/dated_agenda_items/new.html.erb`:

```erb
<section class="mx-auto max-w-5xl space-y-6 px-4 py-8">
  <div>
    <p class="text-sm font-semibold uppercase tracking-wide text-blue-800">Add agenda item</p>
    <h1 class="text-3xl font-bold text-slate-950"><%= @dated_agenda.title %></h1>
    <p class="mt-2 text-slate-700">Choose an active catalog item to copy into this dated agenda.</p>
  </div>
  <% @entries_by_category.each do |category, entries| %>
    <section class="rounded border border-slate-200 bg-white p-4 shadow-sm">
      <h2 class="mb-3 text-xl font-semibold text-slate-950"><%= AgendaItemCatalogEntry::CATEGORIES.fetch(category) %></h2>
      <div class="space-y-2">
        <% entries.each do |entry, already_added| %>
          <div class="flex items-center justify-between gap-4 rounded border border-slate-200 p-3">
            <div>
              <p class="font-semibold"><%= entry.title %></p>
              <p class="text-sm text-slate-600"><%= entry.summary %></p>
            </div>
            <% if already_added %>
              <span class="text-sm font-semibold text-slate-500">Already added</span>
            <% else %>
              <%= button_to "Add", admin_dated_agenda_agenda_items_path(@dated_agenda), params: { agenda_item_catalog_entry_id: entry.id }, class: "rounded bg-blue-900 px-3 py-2 font-semibold text-white" %>
            <% end %>
          </div>
        <% end %>
      </div>
    </section>
  <% end %>
</section>
```

Create `app/views/admin/dated_agenda_items/edit.html.erb`:

```erb
<section class="mx-auto max-w-3xl space-y-6 px-4 py-8">
  <div>
    <p class="text-sm font-semibold uppercase tracking-wide text-blue-800">Edit agenda item</p>
    <h1 class="text-3xl font-bold text-slate-950"><%= @item.title %></h1>
    <p class="mt-2 text-slate-700">Changes here only affect <%= @dated_agenda.title %>.</p>
  </div>
  <%= form_with model: [ :admin, @dated_agenda, @item ], class: "space-y-4 rounded border border-slate-200 bg-white p-4 shadow-sm" do |form| %>
    <% if @item.errors.any? %>
      <div class="error-summary rounded border border-red-300 bg-red-50 p-3 text-red-900"><%= @item.errors.full_messages.to_sentence %></div>
    <% end %>
    <%= form.hidden_field :lock_version %>
    <div>
      <%= form.label :title, class: "block font-semibold text-slate-900" %>
      <%= form.text_field :title, class: "mt-1 w-full rounded border border-slate-300" %>
    </div>
    <div>
      <%= form.label :summary, class: "block font-semibold text-slate-900" %>
      <%= form.text_area :summary, rows: 3, class: "mt-1 w-full rounded border border-slate-300" %>
    </div>
    <div>
      <%= form.label :body, "Agenda wording", class: "block font-semibold text-slate-900" %>
      <%= form.rich_text_area :body %>
    </div>
    <%= form.submit "Save agenda item", class: "rounded bg-blue-900 px-4 py-2 font-semibold text-white" %>
  <% end %>
</section>
```

- [ ] **Step 5: Run item controller tests**

Run:

```bash
bin/rails test test/controllers/admin/dated_agenda_items_controller_test.rb
```

Expected: all tests in the new item controller file pass.

- [ ] **Step 6: Commit item editing workflow**

Run:

```bash
git add app/controllers/admin/dated_agenda_items_controller.rb app/views/admin/dated_agenda_items test/controllers/admin/dated_agenda_items_controller_test.rb
git commit -m "feat: edit dated agenda items"
```

---

### Task 4: Add lifecycle tests and polish locking behavior

**Files:**
- Modify: `test/controllers/admin/dated_agendas_controller_test.rb`
- Modify: `app/controllers/admin/dated_agendas_controller.rb`
- Modify: `app/models/dated_agenda.rb`

- [ ] **Step 1: Add lifecycle controller tests**

Append to `test/controllers/admin/dated_agendas_controller_test.rb`:

```ruby
test "approve locks agenda and records approver" do
  user = user_with_capabilities("manage_agendas")
  sign_in_as(user)
  agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership", status: "draft")

  patch approve_admin_dated_agenda_path(agenda)

  assert_redirected_to edit_admin_dated_agenda_path(agenda)
  assert_equal "approved", agenda.reload.status
  assert_equal user, agenda.approved_by
  assert_not_nil agenda.approved_at
end

test "publish requires approved agenda" do
  sign_in_as(user_with_capabilities("manage_agendas"))
  agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership", status: "draft")

  patch publish_admin_dated_agenda_path(agenda)

  assert_redirected_to edit_admin_dated_agenda_path(agenda)
  assert_equal "Approve this agenda before publishing it.", flash[:alert]
  assert_equal "draft", agenda.reload.status
end

test "reopen returns approved agenda to draft" do
  user = user_with_capabilities("manage_agendas")
  sign_in_as(user)
  agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership", status: "approved", approved_by: user, approved_at: Time.current)

  patch reopen_admin_dated_agenda_path(agenda)

  assert_redirected_to edit_admin_dated_agenda_path(agenda)
  assert_equal "draft", agenda.reload.status
  assert_nil agenda.approved_by
end

test "stale agenda update redirects with conflict message" do
  sign_in_as(user_with_capabilities("manage_agendas"))
  agenda = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Membership", status: "draft")
  stale_lock_version = agenda.lock_version
  agenda.update!(title: "Changed elsewhere")

  patch admin_dated_agenda_path(agenda), params: { dated_agenda: { starts_at: "2026-08-04T19:00", title: "Stale", lock_version: stale_lock_version } }

  assert_redirected_to edit_admin_dated_agenda_path(agenda)
  assert_equal "This agenda was changed by someone else. Review the latest version before saving.", flash[:alert]
end
```

- [ ] **Step 2: Run lifecycle tests**

Run:

```bash
bin/rails test test/controllers/admin/dated_agendas_controller_test.rb
```

Expected: pass after Task 2 implementation; if the stale update test fails, ensure `lock_version` is permitted and included as a hidden field.

- [ ] **Step 3: Commit lifecycle behavior**

Run:

```bash
git add app/controllers/admin/dated_agendas_controller.rb app/models/dated_agenda.rb test/controllers/admin/dated_agendas_controller_test.rb
git commit -m "feat: add dated agenda lifecycle controls"
```

---

### Task 5: Add member-facing published and printable views

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/dated_agendas_controller.rb`
- Create: `app/views/dated_agendas/index.html.erb`
- Create: `app/views/dated_agendas/show.html.erb`
- Create: `app/views/dated_agendas/print.html.erb`
- Create: `app/views/admin/dated_agendas/print.html.erb`
- Test: `test/controllers/dated_agendas_controller_test.rb`

- [ ] **Step 1: Write member visibility tests**

Create `test/controllers/dated_agendas_controller_test.rb`:

```ruby
require "test_helper"

class DatedAgendasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @meeting_body = @organization.meeting_bodies.create!(name: "Membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @draft = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0), title: "Draft Agenda", status: "draft")
    @published = @organization.dated_agendas.create!(meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 11, 19, 0), title: "Published Agenda", status: "published")
    @published.dated_agenda_items.create!(position: 1, title: "Opening", behavior_type: "scripted_ceremony", active: true, body: "Opening words")
  end

  test "signed out users are redirected" do
    get dated_agendas_path

    assert_redirected_to new_session_path
  end

  test "index lists published agendas and hides drafts" do
    sign_in_as(user_with_capabilities)

    get dated_agendas_path

    assert_response :success
    assert_select "body", text: /Published Agenda/
    assert_select "body", text: /Draft Agenda/, count: 0
  end

  test "show displays published agenda read only" do
    sign_in_as(user_with_capabilities)

    get dated_agenda_path(@published)
    assert_response :success
    assert_select "body", text: /Opening words/
    assert_select "a", text: /Edit/, count: 0
  end

  test "draft agenda is not visible to members" do
    sign_in_as(user_with_capabilities)

    get dated_agenda_path(@draft)
    assert_response :not_found
  end

  test "print view renders without edit controls" do
    sign_in_as(user_with_capabilities)

    get print_dated_agenda_path(@published)
    assert_response :success
    assert_select "body", text: /Published Agenda/
    assert_select "a", text: /Edit/, count: 0
  end

  private

  def user_with_capabilities(*capabilities)
    person = Person.create!(first_name: "Member", last_name: "User")
    user = User.create!(person: person, email_address: "member-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
```

- [ ] **Step 2: Run member tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/dated_agendas_controller_test.rb
```

Expected: failures because member routes/controller/views do not exist.

- [ ] **Step 3: Add member routes**

In `config/routes.rb`, after `resources :people, only: %i[index show]`, add:

```ruby
resources :dated_agendas, only: %i[index show] do
  get :print, on: :member
end
```

- [ ] **Step 4: Add member controller**

Create `app/controllers/dated_agendas_controller.rb`:

```ruby
class DatedAgendasController < ApplicationController
  before_action :require_authentication
  before_action :set_organization
  before_action :set_dated_agenda, only: %i[show print]

  def index
    @dated_agendas = @organization.dated_agendas.published.upcoming.includes(:meeting_body).order(:starts_at, :title)
  end

  def show; end

  def print
    render layout: "application"
  end

  private

  def set_organization
    @organization = Organization.first!
  end

  def set_dated_agenda
    @dated_agenda = @organization.dated_agendas.published.find(params[:id])
  end
end
```

- [ ] **Step 5: Add member and print views**

Create `app/views/dated_agendas/index.html.erb`:

```erb
<section class="mx-auto max-w-5xl space-y-6 px-4 py-8">
  <div>
    <p class="text-sm font-semibold uppercase tracking-wide text-blue-800">Member agendas</p>
    <h1 class="text-3xl font-bold text-slate-950">Published Agendas</h1>
    <p class="mt-2 text-slate-700">Read and print agendas that are ready for upcoming meetings.</p>
  </div>
  <div class="space-y-3">
    <% @dated_agendas.each do |agenda| %>
      <article class="rounded border border-slate-200 bg-white p-4 shadow-sm">
        <h2 class="text-xl font-semibold"><%= link_to agenda.title, dated_agenda_path(agenda), class: "text-blue-900" %></h2>
        <p class="text-sm text-slate-600"><%= agenda.meeting_body.name %> · <%= agenda.starts_at.to_fs(:long) %></p>
      </article>
    <% end %>
  </div>
</section>
```

Create `app/views/dated_agendas/show.html.erb`:

```erb
<section class="mx-auto max-w-4xl space-y-6 px-4 py-8">
  <div class="flex items-start justify-between gap-4">
    <div>
      <p class="text-sm font-semibold uppercase tracking-wide text-blue-800">Published agenda</p>
      <h1 class="text-3xl font-bold text-slate-950"><%= @dated_agenda.title %></h1>
      <p class="mt-2 text-slate-700"><%= @dated_agenda.meeting_body.name %> · <%= @dated_agenda.starts_at.to_fs(:long) %></p>
    </div>
    <%= link_to "Print", print_dated_agenda_path(@dated_agenda), class: "rounded border border-slate-300 px-3 py-2 font-semibold text-slate-800" %>
  </div>
  <%= render "agenda_body", dated_agenda: @dated_agenda %>
</section>
```

Create `app/views/dated_agendas/_agenda_body.html.erb`:

```erb
<ol class="space-y-4">
  <% dated_agenda.dated_agenda_items.active.ordered.each do |item| %>
    <li class="rounded border border-slate-200 bg-white p-4 shadow-sm">
      <h2 class="text-xl font-semibold text-slate-950"><%= item.position %>. <%= item.title %></h2>
      <% if item.summary.present? %>
        <p class="mt-1 text-slate-700"><%= item.summary %></p>
      <% end %>
      <div class="prose mt-3 max-w-none"><%= item.body %></div>
    </li>
  <% end %>
</ol>
```

Create `app/views/dated_agendas/print.html.erb`:

```erb
<section class="mx-auto max-w-4xl space-y-6 px-4 py-8 print:px-0">
  <div class="border-b border-slate-300 pb-4">
    <p class="text-sm font-semibold uppercase tracking-wide text-slate-600">Meeting agenda</p>
    <h1 class="text-3xl font-bold text-slate-950"><%= @dated_agenda.title %></h1>
    <p class="mt-2 text-slate-700"><%= @dated_agenda.meeting_body.name %> · <%= @dated_agenda.starts_at.to_fs(:long) %></p>
  </div>
  <%= render "agenda_body", dated_agenda: @dated_agenda %>
</section>
```

Create `app/views/admin/dated_agendas/print.html.erb`:

```erb
<section class="mx-auto max-w-4xl space-y-6 px-4 py-8 print:px-0">
  <div class="border-b border-slate-300 pb-4">
    <p class="text-sm font-semibold uppercase tracking-wide text-slate-600">Officer agenda print view</p>
    <h1 class="text-3xl font-bold text-slate-950"><%= @dated_agenda.title %></h1>
    <p class="mt-2 text-slate-700"><%= @dated_agenda.meeting_body.name %> · <%= @dated_agenda.starts_at.to_fs(:long) %> · <%= @dated_agenda.status.titleize %></p>
  </div>
  <%= render "dated_agendas/agenda_body", dated_agenda: @dated_agenda %>
</section>
```

- [ ] **Step 6: Run member tests**

Run:

```bash
bin/rails test test/controllers/dated_agendas_controller_test.rb
```

Expected: all member-facing tests pass.

- [ ] **Step 7: Commit published agenda views**

Run:

```bash
git add config/routes.rb app/controllers/dated_agendas_controller.rb app/views/dated_agendas app/views/admin/dated_agendas/print.html.erb test/controllers/dated_agendas_controller_test.rb
git commit -m "feat: publish dated agendas to members"
```

---

### Task 6: Final integration, navigation, and verification

**Files:**
- Modify: `app/views/admin/dashboard/show.html.erb`
- Modify: `app/views/dashboard/show.html.erb`
- Modify: `docs/ROADMAP.md`

- [ ] **Step 1: Add navigation links where existing patterns make them visible**

In `app/views/admin/dashboard/show.html.erb`, add this tile inside the `if show_agendas` block after the Meeting Types tile:

```erb
<div class="tile">
  <div class="tile-ic" aria-hidden="true">🗓️</div>
  <p class="tile-t">Dated Agendas</p>
  <p class="tile-d">Prepare the agenda for an actual meeting date, then approve and publish it for members.</p>
  <div class="tile-actions">
    <%= link_to "Manage dated agendas →", admin_dated_agendas_path, class: "tile-act" %>
  </div>
</div>
```

In `app/views/dashboard/show.html.erb`, add this section after the existing `.page-lead` block:

```erb
<section class="hub-sec">
  <h2 class="hub-sec-h">Meetings</h2>
  <p class="hub-sec-n">View agendas that are ready for upcoming post meetings.</p>
  <div class="hub-tiles">
    <div class="tile">
      <div class="tile-ic" aria-hidden="true">📋</div>
      <p class="tile-t">Published Agendas</p>
      <p class="tile-d">Read or print agendas that have been approved for members.</p>
      <div class="tile-actions">
        <%= link_to "View published agendas →", dated_agendas_path, class: "tile-act" %>
      </div>
    </div>
  </div>
</section>
```

- [ ] **Step 2: Update roadmap status**

In `docs/ROADMAP.md`, under `Immediate Next: Structured Agendas`, add this completed bullet after the meeting type templates bullet:

```markdown
- Dated agendas: officer-created agendas for actual meeting dates, copied from meeting type templates, editable before approval/publication, with member read-only and printable HTML views.
```

Remove or revise these pending bullets if they are now satisfied:

```markdown
- Browser/HTML printable agenda rendering for on-screen review and printing.
```

- [ ] **Step 3: Run focused tests**

Run:

```bash
bin/rails test test/models/dated_agenda_test.rb test/models/dated_agenda_item_test.rb test/controllers/admin/dated_agendas_controller_test.rb test/controllers/admin/dated_agenda_items_controller_test.rb test/controllers/dated_agendas_controller_test.rb
```

Expected: all focused dated-agenda tests pass.

- [ ] **Step 4: Run adjacent agenda tests**

Run:

```bash
bin/rails test test/controllers/admin/meeting_types_controller_test.rb test/controllers/admin/meeting_type_agenda_items_controller_test.rb test/models/meeting_type_test.rb test/models/meeting_type_agenda_item_test.rb test/models/agenda_item_catalog_entry_test.rb test/services/meeting_type_template_seeder_test.rb
```

Expected: all adjacent meeting-type/catalog tests still pass.

- [ ] **Step 5: Run Rails test suite if focused checks pass**

Run:

```bash
bin/rails test
```

Expected: full suite passes.

- [ ] **Step 6: Run style/security checks relevant to Rails changes**

Run:

```bash
bin/rubocop
bin/brakeman
```

Expected: no new offenses or warnings. If a pre-existing offense appears, record it separately instead of hiding it.

- [ ] **Step 7: Browser smoke test the visible workflow**

Start the server bound off-box:

```bash
bin/rails server -b 0.0.0.0
```

Smoke path:

1. Sign in as a user with `manage_agendas`.
2. Open `/admin/dated_agendas`.
3. Create a dated agenda from Membership Meeting.
4. Edit one copied item.
5. Approve it.
6. Confirm edit controls are blocked until reopen.
7. Publish it.
8. Open `/dated_agendas` as an authenticated member.
9. Open the published agenda and its print view.

Expected: the workflow is understandable without developer knowledge, locked-state messaging is clear, and print view excludes edit controls.

- [ ] **Step 8: Commit final integration**

Run:

```bash
git add app/views/admin app/views/dashboard/show.html.erb docs/ROADMAP.md
git commit -m "chore: integrate dated agendas into navigation"
```

---

## Self-Review Notes

- Spec coverage: model creation, template copying, independence, editing, lifecycle locking, member published view, printable HTML, and optimistic locking all have tasks and tests.
- Deferred by design: minutes workflow, accepted-minutes immutability, app-generated PDFs, email distribution, real-time collaboration, and detailed audit logging.
- Implementation risk: `publish!` uses `RecordInvalid` as a simple controller rescue path; if Rails error presentation needs model errors, add `errors.add(:base, "Approve this agenda before publishing it")` before raising.
- UI risk: the plan gives functional ERB. A designer pass may improve visual hierarchy and older-user clarity before implementation if the team wants more polish.
