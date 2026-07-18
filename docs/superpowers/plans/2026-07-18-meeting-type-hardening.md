# Meeting Type Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the admin Meeting Types workflow by making default seeding explicit, keeping GET requests read-only, narrowing duplicate-add error handling, and protecting ordering with locks plus unique database constraints.

**Architecture:** Add a POST-only `seed_defaults` collection action under `admin/meeting_types`, remove implicit seeding from `index` and `create`, and keep the seeder itself idempotent. Wrap position-sensitive meeting type and template item writes in parent-row locks, then enforce scoped position uniqueness at the database layer with a short blocking data-normalizing migration.

**Tech Stack:** Rails 8.1, PostgreSQL, Minitest integration/model tests, server-rendered ERB, existing admin capability guards.

---

## File Structure

- Modify `config/routes.rb`: add a POST collection route for `admin/meeting_types#seed_defaults`.
- Modify `app/controllers/admin/meeting_types_controller.rb`: make `index` read-only, add `seed_defaults`, lock automatic position assignment in `create`, and expose whether defaults are missing for the view.
- Modify `app/controllers/admin/meeting_type_agenda_items_controller.rb`: lock template item creation/reordering and narrow duplicate-add handling.
- Modify `app/services/meeting_type_template_seeder.rb`: add a helper to detect whether any default meeting types are missing.
- Modify `app/views/admin/meeting_types/index.html.erb`: show a POST button to seed default meeting types when defaults are missing.
- Add `db/migrate/20260718000000_enforce_unique_meeting_type_positions.rb`: lock the tables, normalize existing duplicate positions, and replace non-unique position indexes with unique indexes in one blocking migration.
- Modify `test/controllers/admin/meeting_types_controller_test.rb`: update tests for read-only GET, explicit seeding, and failed create behavior.
- Modify `test/controllers/admin/meeting_type_agenda_items_controller_test.rb`: update tests for duplicate-only rescue and position assignment.
- Modify `test/models/meeting_type_test.rb` and `test/models/meeting_type_agenda_item_test.rb`: assert scoped position uniqueness if model validations are added.

---

### Task 1: Add explicit POST default seeding

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/services/meeting_type_template_seeder.rb`
- Modify: `app/controllers/admin/meeting_types_controller.rb`
- Modify: `app/views/admin/meeting_types/index.html.erb`
- Test: `test/controllers/admin/meeting_types_controller_test.rb`

- [ ] **Step 1: Update controller tests for read-only GET and explicit POST seeding**

Replace the current `index seeds and lists meeting types` test in `test/controllers/admin/meeting_types_controller_test.rb` with:

```ruby
test "index is read-only and lists existing meeting types" do
  sign_in_as(user_with_capabilities("manage_agendas"))
  existing = @organization.meeting_types.create!(name: "Special Ceremony Meeting", position: 1, active: true)

  assert_no_difference -> { @organization.meeting_types.count } do
    assert_no_difference -> { MeetingTypeAgendaItem.count } do
      get admin_meeting_types_path
    end
  end

  assert_response :success
  assert_select "h1", text: /Meeting Types/
  assert_select "a[href=?]", admin_agenda_item_catalog_entries_path, text: /Agenda Item Catalog/
  assert_select "body", text: /#{existing.name}/
  assert_select "form[action=?][method=?]", seed_defaults_admin_meeting_types_path, "post"
end

test "seed defaults creates default meeting types with a post request" do
  sign_in_as(user_with_capabilities("manage_agendas"))

  assert_difference -> { @organization.meeting_types.count }, 2 do
    post seed_defaults_admin_meeting_types_path
  end

  assert_redirected_to admin_meeting_types_path
  assert_equal "Default meeting types seeded.", flash[:notice]
  assert_equal [ "PEC Meeting", "Membership Meeting" ], @organization.meeting_types.ordered.pluck(:name)
