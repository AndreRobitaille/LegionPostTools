# Meeting Types Admin Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Meeting Types index and edit pages in line with the Post Positions pattern — drag-to-reorder, delete, instant toggle, click-to-edit name — and replace the seeded/soft-delete machinery with explicit restore-to-default actions.

**Architecture:** A shared `Reorderable` model concern gives both unique-position models a two-phase `reorder!`. New controller actions/routes add reorder, delete, and reset endpoints. The existing `reorder` Stimulus controller is generalized to drive three lists; a small `inline-edit` controller powers click-to-edit name. Views are rewritten to use drag handles, a red trash-can button, and instant toggles. Soft-delete of agenda items is removed entirely.

**Tech Stack:** Rails 8, Hotwire (Turbo + Stimulus), SortableJS (pinned via importmap), Minitest integration/model tests, plain CSS in `app/assets/tailwind/application.css`.

## Global Constraints

- Readability floor (visual design system): body/interactive text ≥ 16px, secondary ≥ 14px, labels ≥ 13px. Never tighten type for density.
- Dates render `DD MMM YYYY`, times 24-hour `HH:MM` (not relevant to this plan, but the standard).
- Any dev server MUST bind `0.0.0.0` (e.g. `bin/rails server -b 0.0.0.0`) — Andre works off-box.
- Trash/delete red uses the existing token `--color-legionred` (#8C1622). Do not introduce new ad-hoc colors.
- Keep Rails conventional; do not overbuild. No audit/enforcement machinery.
- Officer-facing copy: the seeded/default meeting types are called **"suggested"**; never surface "seeded", "inactive", "source_key", or "catalog" internals to users.
- Delete always means delete. No soft-delete anywhere in this feature.

---

### Task 1: `Reorderable` concern + model `reorder!` methods

**Files:**
- Create: `app/models/concerns/reorderable.rb`
- Modify: `app/models/meeting_type.rb`
- Modify: `app/models/meeting_type_agenda_item.rb`
- Test: `test/models/meeting_type_test.rb`, `test/models/meeting_type_agenda_item_test.rb`

**Interfaces:**
- Produces: `Reorderable.reorder_within!(scope, ordered_ids, column: :position)` — class method mixed in. `MeetingType.reorder!(organization, ordered_ids)` and `MeetingTypeAgendaItem.reorder!(meeting_type, ordered_ids)`. Each rewrites `position` to a contiguous `1..N` matching `ordered_ids`; raises `ActiveRecord::RecordNotFound` if any id is missing from the scope or `ordered_ids` has duplicates. `ordered_ids` must be the complete set for the scope.

- [ ] **Step 1: Write the failing model tests**

Append to `test/models/meeting_type_test.rb` (inside the class):

```ruby
  test "reorder! rewrites position to the given 1-based sequence" do
    a = @organization.meeting_types.create!(name: "PEC Meeting", position: 1, active: true)
    b = @organization.meeting_types.create!(name: "Membership Meeting", position: 2, active: true)
    c = @organization.meeting_types.create!(name: "Special Meeting", position: 3, active: true)

    MeetingType.reorder!(@organization, [ c.id, a.id, b.id ])

    assert_equal 1, c.reload.position
    assert_equal 2, a.reload.position
    assert_equal 3, b.reload.position
  end

  test "reorder! rejects ids outside the organization and changes nothing" do
    a = @organization.meeting_types.create!(name: "PEC Meeting", position: 1, active: true)
    b = @organization.meeting_types.create!(name: "Membership Meeting", position: 2, active: true)
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = other.meeting_types.create!(name: "Foreign", position: 1, active: true)

    assert_raises(ActiveRecord::RecordNotFound) do
      MeetingType.reorder!(@organization, [ a.id, foreign.id ])
    end

    assert_equal 1, a.reload.position
    assert_equal 2, b.reload.position
  end

  test "reorder! rejects duplicate ids" do
    a = @organization.meeting_types.create!(name: "PEC Meeting", position: 1, active: true)
    @organization.meeting_types.create!(name: "Membership Meeting", position: 2, active: true)

    assert_raises(ActiveRecord::RecordNotFound) do
      MeetingType.reorder!(@organization, [ a.id, a.id ])
    end
  end
```

Append to `test/models/meeting_type_agenda_item_test.rb` (inside the class):

```ruby
  test "reorder! rewrites item position to the given 1-based sequence" do
    entry2 = @organization.agenda_item_catalog_entries.create!(title: "Second", category: "ceremony", behavior_type: "scripted_ceremony", position: 2, active: true)
    entry3 = @organization.agenda_item_catalog_entries.create!(title: "Third", category: "ceremony", behavior_type: "scripted_ceremony", position: 3, active: true)
    a = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "A", active: true)
    b = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: entry2, position: 2, title: "B", active: true)
    c = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: entry3, position: 3, title: "C", active: true)

    MeetingTypeAgendaItem.reorder!(@meeting_type, [ c.id, a.id, b.id ])

    assert_equal 1, c.reload.position
    assert_equal 2, a.reload.position
    assert_equal 3, b.reload.position
  end

  test "reorder! rejects ids from another meeting type" do
    other_type = @organization.meeting_types.create!(name: "Other Type", position: 2, active: true)
    a = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "A", active: true)
    foreign_entry = @organization.agenda_item_catalog_entries.create!(title: "Foreign", category: "ceremony", behavior_type: "scripted_ceremony", position: 9, active: true)
    foreign = other_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: foreign_entry, position: 1, title: "F", active: true)

    assert_raises(ActiveRecord::RecordNotFound) do
      MeetingTypeAgendaItem.reorder!(@meeting_type, [ a.id, foreign.id ])
    end

    assert_equal 1, a.reload.position
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bin/rails test test/models/meeting_type_test.rb test/models/meeting_type_agenda_item_test.rb`
Expected: FAIL with `NoMethodError: undefined method 'reorder!'`.

- [ ] **Step 3: Create the concern**

Create `app/models/concerns/reorderable.rb`:

```ruby
module Reorderable
  extend ActiveSupport::Concern

  class_methods do
    # Rewrites `column` to a contiguous 1..N sequence matching ordered_ids,
    # within `scope`. ordered_ids must be the complete set of the scope's ids.
    # Two-phase (offset all rows above the current max, then set 1..N) so that
    # models with a UNIQUE index on the position column never collide
    # mid-transaction. Raises ActiveRecord::RecordNotFound if any id is missing
    # from the scope or ordered_ids contains duplicates. Atomic.
    def reorder_within!(scope, ordered_ids, column: :position)
      ids = Array(ordered_ids).map(&:to_i)
      records = scope.where(id: ids).index_by(&:id)
      raise ActiveRecord::RecordNotFound unless records.length == ids.length

      transaction do
        offset = (scope.maximum(column) || 0) + 1
        ids.each_with_index { |id, index| records.fetch(id).update!(column => offset + index) }
        ids.each_with_index { |id, index| records.fetch(id).update!(column => index + 1) }
      end
    end
  end
end
```

- [ ] **Step 4: Wire the concern into both models**

In `app/models/meeting_type.rb`, add after `belongs_to :organization` line — include the concern and a wrapper. Add `include Reorderable` near the top of the class body (after the `belongs_to`/`has_many` lines) and this class method (place it above the `def seeded?` method):

```ruby
  def self.reorder!(organization, ordered_ids)
    reorder_within!(organization.meeting_types, ordered_ids)
  end
```

In `app/models/meeting_type_agenda_item.rb`, add `include Reorderable` after the `has_rich_text :body` line, and add this class method (place it above `def self.create_from_catalog_entry!`):

```ruby
  def self.reorder!(meeting_type, ordered_ids)
    reorder_within!(meeting_type.meeting_type_agenda_items, ordered_ids)
  end
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bin/rails test test/models/meeting_type_test.rb test/models/meeting_type_agenda_item_test.rb`
Expected: PASS (all tests green).

- [ ] **Step 6: Commit**

```bash
git add app/models/concerns/reorderable.rb app/models/meeting_type.rb app/models/meeting_type_agenda_item.rb test/models/meeting_type_test.rb test/models/meeting_type_agenda_item_test.rb
git commit -m "feat: Reorderable concern with two-phase reorder! for meeting types and agenda items"
```

---

### Task 2: Seeder reset methods

**Files:**
- Modify: `app/services/meeting_type_template_seeder.rb`
- Test: `test/services/meeting_type_template_seeder_test.rb`

**Interfaces:**
- Produces: `MeetingTypeTemplateSeeder.reset_for!(organization)` — destroys the suggested meeting types (those whose `source_key` is in `MEETING_TYPES`) and their items, then re-seeds them to default. Leaves custom meeting types untouched. `MeetingTypeTemplateSeeder.reset_agenda_for!(meeting_type)` — destroys one suggested meeting type's agenda items and recreates them from its template definition; returns `false` (no-op) if the meeting type is not a known suggested type, `true` otherwise.

- [ ] **Step 1: Write the failing seeder tests**

Append to `test/services/meeting_type_template_seeder_test.rb` (inside the class; the file's existing setup creates `@organization`):

```ruby
  test "reset_for! restores suggested meeting types to defaults and leaves custom types" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    custom = @organization.meeting_types.create!(name: "Custom Meeting", position: 9, active: true)
    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    pec.meeting_type_agenda_items.first.destroy
    pec.update!(name: "Renamed PEC")

    MeetingTypeTemplateSeeder.reset_for!(@organization)

    assert @organization.meeting_types.exists?(custom.id), "custom types must survive reset"
    restored = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    assert_equal "PEC Meeting", restored.name
    assert_equal 5, restored.meeting_type_agenda_items.count
  end

  test "reset_agenda_for! restores one suggested type's items to default" do
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    pec.meeting_type_agenda_items.destroy_all

    assert MeetingTypeTemplateSeeder.reset_agenda_for!(pec)
    assert_equal 5, pec.reload.meeting_type_agenda_items.count
    assert_equal (1..5).to_a, pec.meeting_type_agenda_items.ordered.pluck(:position)
  end

  test "reset_agenda_for! is a no-op for a non-suggested meeting type" do
    custom = @organization.meeting_types.create!(name: "Custom Meeting", position: 1, active: true)

    assert_not MeetingTypeTemplateSeeder.reset_agenda_for!(custom)
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bin/rails test test/services/meeting_type_template_seeder_test.rb`
Expected: FAIL with `NoMethodError: undefined method 'reset_for!'`.

- [ ] **Step 3: Add the reset methods**

In `app/services/meeting_type_template_seeder.rb`, add these class methods next to `self.seed_for!` (after the `def self.defaults_missing?` method):

```ruby
  def self.reset_for!(organization)
    source_keys = MEETING_TYPES.map { |definition| definition.fetch(:source_key) }
    ApplicationRecord.transaction do
      organization.meeting_types.where(source_key: source_keys).destroy_all
      seed_for!(organization)
    end
  end

  def self.reset_agenda_for!(meeting_type)
    new(meeting_type.organization).reset_agenda!(meeting_type)
  end
```

And add this public instance method (place it after `def seed!`, before `private`):

```ruby
  def reset_agenda!(meeting_type)
    definition = MEETING_TYPES.find { |candidate| candidate.fetch(:source_key) == meeting_type.source_key }
    return false unless definition

    organization.with_lock do
      AgendaItemCatalogSeeder.seed_for!(organization)
      meeting_type.meeting_type_agenda_items.destroy_all
      definition.fetch(:item_source_keys).each_with_index do |catalog_source_key, index|
        seed_template_item(meeting_type, catalog_source_key, index + 1)
      end
    end
    true
  end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bin/rails test test/services/meeting_type_template_seeder_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/meeting_type_template_seeder.rb test/services/meeting_type_template_seeder_test.rb
git commit -m "feat: seeder reset_for! and reset_agenda_for! restore suggested defaults"
```

---

### Task 3: Meeting types controller — reorder, delete, reset actions + routes

**Files:**
- Modify: `config/routes.rb:44-49`
- Modify: `app/controllers/admin/meeting_types_controller.rb`
- Test: `test/controllers/admin/meeting_types_controller_test.rb`

**Interfaces:**
- Consumes: `MeetingType.reorder!` (Task 1), `MeetingTypeTemplateSeeder.reset_for!` / `reset_agenda_for!` (Task 2).
- Produces routes: `reorder_admin_meeting_types_path` (POST collection), `reset_defaults_admin_meeting_types_path` (POST collection), `reset_agenda_admin_meeting_type_path(meeting_type)` (POST member), `admin_meeting_type_path(meeting_type)` (DELETE). Flash copy: delete → "Meeting type deleted."; reset_defaults → "Suggested meeting types reset."; reset_agenda → "Agenda reset to the default items."

- [ ] **Step 1: Write the failing controller tests**

Append to `test/controllers/admin/meeting_types_controller_test.rb` (inside the class, before `private`):

```ruby
  test "destroy deletes a meeting type and its items" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    meeting_type = @organization.meeting_types.create!(name: "Doomed Meeting", position: 1, active: true)
    entry = @organization.agenda_item_catalog_entries.create!(title: "Item", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true)
    meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: entry, position: 1, title: "Item", active: true)

    assert_difference -> { @organization.meeting_types.count }, -1 do
      assert_difference -> { MeetingTypeAgendaItem.count }, -1 do
        delete admin_meeting_type_path(meeting_type)
      end
    end

    assert_redirected_to admin_meeting_types_path
    assert_equal "Meeting type deleted.", flash[:notice]
  end

  test "reorder persists the new meeting type order" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    a = @organization.meeting_types.create!(name: "First", position: 1, active: true)
    b = @organization.meeting_types.create!(name: "Second", position: 2, active: true)
    c = @organization.meeting_types.create!(name: "Third", position: 3, active: true)

    post reorder_admin_meeting_types_path, params: { ids: [ c.id, a.id, b.id ] }, as: :json

    assert_response :success
    assert_equal 1, c.reload.position
    assert_equal 2, a.reload.position
    assert_equal 3, b.reload.position
  end

  test "reorder rejects ids from another organization" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    a = @organization.meeting_types.create!(name: "First", position: 1, active: true)
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = other.meeting_types.create!(name: "Foreign", position: 1, active: true)

    post reorder_admin_meeting_types_path, params: { ids: [ a.id, foreign.id ] }, as: :json

    assert_response :unprocessable_entity
    assert_equal 1, a.reload.position
  end

  test "reset defaults restores suggested types and keeps custom ones" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    custom = @organization.meeting_types.create!(name: "Custom Meeting", position: 9, active: true)
    @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting").update!(name: "Renamed")

    post reset_defaults_admin_meeting_types_path

    assert_redirected_to admin_meeting_types_path
    assert_equal "Suggested meeting types reset.", flash[:notice]
    assert @organization.meeting_types.exists?(custom.id)
    assert_equal "PEC Meeting", @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting").name
  end

  test "reset agenda restores a suggested type's items" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    pec.meeting_type_agenda_items.destroy_all

    post reset_agenda_admin_meeting_type_path(pec)

    assert_redirected_to edit_admin_meeting_type_path(pec)
    assert_equal "Agenda reset to the default items.", flash[:notice]
    assert_equal 5, pec.reload.meeting_type_agenda_items.count
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bin/rails test test/controllers/admin/meeting_types_controller_test.rb`
Expected: FAIL with routing/`undefined local variable or method` errors for the new paths.

- [ ] **Step 3: Update routes**

In `config/routes.rb`, replace the `resources :meeting_types` block (currently lines ~44-49) with:

```ruby
    resources :meeting_types, except: %i[show] do
      post :seed_defaults, on: :collection
      post :reset_defaults, on: :collection
      post :reorder, on: :collection
      post :reset_agenda, on: :member
      resources :agenda_items, controller: "meeting_type_agenda_items", as: :agenda_items, only: %i[new create edit update destroy] do
        post :reorder, on: :collection
      end
    end
```

(This adds `destroy` by dropping it from `except`, adds the reset/reorder routes, and replaces the agenda_items `patch :move` member route with a `post :reorder` collection route.)

- [ ] **Step 4: Add the controller actions**

In `app/controllers/admin/meeting_types_controller.rb`, change the `set_meeting_type` before_action to cover the new member actions:

```ruby
    before_action :set_meeting_type, only: %i[edit update destroy reset_agenda]
```

Add these actions (place them after `def update ... end`, before `private`):

```ruby
    def destroy
      @meeting_type.destroy
      redirect_to admin_meeting_types_path, notice: "Meeting type deleted."
    end

    def reorder
      MeetingType.reorder!(@organization, params.require(:ids))
      head :ok
    rescue ActiveRecord::RecordNotFound
      head :unprocessable_entity
    end

    def reset_defaults
      MeetingTypeTemplateSeeder.reset_for!(@organization)
      redirect_to admin_meeting_types_path, notice: "Suggested meeting types reset."
    end

    def reset_agenda
      MeetingTypeTemplateSeeder.reset_agenda_for!(@meeting_type)
      redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Agenda reset to the default items."
    end
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bin/rails test test/controllers/admin/meeting_types_controller_test.rb`
Expected: PASS. (The existing `seed_defaults` and index tests still pass — `seed_defaults` route/action are unchanged.)

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/admin/meeting_types_controller.rb test/controllers/admin/meeting_types_controller_test.rb
git commit -m "feat: meeting type reorder, delete, and reset endpoints"
```

---

### Task 4: Agenda items controller — reorder + hard-delete (remove move/soft-delete)

**Files:**
- Modify: `app/controllers/admin/meeting_type_agenda_items_controller.rb`
- Test: `test/controllers/admin/meeting_type_agenda_items_controller_test.rb`

**Interfaces:**
- Consumes: `MeetingTypeAgendaItem.reorder!` (Task 1), the `agenda_items` `reorder` collection route (Task 3).
- Produces: `reorder_admin_meeting_type_agenda_items_path(meeting_type)` (POST collection). `destroy` always hard-deletes and flashes "Item removed from the agenda." The `move` action and its route are gone.

- [ ] **Step 1: Update the existing tests (they encode the old behavior)**

In `test/controllers/admin/meeting_type_agenda_items_controller_test.rb`:

Delete the entire `test "move item up and down swaps positions"` test (lines ~141-152).

Replace the `test "remove deactivates seeded template item and leaves catalog entry"` test with a hard-delete assertion:

```ruby
  test "remove hard-deletes a seeded template item and leaves the catalog entry" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: @catalog_entry.title, active: true, source_key: "american_legion_post:membership_meeting:regular_meeting.opening_ceremony", source_label: "Seed")

    assert_difference -> { @meeting_type.meeting_type_agenda_items.count }, -1 do
      delete admin_meeting_type_agenda_item_path(@meeting_type, item)
    end

    assert_equal 2, @organization.agenda_item_catalog_entries.count
    assert_redirected_to edit_admin_meeting_type_path(@meeting_type)
    assert_equal "Item removed from the agenda.", flash[:notice]
  end
```

Update the `test "remove deletes local template item and leaves catalog entry"` flash assertion from `"Template item removed."` to `"Item removed from the agenda."`.

Add a reorder test (inside the class, before `private`):

```ruby
  test "reorder persists the new item order" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    entry2 = @organization.agenda_item_catalog_entries.create!(title: "Second", category: "ceremony", behavior_type: "scripted_ceremony", position: 3, active: true)
    a = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "A", active: true)
    b = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: entry2, position: 2, title: "B", active: true)

    post reorder_admin_meeting_type_agenda_items_path(@meeting_type), params: { ids: [ b.id, a.id ] }, as: :json

    assert_response :success
    assert_equal 1, b.reload.position
    assert_equal 2, a.reload.position
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bin/rails test test/controllers/admin/meeting_type_agenda_items_controller_test.rb`
Expected: FAIL — the reorder route is undefined, the seeded-delete test expects hard delete, and the local-delete flash changed.

- [ ] **Step 3: Update the controller**

In `app/controllers/admin/meeting_type_agenda_items_controller.rb`:

Change the `set_item` before_action to drop `move`:

```ruby
    before_action :set_item, only: %i[edit update destroy]