end
```

- [ ] **Step 2: Update create tests so create no longer seeds defaults**

In `test/controllers/admin/meeting_types_controller_test.rb`, change `create meeting type` to expect one new record:

```ruby
test "create meeting type" do
  sign_in_as(user_with_capabilities("manage_agendas"))

  assert_difference -> { @organization.meeting_types.count }, 1 do
    post admin_meeting_types_path, params: { meeting_type: { name: "Special Ceremony Meeting", active: true } }
  end

  meeting_type = @organization.meeting_types.find_by!(slug: "special-ceremony-meeting")
  assert_redirected_to edit_admin_meeting_type_path(meeting_type)
  assert_equal "Meeting type created.", flash[:notice]
end
```

Replace `create seeds defaults before assigning next position on a fresh organization` with:

```ruby
test "create on a fresh organization uses the first position without seeding defaults" do
  sign_in_as(user_with_capabilities("manage_agendas"))

  post admin_meeting_types_path, params: { meeting_type: { name: "Special Ceremony Meeting", active: true } }

  meeting_type = @organization.meeting_types.find_by!(slug: "special-ceremony-meeting")
  assert_equal 1, meeting_type.position
  assert_equal [ "Special Ceremony Meeting" ], @organization.meeting_types.ordered.pluck(:name)
end
```

Change `newly created meeting type appends after seeded defaults` to seed with POST:

```ruby
test "newly created meeting type appends after seeded defaults" do
  sign_in_as(user_with_capabilities("manage_agendas"))
  post seed_defaults_admin_meeting_types_path

  post admin_meeting_types_path, params: { meeting_type: { name: "Special Ceremony Meeting", active: true } }

  meeting_type = @organization.meeting_types.find_by!(slug: "special-ceremony-meeting")
  assert_equal 3, meeting_type.position
  assert_equal [ "PEC Meeting", "Membership Meeting", "Special Ceremony Meeting" ], @organization.meeting_types.ordered.pluck(:name)
end
```

Add this test after `invalid create returns unprocessable entity`:

```ruby
test "invalid create does not seed defaults as a side effect" do
  sign_in_as(user_with_capabilities("manage_agendas"))

  assert_no_difference -> { @organization.meeting_types.count } do
    assert_no_difference -> { MeetingTypeAgendaItem.count } do
      post admin_meeting_types_path, params: { meeting_type: { name: "", active: true } }
    end
  end

  assert_response :unprocessable_entity
end
```

- [ ] **Step 3: Run the focused controller test and verify it fails**

Run:

```bash
bin/rails test test/controllers/admin/meeting_types_controller_test.rb
```

Expected: failures because `seed_defaults_admin_meeting_types_path` and `seed_defaults` do not exist, and because `index`/`create` still seed implicitly.

- [ ] **Step 4: Add the POST route**

In `config/routes.rb`, change the `resources :meeting_types` block to:

```ruby
resources :meeting_types, except: %i[show destroy] do
  post :seed_defaults, on: :collection
  resources :agenda_items, controller: "meeting_type_agenda_items", as: :agenda_items, only: %i[new create edit update destroy] do
    patch :move, on: :member
  end
end
```

- [ ] **Step 5: Add missing-default detection to the seeder**

In `app/services/meeting_type_template_seeder.rb`, add this class method after `self.seed_for!`:

```ruby
def self.defaults_missing?(organization)
  MEETING_TYPES.any? do |definition|
    meeting_type = organization.meeting_types.find_by(source_key: definition.fetch(:source_key))
    meeting_type.blank? || meeting_type.meeting_type_agenda_items.where(source_key: seeded_item_source_keys(definition)).count < definition.fetch(:item_source_keys).size
  end
end

def self.seeded_item_source_keys(definition)
  definition.fetch(:item_source_keys).map { |catalog_source_key| "#{definition.fetch(:source_key)}:#{catalog_source_key}" }
end
```

- [ ] **Step 6: Make the Meeting Types controller use explicit seeding**

Update `app/controllers/admin/meeting_types_controller.rb` so the public actions are:

```ruby
def index
  @meeting_types = @organization.meeting_types.ordered.includes(:meeting_type_agenda_items)
  @default_meeting_types_missing = MeetingTypeTemplateSeeder.defaults_missing?(@organization)
end

def new
  @meeting_type = @organization.meeting_types.new(active: true)
end

def create
  @meeting_type = @organization.meeting_types.new(meeting_type_params)

  @organization.with_lock do
    @meeting_type.position = next_position if @meeting_type.position.to_i.zero?
    @meeting_type.save
  end

  if @meeting_type.persisted?
    redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Meeting type created."
  else
    render :new, status: :unprocessable_entity
  end
end

def seed_defaults
  MeetingTypeTemplateSeeder.seed_for!(@organization)
  redirect_to admin_meeting_types_path, notice: "Default meeting types seeded."
end

def edit
  @template_items = @meeting_type.meeting_type_agenda_items.ordered
end
```

Keep `update`, private methods, and before actions unchanged.

- [ ] **Step 7: Add the index seed button**

In `app/views/admin/meeting_types/index.html.erb`, change the `.btnrow` section to:

```erb
<div class="btnrow">
  <%= link_to "Add meeting type", new_admin_meeting_type_path, class: "btn-primary" %>
  <% if @default_meeting_types_missing %>
    <%= button_to "Seed default meeting types", seed_defaults_admin_meeting_types_path, method: :post, class: "btn-secondary" %>
  <% end %>
  <%= link_to "Agenda Item Catalog", admin_agenda_item_catalog_entries_path, class: "btn-secondary" %>
</div>
```

- [ ] **Step 8: Run the focused controller test and verify it passes**

Run:

```bash
bin/rails test test/controllers/admin/meeting_types_controller_test.rb
```

Expected: all tests in that file pass.

---

### Task 2: Lock template item add/move and narrow duplicate handling

**Files:**
- Modify: `app/controllers/admin/meeting_type_agenda_items_controller.rb`
- Test: `test/controllers/admin/meeting_type_agenda_items_controller_test.rb`

- [ ] **Step 1: Add focused tests for position assignment and generic validation failure handling**

In `test/controllers/admin/meeting_type_agenda_items_controller_test.rb`, add this test after `add catalog item copies it into meeting type with rich body`:

```ruby
test "add catalog item appends at next position" do
  sign_in_as(user_with_capabilities("manage_agendas"))
  @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: @catalog_entry.title, active: true)
  second_entry = @organization.agenda_item_catalog_entries.create!(title: "Second Entry", category: "ceremony", behavior_type: "scripted_ceremony", position: 3, active: true)

  post admin_meeting_type_agenda_items_path(@meeting_type), params: { agenda_item_catalog_entry_id: second_entry.id }

  item = @meeting_type.meeting_type_agenda_items.find_by!(agenda_item_catalog_entry: second_entry)
  assert_equal 2, item.position
end
```

Add this test after `duplicate add is rejected`:

```ruby
test "non duplicate validation failure is not reported as duplicate" do
  sign_in_as(user_with_capabilities("manage_agendas"))
  invalid_entry = @organization.agenda_item_catalog_entries.create!(title: "Invalid Copy", category: "ceremony", behavior_type: "scripted_ceremony", position: 3, active: true)
  MeetingTypeAgendaItem.stub(:create_from_catalog_entry!, ->(_entry, position:, meeting_type:) { raise ActiveRecord::RecordInvalid.new(meeting_type.meeting_type_agenda_items.build(position: position)) }) do
    post admin_meeting_type_agenda_items_path(@meeting_type), params: { agenda_item_catalog_entry_id: invalid_entry.id }
  end

  assert_redirected_to new_admin_meeting_type_agenda_item_path(@meeting_type)
  assert_equal "Catalog item could not be added.", flash[:alert]
end
```

- [ ] **Step 2: Run the focused agenda item controller test and verify it fails**

Run:

```bash
bin/rails test test/controllers/admin/meeting_type_agenda_items_controller_test.rb
```

Expected: the new generic validation failure test fails because all `RecordInvalid` exceptions still show the duplicate message.

- [ ] **Step 3: Lock create and narrow rescue logic**

Replace the `create` action in `app/controllers/admin/meeting_type_agenda_items_controller.rb` with:

```ruby
def create
  catalog_entry = @organization.agenda_item_catalog_entries.active.find(params[:agenda_item_catalog_entry_id])
  @meeting_type.with_lock do
    MeetingTypeAgendaItem.create_from_catalog_entry!(catalog_entry, position: next_position, meeting_type: @meeting_type)
  end
  redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Catalog item added."