```

Replace the `destroy` method body with an unconditional delete:

```ruby
    def destroy
      @item.destroy
      redirect_to edit_admin_meeting_type_path(@meeting_type), notice: "Item removed from the agenda."
    end
```

Delete the entire `move` method (lines ~55-72).

Add a `reorder` action (place it after `destroy`):

```ruby
    def reorder
      MeetingTypeAgendaItem.reorder!(@meeting_type, params.require(:ids))
      head :ok
    rescue ActiveRecord::RecordNotFound
      head :unprocessable_entity
    end
```

Leave `next_position` (still used by `create`) in place.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bin/rails test test/controllers/admin/meeting_type_agenda_items_controller_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/meeting_type_agenda_items_controller.rb test/controllers/admin/meeting_type_agenda_items_controller_test.rb
git commit -m "feat: agenda item reorder endpoint; delete always hard-deletes"
```

---

### Task 5: Generalize the reorder Stimulus controller + shared CSS + inline-edit controller

**Files:**
- Modify: `app/javascript/controllers/reorder_controller.js`
- Create: `app/javascript/controllers/inline_edit_controller.js`
- Modify: `app/views/admin/position_titles/index.html.erb:15` (row attributes)
- Modify: `app/assets/tailwind/application.css`
- Test: `test/controllers/admin/position_titles_controller_test.rb` (regression — must still pass unchanged)

**Interfaces:**
- Produces: reorder controller now reads draggable rows via `[data-reorder-item]` and their id via `data-reorder-id`, so any list (position titles, meeting types, agenda items) can use it. `inline-edit` controller with targets `display`, `form`, `field` and actions `edit`/`cancel`. Shared CSS classes: `.pos-handle` (grip, reused across lists), `.row-del` (red trash-can button), `.reorder-hint`.

- [ ] **Step 1: Generalize the reorder controller's row lookup**

In `app/javascript/controllers/reorder_controller.js`, replace the `rows()` method and the `save()` id extraction:

```javascript
  rows() {
    return Array.from(this.listTarget.querySelectorAll("[data-reorder-item]"))
  }

  async save() {
    const ids = this.rows().map((el) => el.dataset.reorderId)
```

(Only those two lines change — `data-position-id`/`dataset.positionId` become `data-reorder-item`/`dataset.reorderId`. The rest of the controller is unchanged.)

- [ ] **Step 2: Update the position titles rows to the new attributes**

In `app/views/admin/position_titles/index.html.erb`, change the row element (line ~15) from:

```erb
          <div class="pos" data-position-id="<%= title.id %>">
```

to:

```erb
          <div class="pos" data-reorder-item data-reorder-id="<%= title.id %>">
```