rescue ActiveRecord::RecordNotUnique => error
  alert = duplicate_catalog_entry_unique_violation?(error) ? "That catalog item is already in this meeting type." : "Catalog item could not be added."
  redirect_to new_admin_meeting_type_agenda_item_path(@meeting_type), alert: alert
rescue ActiveRecord::RecordInvalid => error
  alert = duplicate_catalog_entry_error?(error.record) ? "That catalog item is already in this meeting type." : "Catalog item could not be added."
  redirect_to new_admin_meeting_type_agenda_item_path(@meeting_type), alert: alert
end
```

Add this private helper before `item_params`:

```ruby
def duplicate_catalog_entry_error?(record)
  record&.errors&.of_kind?(:agenda_item_catalog_entry_id, :taken)
end

def duplicate_catalog_entry_unique_violation?(error)
  exception_message = [ error.message, error.cause&.message ].compact.join(" ")
  exception_message.include?("index_mt_agenda_items_on_type_and_catalog_entry") || exception_message.include?("agenda_item_catalog_entry_id")
end
```

- [ ] **Step 4: Lock move swaps**

Replace the `move` action in `app/controllers/admin/meeting_type_agenda_items_controller.rb` with:

```ruby
def move
  @meeting_type.with_lock do
    @item.reload
    current_position = @item.position
    neighbor = case params[:direction]
    when "up" then @meeting_type.meeting_type_agenda_items.where("position < ?", current_position).ordered.last
    when "down" then @meeting_type.meeting_type_agenda_items.where("position > ?", current_position).ordered.first
    end
    if neighbor.present?
      neighbor_position = neighbor.position
      temp_position = next_position
      @item.update!(position: temp_position)
      neighbor.update!(position: current_position)
      @item.update!(position: neighbor_position)
    end
  end
  redirect_to edit_admin_meeting_type_path(@meeting_type)
end
```

- [ ] **Step 5: Run the focused agenda item controller test and verify it passes**

Run:

```bash
bin/rails test test/controllers/admin/meeting_type_agenda_items_controller_test.rb
```

Expected: all tests in that file pass.

---

### Task 3: Enforce scoped position uniqueness

**Files:**
- Add: `db/migrate/20260718000000_enforce_unique_meeting_type_positions.rb`
- Modify: `app/models/meeting_type.rb`
- Modify: `app/models/meeting_type_agenda_item.rb`
- Test: `test/models/meeting_type_test.rb`
- Test: `test/models/meeting_type_agenda_item_test.rb`

- [ ] **Step 1: Add model tests for position uniqueness**

In `test/models/meeting_type_test.rb`, add:

```ruby
test "position is unique within an organization" do
  @organization.meeting_types.create!(name: "First", position: 1, active: true)

  duplicate = @organization.meeting_types.new(name: "Second", position: 1, active: true)

  assert_not duplicate.valid?
  assert_includes duplicate.errors[:position], "has already been taken"
end
```

In `test/models/meeting_type_agenda_item_test.rb`, add:

```ruby
test "position is unique within a meeting type" do
  @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "First", active: true)
  second_entry = @organization.agenda_item_catalog_entries.create!(title: "Second Entry", category: "ceremony", behavior_type: "scripted_ceremony", position: 99, active: true)

  duplicate = @meeting_type.meeting_type_agenda_items.new(agenda_item_catalog_entry: second_entry, position: 1, title: "Second", active: true)

  assert_not duplicate.valid?
  assert_includes duplicate.errors[:position], "has already been taken"