- [ ] **Step 3: Verify position titles still work (regression)**

Run: `bin/rails test test/controllers/admin/position_titles_controller_test.rb`
Expected: PASS (the request tests post ids directly and don't depend on the DOM attribute names).

- [ ] **Step 4: Create the inline-edit controller**

Create `app/javascript/controllers/inline_edit_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Click-to-edit for a single text field. Shows read-only display markup with an
// Edit button; on edit, hides the display and reveals a form (a normal Turbo
// form) with the field focused. Cancel restores the display without submitting.
// Saving is the form's own Turbo submit, which reloads the page in saved state.
export default class extends Controller {
  static targets = ["display", "form", "field"]

  connect() {
    this.showDisplay()
  }

  edit() {
    this.displayTarget.hidden = true
    this.formTarget.hidden = false
    this.fieldTarget.focus()
    this.fieldTarget.select()
  }

  cancel() {
    this.fieldTarget.value = this.fieldTarget.defaultValue
    this.showDisplay()
  }

  showDisplay() {
    this.displayTarget.hidden = false
    this.formTarget.hidden = true
  }
}
```

- [ ] **Step 5: Add the shared CSS**

Append to `app/assets/tailwind/application.css` (after the `.addrow` rule near line 371):

```css
/* Shared reorder + row actions (meeting types, agenda items) --------------- */
.reorder-hint { margin: 0 0 10px; }
.mrow-list [data-reorder-item] { cursor: default; }
.mrow .pos-handle { margin-right: 4px; }
.mrow-id { display: block; }
a.mrow-id { text-decoration: none; color: inherit; }
a.mrow-id:hover .mrow-name { text-decoration: underline; }
.row-del { display: inline-flex; align-items: center; justify-content: center; width: 40px; height: 40px; padding: 0; margin: 0; border: 1.5px solid transparent; border-radius: 8px; background: none; color: var(--color-legionred); cursor: pointer; }
.row-del:hover, .row-del:focus-visible { background: #fbeceb; border-color: var(--color-legionred); outline: none; }
.row-del svg { width: 20px; height: 20px; display: block; }
.row-del form { margin: 0; }
```

- [ ] **Step 6: Rebuild CSS and boot-check**

Run: `bin/rails test test/controllers/admin/position_titles_controller_test.rb` (still green) and confirm the app boots: `bin/rails runner "puts 'ok'"`
Expected: `ok` and green tests. (Full visual verification of drag happens in Task 8.)

- [ ] **Step 7: Commit**

```bash
git add app/javascript/controllers/reorder_controller.js app/javascript/controllers/inline_edit_controller.js app/views/admin/position_titles/index.html.erb app/assets/tailwind/application.css
git commit -m "feat: generalize reorder controller, add inline-edit controller and shared row CSS"
```

---

### Task 6: Meeting Types index view — drag reorder, delete, suggested buttons

**Files:**
- Modify: `app/views/admin/meeting_types/index.html.erb`
- Test: `test/controllers/admin/meeting_types_controller_test.rb`

**Interfaces:**
- Consumes: `reorder_admin_meeting_types_path`, `admin_meeting_type_path` (DELETE), `seed_defaults_admin_meeting_types_path`, `reset_defaults_admin_meeting_types_path`, the `reorder`/`inline-edit` Stimulus controllers, `.pos-handle`/`.row-del` CSS (Task 5), `@default_meeting_types_missing` (already set by `index`).

- [ ] **Step 1: Add request-test assertions for the new controls**

Append to `test/controllers/admin/meeting_types_controller_test.rb` (inside the class, before `private`):

```ruby
  test "index shows drag reorder, delete, and reset suggested when defaults present" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    MeetingTypeTemplateSeeder.seed_for!(@organization)

    get admin_meeting_types_path

    assert_response :success
    assert_select "[data-controller='reorder']"
    assert_select ".pos-handle"
    assert_select "form[action=?][method=?]", reset_defaults_admin_meeting_types_path, "post"
    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    assert_select "form[action=?]", admin_meeting_type_path(pec)
  end

  test "index shows add suggested when defaults are missing" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    @organization.meeting_types.create!(name: "Custom Only", position: 1, active: true)

    get admin_meeting_types_path

    assert_response :success
    assert_select "form[action=?][method=?]", seed_defaults_admin_meeting_types_path, "post"
    assert_select "form[action=?]", reset_defaults_admin_meeting_types_path, count: 0
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bin/rails test test/controllers/admin/meeting_types_controller_test.rb -n "/index shows/"`
Expected: FAIL — no `[data-controller='reorder']`, no reset form.

- [ ] **Step 3: Rewrite the index view**

Replace the entire contents of `app/views/admin/meeting_types/index.html.erb` with:

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
  <% if @default_meeting_types_missing %>
    <%= button_to "Add suggested", seed_defaults_admin_meeting_types_path, method: :post, class: "btn-secondary" %>
  <% else %>
    <%= button_to "Reset suggested", reset_defaults_admin_meeting_types_path, method: :post, class: "btn-secondary",
          data: { turbo_confirm: "Reset the suggested meeting types back to their defaults? Your changes to them will be lost." } %>
  <% end %>
  <%= link_to "Agenda Item Catalog", admin_agenda_item_catalog_entries_path, class: "btn-secondary" %>
</div>

<% if @meeting_types.present? %>
  <p class="page-sub reorder-hint">Drag a row by its handle to change the order. Changes save automatically.</p>
  <div data-controller="reorder" data-reorder-url-value="<%= reorder_admin_meeting_types_path %>">
    <div class="mrow-list" data-reorder-target="list">
      <% @meeting_types.each do |meeting_type| %>
        <div class="mrow catrow<%= ' mrow--inactive' unless meeting_type.active? %>" data-reorder-item data-reorder-id="<%= meeting_type.id %>">
          <button type="button" class="pos-handle" aria-label="Drag to reorder <%= meeting_type.name %>">
            <svg width="12" height="18" viewBox="0 0 12 18" aria-hidden="true" focusable="false">
              <g fill="currentColor">
                <circle cx="3" cy="3" r="1.6"/><circle cx="9" cy="3" r="1.6"/>
                <circle cx="3" cy="9" r="1.6"/><circle cx="9" cy="9" r="1.6"/>
                <circle cx="3" cy="15" r="1.6"/><circle cx="9" cy="15" r="1.6"/>
              </g>
            </svg>
          </button>
          <%= link_to edit_admin_meeting_type_path(meeting_type), class: "mrow-id", aria: { label: "Edit #{meeting_type.name}" } do %>
            <span class="mrow-name"><%= meeting_type.name %></span>
            <span class="mrow-sub"><%= pluralize(meeting_type.meeting_type_agenda_items.size, "template item") %></span>
          <% end %>
          <div class="catrow-meta">
            <% unless meeting_type.active? %><%= agenda_active_tag(false) %><% end %>
            <%= link_to "Edit", edit_admin_meeting_type_path(meeting_type), class: "catrow-edit" %>
            <%= button_to admin_meeting_type_path(meeting_type), method: :delete, class: "row-del",
                  aria: { label: "Delete #{meeting_type.name}" },
                  data: { turbo_confirm: "Delete “#{meeting_type.name}”? This removes the meeting type and its template agenda." } do %>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true" focusable="false">
                <path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2m2 0v14a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V6" stroke-linecap="round" stroke-linejoin="round"/>
                <path d="M10 11v6M14 11v6" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    <span class="pos-status" data-reorder-target="status" role="status" aria-live="polite"></span>
  </div>
<% else %>
  <p class="page-sub">No meeting types yet.</p>
<% end %>
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bin/rails test test/controllers/admin/meeting_types_controller_test.rb`
Expected: PASS (new `index shows...` tests green; the existing "index is read-only" test still passes — the seed form is still present when defaults are missing).

- [ ] **Step 5: Commit**

```bash
git add app/views/admin/meeting_types/index.html.erb test/controllers/admin/meeting_types_controller_test.rb
git commit -m "feat: meeting types index drag reorder, delete, suggested add/reset buttons"
```

---

### Task 7: Meeting Type edit view — inline name, active toggle, agenda drag/trash, reset agenda

**Files:**
- Modify: `app/views/admin/meeting_types/edit.html.erb`
- Modify: `app/assets/tailwind/application.css` (inline-edit + edit-head styles)
- Test: `test/controllers/admin/meeting_types_controller_test.rb`, `test/controllers/admin/meeting_type_agenda_items_controller_test.rb`

**Interfaces:**
- Consumes: `admin_meeting_type_path` (PATCH via `form_with model`), `reset_agenda_admin_meeting_type_path`, `reorder_admin_meeting_type_agenda_items_path`, `admin_meeting_type_agenda_item_path` (DELETE), the `inline-edit`/`reorder` controllers, `.row-del`/`.pos-handle` CSS. `@meeting_type` and `@template_items` are already set by `edit`.

- [ ] **Step 1: Add request-test assertions for the edit page controls**

Append to `test/controllers/admin/meeting_types_controller_test.rb` (inside the class, before `private`):

```ruby
  test "edit page has inline name edit and instant active toggle" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)

    get edit_admin_meeting_type_path(meeting_type)

    assert_response :success
    assert_select "[data-controller='inline-edit']"
    assert_select "input[name=?]", "meeting_type[name]"
    assert_select "form[action=?]", admin_meeting_type_path(meeting_type)
    # instant toggle posts only the active flag via PATCH
    assert_select "form.mt-active-form input[name=?][value=?]", "meeting_type[active]", "false"
  end

  test "edit page shows reset agenda only for suggested types" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    MeetingTypeTemplateSeeder.seed_for!(@organization)
    pec = @organization.meeting_types.find_by!(source_key: "american_legion_post:pec_meeting")
    custom = @organization.meeting_types.create!(name: "Custom Meeting", position: 9, active: true)

    get edit_admin_meeting_type_path(pec)
    assert_select "form[action=?]", reset_agenda_admin_meeting_type_path(pec)

    get edit_admin_meeting_type_path(custom)
    assert_select "form[action=?]", reset_agenda_admin_meeting_type_path(custom), count: 0
  end
```

Append to `test/controllers/admin/meeting_type_agenda_items_controller_test.rb` (inside the class, before `private`):

```ruby
  test "edit page renders draggable agenda rows with trash buttons" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: @catalog_entry, position: 1, title: "Opening", active: true)

    get edit_admin_meeting_type_path(@meeting_type)

    assert_response :success
    assert_select "[data-controller='reorder'] [data-reorder-item][data-reorder-id='#{item.id}']"
    assert_select ".pos-handle"
    assert_select "form[action=?][method=?]", admin_meeting_type_agenda_item_path(@meeting_type, item), "post"
  end
```

Note: the existing test `edit form hides developer fields` asserts `input[name='meeting_type[name]']` and `input[name='meeting_type[active]']` are present and `slug`/`position` absent. The new markup keeps a `name` input (inside the inline-edit form) and an `active` hidden input (inside the toggle `button_to`), and still emits no `slug`/`position` inputs — so that test stays valid.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bin/rails test test/controllers/admin/meeting_types_controller_test.rb -n "/edit page/" test/controllers/admin/meeting_type_agenda_items_controller_test.rb -n "/draggable agenda rows/"`
Expected: FAIL — no `inline-edit` controller, no `.mt-active-form`, no reorder wrapper on items.

- [ ] **Step 3: Rewrite the edit view**