end
```

- [ ] **Step 2: Run model tests and verify they fail**

Run:

```bash
bin/rails test test/models/meeting_type_test.rb test/models/meeting_type_agenda_item_test.rb
```

Expected: failures because scoped position uniqueness validations do not exist yet.

- [ ] **Step 3: Add model validations**

In `app/models/meeting_type.rb`, change the position validation area to:

```ruby
validates :position, numericality: { only_integer: true }
validates :position, uniqueness: { scope: :organization_id }
```

In `app/models/meeting_type_agenda_item.rb`, change the position validation area to:

```ruby
validates :position, numericality: { only_integer: true }
validates :position, uniqueness: { scope: :meeting_type_id }
```

- [ ] **Step 4: Add data-normalizing unique-index migration**

Create `db/migrate/20260718000000_enforce_unique_meeting_type_positions.rb`:

```ruby
class EnforceUniqueMeetingTypePositions < ActiveRecord::Migration[8.1]
  def up
    lock_tables!
    normalize_meeting_type_positions!
    normalize_meeting_type_agenda_item_positions!

    remove_index :meeting_types, name: "index_meeting_types_on_organization_id_and_position"
    add_index :meeting_types, [ :organization_id, :position ], unique: true, name: "index_meeting_types_on_organization_id_and_position"

    remove_index :meeting_type_agenda_items, name: "index_mt_agenda_items_on_meeting_type_and_position"
    add_index :meeting_type_agenda_items, [ :meeting_type_id, :position ], unique: true, name: "index_mt_agenda_items_on_meeting_type_and_position"
  end

  def down
    remove_index :meeting_types, name: "index_meeting_types_on_organization_id_and_position"
    add_index :meeting_types, [ :organization_id, :position ], name: "index_meeting_types_on_organization_id_and_position"

    remove_index :meeting_type_agenda_items, name: "index_mt_agenda_items_on_meeting_type_and_position"
    add_index :meeting_type_agenda_items, [ :meeting_type_id, :position ], name: "index_mt_agenda_items_on_meeting_type_and_position"
  end

  private

  def normalize_meeting_type_positions!
    execute <<~SQL.squish
      WITH ranked AS (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY organization_id ORDER BY position, id) AS new_position
        FROM meeting_types
      )
      UPDATE meeting_types
      SET position = ranked.new_position
      FROM ranked
      WHERE meeting_types.id = ranked.id
    SQL
  end

  def normalize_meeting_type_agenda_item_positions!
    execute <<~SQL.squish
      WITH ranked AS (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY meeting_type_id ORDER BY position, id) AS new_position
        FROM meeting_type_agenda_items
      )
      UPDATE meeting_type_agenda_items
      SET position = ranked.new_position
      FROM ranked
      WHERE meeting_type_agenda_items.id = ranked.id
    SQL
  end

  def lock_tables!
    execute "LOCK TABLE meeting_types IN ACCESS EXCLUSIVE MODE"
    execute "LOCK TABLE meeting_type_agenda_items IN ACCESS EXCLUSIVE MODE"
  end
end
```

- [ ] **Step 5: Run migration and model tests**

Run:

```bash
bin/rails db:migrate
bin/rails test test/models/meeting_type_test.rb test/models/meeting_type_agenda_item_test.rb
```

Expected: migration succeeds and both model test files pass.

---

### Task 4: Final focused verification

**Files:**
- Verify only; no planned edits.

- [ ] **Step 1: Run focused controller/model/service tests**

Run:

```bash
bin/rails test test/controllers/admin/meeting_types_controller_test.rb test/controllers/admin/meeting_type_agenda_items_controller_test.rb test/models/meeting_type_test.rb test/models/meeting_type_agenda_item_test.rb test/services/meeting_type_template_seeder_test.rb
```

Expected: all tests pass.

- [ ] **Step 2: Run schema consistency check through test database preparation if needed**

If Rails reports pending migrations or schema mismatch during tests, run:

```bash
bin/rails db:test:prepare
```

Then rerun Step 1.

- [ ] **Step 3: Inspect final diff**

Run:

```bash
git diff -- app config db test docs/superpowers/specs/2026-07-18-meeting-type-hardening-design.md docs/superpowers/plans/2026-07-18-meeting-type-hardening.md
```

Expected: diff contains only the hardening changes described in this plan plus the approved design and plan docs.