Replace the entire contents of `app/views/admin/meeting_types/edit.html.erb` with:

```erb
<% content_for :title, "Edit #{@meeting_type.name}" %>
<a class="back" href="<%= admin_meeting_types_path %>">&larr; Meeting Types</a>

<div class="mt-head" data-controller="inline-edit">
  <div class="mt-head-name" data-inline-edit-target="display">
    <h1 class="page-title"><%= @meeting_type.name %></h1>
    <button type="button" class="mt-edit-btn" data-action="inline-edit#edit" aria-label="Rename this meeting type">
      <svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true" focusable="false">
        <path d="M12 20h9" stroke-linecap="round"/>
        <path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
      Edit
    </button>
  </div>

  <%= form_with model: [ :admin, @meeting_type ], class: "mt-head-form", data: { inline_edit_target: "form" } do |form| %>
    <% if @meeting_type.errors.any? %>
      <div class="error-summary">
        <h2><%= pluralize(@meeting_type.errors.count, "error") %> prohibited this meeting type from being saved:</h2>
        <ul>
          <% @meeting_type.errors.full_messages.each do |message| %><li><%= message %></li><% end %>
        </ul>
      </div>
    <% end %>
    <%= form.label :name, "Meeting name", class: "fl-label-inline" %>
    <div class="mt-head-editrow">
      <%= form.text_field :name, class: "f", data: { inline_edit_target: "field" } %>
      <%= form.submit "Save", class: "btn-primary" %>
      <button type="button" class="btn-secondary" data-action="inline-edit#cancel">Cancel</button>
    </div>
  <% end %>

  <div class="mt-active">
    <span class="state <%= @meeting_type.active? ? "on" : "off" %>"><%= @meeting_type.active? ? "Active" : "Inactive" %></span>
    <%= button_to @meeting_type.active? ? "Deactivate" : "Activate", admin_meeting_type_path(@meeting_type), method: :patch,
          params: { meeting_type: { active: !@meeting_type.active? } }, class: "toggle", form: { class: "mt-active-form" } %>
    <span class="mt-active-help">Inactive meeting types stay in the list but are hidden from routine use.</span>
  </div>
</div>

<div class="sec-head-row" style="margin-top: 22px">
  <%= render "shared/section_header", label: "Template agenda" %>
</div>

<div class="btnrow" style="margin-top: 12px">
  <%= link_to "Add catalog item", new_admin_meeting_type_agenda_item_path(@meeting_type), class: "btn-primary" %>
  <% if @meeting_type.seeded? %>
    <%= button_to "Reset agenda to default", reset_agenda_admin_meeting_type_path(@meeting_type), method: :post, class: "btn-secondary",
          data: { turbo_confirm: "Reset this agenda back to the default items? Your changes to this agenda will be lost." } %>
  <% end %>
</div>

<% if @template_items.present? %>
  <p class="page-sub reorder-hint">Drag a row by its handle to change the order. Changes save automatically.</p>
  <div data-controller="reorder" data-reorder-url-value="<%= reorder_admin_meeting_type_agenda_items_path(@meeting_type) %>">
    <div class="mrow-list" data-reorder-target="list">
      <% @template_items.each do |item| %>
        <div class="mrow catrow" data-reorder-item data-reorder-id="<%= item.id %>">
          <button type="button" class="pos-handle" aria-label="Drag to reorder <%= item.title %>">
            <svg width="12" height="18" viewBox="0 0 12 18" aria-hidden="true" focusable="false">
              <g fill="currentColor">
                <circle cx="3" cy="3" r="1.6"/><circle cx="9" cy="3" r="1.6"/>
                <circle cx="3" cy="9" r="1.6"/><circle cx="9" cy="9" r="1.6"/>
                <circle cx="3" cy="15" r="1.6"/><circle cx="9" cy="15" r="1.6"/>
              </g>
            </svg>
          </button>
          <span class="mrow-id">
            <span class="mrow-name"><%= item.title %></span>
            <% if item.summary.present? %><span class="mrow-sub"><%= item.summary %></span><% end %>
          </span>
          <div class="catrow-meta">
            <%= link_to "Edit", edit_admin_meeting_type_agenda_item_path(@meeting_type, item), class: "catrow-edit" %>
            <%= button_to admin_meeting_type_agenda_item_path(@meeting_type, item), method: :delete, class: "row-del",
                  aria: { label: "Remove #{item.title}" },
                  data: { turbo_confirm: "Remove “#{item.title}” from the agenda?" } do %>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true" focusable="false">
                <path d="M3 6h18M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2m2 0v14a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V6" stroke-linecap="round" stroke-linejoin="round"/>
                <path d="M10 11v6M14 11v6" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    <span class="pos-status" data-reorder-target="status" role="status" aria-live="polite"></span>
  </div>
<% else %>
  <p class="page-sub">No template items yet. Use “Add catalog item” to build this agenda.</p>
<% end %>
```

- [ ] **Step 4: Add the edit-head CSS**

Append to `app/assets/tailwind/application.css`:

```css
/* Meeting type edit head: click-to-edit name + instant active toggle -------- */
.mt-head { margin-bottom: 18px; }
.mt-head-name { display: flex; align-items: center; gap: 14px; }
.mt-edit-btn { display: inline-flex; align-items: center; gap: 6px; font-size: 15px; font-weight: 700; color: var(--color-navy); background: #fff; border: 1.5px solid #cbb98a; border-radius: 6px; padding: 6px 12px; cursor: pointer; }
.mt-edit-btn:hover, .mt-edit-btn:focus-visible { background: var(--color-navy); border-color: var(--color-navy); color: #fff; outline: none; }
.mt-head-form { margin: 0; }
.fl-label-inline { display: block; font-size: 13px; letter-spacing: .1em; text-transform: uppercase; color: var(--color-muted); margin-bottom: 4px; }
.mt-head-editrow { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
.mt-head-editrow .f { font-size: 18px; padding: 8px 10px; border: 1px solid #cdbf98; border-radius: 6px; background: #fff; color: var(--color-ink); min-width: 260px; }
.mt-active { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; margin-top: 12px; }
.mt-active .state { font-size: 14px; font-weight: 600; }
.mt-active .state.on { color: var(--color-green); }
.mt-active .state.off { color: var(--color-muted); }
.mt-active .toggle { font-size: 16px; color: var(--color-navy); text-decoration: underline; cursor: pointer; background: none; border: none; padding: 0; font-family: inherit; }
.mt-active-form { margin: 0; }
.mt-active-help { font-size: 14px; color: var(--color-muted); }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bin/rails test test/controllers/admin/meeting_types_controller_test.rb test/controllers/admin/meeting_type_agenda_items_controller_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/views/admin/meeting_types/edit.html.erb app/assets/tailwind/application.css test/controllers/admin/meeting_types_controller_test.rb test/controllers/admin/meeting_type_agenda_items_controller_test.rb
git commit -m "feat: meeting type edit inline name, instant toggle, agenda drag/trash, reset agenda"
```

---

### Task 8: Full-suite verification + manual visual check

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `bin/rails test`
Expected: All green. If any unrelated test references the removed `move` route or old flash strings, fix the assertion to match the new behavior (there should be none beyond the ones updated in Tasks 4/6/7).

- [ ] **Step 2: Boot the app for manual verification**

Run: `bin/dev` (or `bin/rails server -b 0.0.0.0`) — the server MUST bind `0.0.0.0` so Andre can reach it off-box at `192.168.37.41`.

- [ ] **Step 3: Manually verify each interaction**

Sign in as a `manage_agendas` user and check:
1. Meeting Types index: drag a row by its handle → order persists on reload; status line shows "Order saved".
2. Index trash-can deletes a meeting type after confirm.
3. With suggested types present, "Reset suggested" restores defaults; with a fresh org, "Add suggested" appears instead.
4. Edit page: name shows as heading with an Edit button → click reveals the field + Save/Cancel; Save renames (flash "Meeting type updated."); Cancel restores without change.
5. Edit page Active toggle flips instantly (no page-level form submit) and the state label updates on reload.
6. Edit page agenda: drag reorders items; trash-can removes an item after confirm; "Reset agenda to default" appears only on suggested types and restores the default items.
7. Confirm no console errors; readability holds (name field ≥16px, labels ≥13px).

- [ ] **Step 4: Commit any assertion fixes from Step 1 (if needed)**

```bash
git add -A
git commit -m "test: align remaining assertions with meeting types refresh"
```

---

## Self-Review Notes

- **Spec coverage:** Index reorder/delete (Tasks 3, 6); suggested add/reset labels + semantics (Tasks 2, 3, 6); edit click-to-edit name + instant toggle (Tasks 5, 7); agenda drag reorder + true-delete trash (Tasks 1, 4, 5, 7); reset-agenda-to-default (Tasks 2, 3, 7); removal of soft-delete/inactive-in-list (Task 4, and item rows no longer render the inactive tag/flag in Task 7); shared `Reorderable` concern (Task 1); progressive enhancement (Turbo `button_to`/form fallbacks throughout, drag is enhancement only). All spec sections map to a task.
- **Two-phase reorder** is required because both `meeting_types.position` and `meeting_type_agenda_items.position` have UNIQUE indexes (verified in `db/schema.rb`) — the one-shot rewrite `PositionTitle` uses would collide.
- **No system tests:** the project has no `test/system` directory or JS test harness, so drag-drop is verified manually in Task 8; all server behavior is covered by model + request tests.
- **Red token:** `--color-legionred` is the defined token; `--color-red` is not defined and is avoided.
```
