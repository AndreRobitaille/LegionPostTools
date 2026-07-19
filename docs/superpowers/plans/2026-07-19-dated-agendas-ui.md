# Dated Agendas UI Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the project's visual design system to every un-styled dated-agenda view, convert item reordering to drag-and-drop, fix the site-wide date format, and give print a real stylesheet — so the feature reads as finished.

**Architecture:** Pure UI/server pass on an existing, tested feature. Reuse infrastructure already on `main`: the `Reorderable` concern, the generalized `reorder` Stimulus controller (no JS changes), the shared drag/trash row CSS, the `.st` status-tag component, and the `test/system` harness. The redesigned `admin/meeting_types/edit` is the markup reference for the management screen's item list.

**Tech Stack:** Rails 8.1, ERB views, Tailwind v4 (custom classes in `app/assets/tailwind/application.css` → built to `app/assets/builds/tailwind.css`), Stimulus + SortableJS, Minitest (request + system tests via Capybara/headless Chromium).

## Global Constraints

- **Readability floor:** body/interactive text ≥ 16px, secondary ≥ 14px, labels ≥ 13px. Never go below 13px. (`docs/superpowers/specs/2026-07-11-visual-design-system-design.md`)
- **Date/time format:** dates render `DD MMM YYYY` (e.g. `19 JUL 2026`), times 24-hour `HH:MM`, via `LegionFormatHelper` (`legion_date`, `legion_time`, `legion_datetime`). Never `l(..., format: :long)` or ad-hoc `strftime` for display.
- **No full-width UI:** keep an item's status and actions grouped with the item (the `.mrow`/`.catrow-meta` pattern), never stranded across a stretched row.
- **Reuse, don't reinvent:** use the `Reorderable` concern, the existing `reorder` Stimulus controller, and the shared `.pos-handle`/`.row-del`/`.reorder-hint` CSS. Do not add a new reorder controller or new row CSS.
- **Design-system vocabulary only:** `content_for :title`, `.back`, `.page-lead`/`.page-title`/`.page-sub`, `.btnrow`/`.btn-primary`/`.btn-secondary`, `.mrow-list`/`.mrow`/`.catrow`/`.mrow-id`/`.mrow-name`/`.mrow-sub`/`.catrow-meta`/`.catrow-edit`, `.stacked-form`/`.fl`/`.f`/`.fl-help`/`.error-summary`, `.st`/`.st-dot`, `.sec-head-row` + `shared/section_header`, `.readonly-tip`.
- **Build step:** after editing `application.css`, run `bin/rails tailwindcss:build` (the test task also rebuilds automatically).

---

### Task 1: Lifecycle status tag helper + CSS variants

**Files:**
- Modify: `app/helpers/status_display_helper.rb`
- Modify: `app/assets/tailwind/application.css` (near the existing `.st--other` block, ~line 204)
- Test: `test/helpers/status_display_helper_test.rb`

**Interfaces:**
- Produces: `dated_agenda_status_tag(status)` → HTML-safe `<span class="st st--draft|st--approved|st--published|st--other"><span class="st-dot"></span>Label</span>`. Used by Tasks 4 and 6.

- [ ] **Step 1: Write the failing test**

Append to `test/helpers/status_display_helper_test.rb` (inside the class):

```ruby
test "dated agenda draft status renders the draft variant" do
  frag = Nokogiri::HTML::DocumentFragment.parse(dated_agenda_status_tag("draft"))
  assert_select frag, "span.st.st--draft", text: /Draft/
  assert_select frag, "span.st--draft .st-dot"
end

test "dated agenda approved status renders the approved variant" do
  frag = Nokogiri::HTML::DocumentFragment.parse(dated_agenda_status_tag("approved"))
  assert_select frag, "span.st.st--approved", text: /Approved/
end

test "dated agenda published status renders the published variant" do
  frag = Nokogiri::HTML::DocumentFragment.parse(dated_agenda_status_tag("published"))
  assert_select frag, "span.st.st--published", text: /Published/
end

test "dated agenda unknown status falls back to the muted variant with a titleized label" do
  frag = Nokogiri::HTML::DocumentFragment.parse(dated_agenda_status_tag("archived"))
  assert_select frag, "span.st.st--other", text: /Archived/
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/helpers/status_display_helper_test.rb`
Expected: FAIL with `NoMethodError: undefined method 'dated_agenda_status_tag'`

- [ ] **Step 3: Implement the helper**

In `app/helpers/status_display_helper.rb`, add inside the module (after `agenda_active_tag`):

```ruby
  def dated_agenda_status_tag(status)
    variant, label =
      case status.to_s
      when "draft" then [ "st--draft", "Draft" ]
      when "approved" then [ "st--approved", "Approved" ]
      when "published" then [ "st--published", "Published" ]
      else [ "st--other", status.to_s.titleize ]
      end

    tag.span(class: "st #{variant}") do
      tag.span("", class: "st-dot") + label
    end
  end
```

- [ ] **Step 4: Add the CSS variants**

In `app/assets/tailwind/application.css`, immediately after the `.st--other .st-dot` rule (~line 204):

```css
.st--draft { color: var(--color-muted); }
.st--draft .st-dot { background: var(--color-muted); }
.st--approved { color: var(--color-gold-ink); }
.st--approved .st-dot { background: var(--color-gold); }
.st--published { color: var(--color-green); }
.st--published .st-dot { background: var(--color-green); }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/helpers/status_display_helper_test.rb`
Expected: PASS (all status_display_helper tests green)

- [ ] **Step 6: Commit**

```bash
git add app/helpers/status_display_helper.rb app/assets/tailwind/application.css test/helpers/status_display_helper_test.rb
git commit -m "feat: dated agenda lifecycle status tag helper and CSS"
```

---

### Task 2: `DatedAgendaItem.reorder!` via the Reorderable concern

**Files:**
- Modify: `app/models/dated_agenda_item.rb`
- Test: `test/models/dated_agenda_item_test.rb`

**Interfaces:**
- Consumes: `Reorderable.reorder_within!(scope, ordered_ids, column: :position)` (already on `main`).
- Produces: `DatedAgendaItem.reorder!(dated_agenda, ordered_ids)` — rewrites `position` to a contiguous 1..N sequence in the given `ordered_ids` order; raises `ActiveRecord::RecordNotFound` if `ordered_ids` is not exactly the agenda's item ids. Used by Task 3.

- [ ] **Step 1: Write the failing test**

Append to `test/models/dated_agenda_item_test.rb` (inside the class). The setup already provides `@agenda` (from `create_from_template!` this agenda has no items; build two here):

```ruby
test "reorder! rewrites positions to match the given id order" do
  entry_a = @organization.agenda_item_catalog_entries.create!(title: "A", category: "reports", behavior_type: "report_slot", position: 10, active: true)
  entry_b = @organization.agenda_item_catalog_entries.create!(title: "B", category: "reports", behavior_type: "report_slot", position: 11, active: true)
  first = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_a, position: 1, title: "A", behavior_type: "report_slot", active: true)
  second = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_b, position: 2, title: "B", behavior_type: "report_slot", active: true)

  DatedAgendaItem.reorder!(@agenda, [ second.id, first.id ])

  assert_equal 1, second.reload.position
  assert_equal 2, first.reload.position
end

test "reorder! raises when the id set does not match the agenda's items" do
  entry_a = @organization.agenda_item_catalog_entries.create!(title: "A", category: "reports", behavior_type: "report_slot", position: 10, active: true)
  only = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: entry_a, position: 1, title: "A", behavior_type: "report_slot", active: true)

  assert_raises(ActiveRecord::RecordNotFound) do
    DatedAgendaItem.reorder!(@agenda, [ only.id, 999_999 ])
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/dated_agenda_item_test.rb`
Expected: FAIL with `NoMethodError: undefined method 'reorder!' for class DatedAgendaItem`

- [ ] **Step 3: Implement**

In `app/models/dated_agenda_item.rb`, add the concern include just under the class definition (with the other includes / associations) and the class method. Add near the top of the class body:

```ruby
  include Reorderable
```

And add with the other `def self.` methods:

```ruby
  def self.reorder!(dated_agenda, ordered_ids)
    reorder_within!(dated_agenda.dated_agenda_items, ordered_ids)
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/dated_agenda_item_test.rb`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/models/dated_agenda_item.rb test/models/dated_agenda_item_test.rb
git commit -m "feat: DatedAgendaItem.reorder! via Reorderable concern"
```

---

### Task 3: Reorder endpoint; remove the Up/Down `move` path

**Files:**
- Modify: `config/routes.rb` (the admin dated-agenda `agenda_items` block)
- Modify: `app/controllers/admin/dated_agenda_items_controller.rb`
- Test: `test/controllers/admin/dated_agenda_items_controller_test.rb`

**Interfaces:**
- Consumes: `DatedAgendaItem.reorder!` (Task 2).
- Produces: `POST /admin/dated_agendas/:dated_agenda_id/agenda_items/reorder` → `reorder_admin_dated_agenda_agenda_items_path`. Body `{ ids: [...] }`, returns `head :ok` / `head :unprocessable_entity`. Used by Task 6's view.

- [ ] **Step 1: Update the route**

In `config/routes.rb`, in the admin `dated_agendas` block, change the nested agenda-items resource from:

```ruby
      resources :agenda_items, controller: "dated_agenda_items", as: :agenda_items, only: %i[new create edit update destroy] do
        patch :move, on: :member
      end
```

to:

```ruby
      resources :agenda_items, controller: "dated_agenda_items", as: :agenda_items, only: %i[new create edit update destroy] do
        post :reorder, on: :collection
      end
```

- [ ] **Step 2: Write the failing tests**

In `test/controllers/admin/dated_agenda_items_controller_test.rb`, **delete** the two `move` tests (`"move item up and down swaps positions"` and `"move stops cleanly if agenda becomes locked"`) and add:

```ruby
  test "reorder rewrites item positions for a draft agenda" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    second_entry = @organization.agenda_item_catalog_entries.create!(title: "Commander Report", slug: "commander-report-2", category: "reports", behavior_type: "report_slot", position: 2, active: true)
    second = @agenda.dated_agenda_items.create!(agenda_item_catalog_entry: second_entry, position: 2, title: "Commander Report", behavior_type: "report_slot", active: true)
    first = @agenda.dated_agenda_items.ordered.first

    post reorder_admin_dated_agenda_agenda_items_path(@agenda), params: { ids: [ second.id, first.id ] }, as: :json

    assert_response :ok
    assert_equal 1, second.reload.position
    assert_equal 2, first.reload.position
  end

  test "reorder with a bad id set is rejected" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @agenda.dated_agenda_items.first

    post reorder_admin_dated_agenda_agenda_items_path(@agenda), params: { ids: [ item.id, 999_999 ] }, as: :json

    assert_response :unprocessable_entity
  end

  test "reorder is blocked on a locked agenda" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    item = @agenda.dated_agenda_items.first
    @agenda.approve!(User.last)

    post reorder_admin_dated_agenda_agenda_items_path(@agenda), params: { ids: [ item.id ] }, as: :json

    assert_redirected_to edit_admin_dated_agenda_path(@agenda)
    assert_equal "Reopen this agenda before editing items.", flash[:alert]
  end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/dated_agenda_items_controller_test.rb`
Expected: FAIL — `reorder_admin_dated_agenda_agenda_items_path` undefined / action missing.

- [ ] **Step 4: Update the controller**

In `app/controllers/admin/dated_agenda_items_controller.rb`:

1. Change the `set_item` filter line from `only: %i[edit update destroy move]` to `only: %i[edit update destroy]`.
2. Change the `ensure_draft_agenda` filter line from `only: %i[new create edit update destroy move]` to `only: %i[new create edit update destroy reorder]`.
3. **Delete** the entire `def move ... end` action.
4. Add the `reorder` action (place it after `destroy`):

```ruby
    def reorder
      DatedAgendaItem.reorder!(@dated_agenda, params.require(:ids))
      head :ok
    rescue ActiveRecord::RecordNotFound
      head :unprocessable_entity
    end
```

Note: `ensure_draft_agenda` already redirects locked agendas with the "Reopen this agenda before editing items." alert, satisfying the locked-agenda test.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/dated_agenda_items_controller_test.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add config/routes.rb app/controllers/admin/dated_agenda_items_controller.rb test/controllers/admin/dated_agenda_items_controller_test.rb
git commit -m "feat: dated agenda item reorder endpoint; remove Up/Down move"
```

---

### Task 4: Admin index redesign

**Files:**
- Modify: `app/views/admin/dated_agendas/index.html.erb`
- Test: `test/controllers/admin/dated_agendas_controller_test.rb`

- [ ] **Step 1a: Add a reusable `@agenda` to the admin test setup**

The `Admin::DatedAgendasControllerTest` setup creates `@organization`, `@meeting_body`, `@meeting_type`, and a template item, but **no dated agenda**. Add one at the end of its `setup do ... end` block so Tasks 4, 6, and 8 can reuse it (existing tests don't reference `@agenda`, so this is safe):

```ruby
    @agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))
```

`create_from_template!` copies the template's one item, so `@agenda` has a draft item for the list assertions.

- [ ] **Step 1b: Write the failing test**

Add to `test/controllers/admin/dated_agendas_controller_test.rb`:

```ruby
  test "index renders agendas in the design system with a status tag and house date format" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get admin_dated_agendas_path

    assert_response :success
    assert_select ".page-lead .page-title", text: "Dated Agendas"
    assert_select ".mrow-list .mrow.catrow .mrow-name"
    assert_select ".mrow-list .catrow-meta .st"
    assert_select "a.btn-primary", text: "New dated agenda"
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/admin/dated_agendas_controller_test.rb -n /index renders agendas/`
Expected: FAIL (no `.mrow-list`, no `.st` — current view is bare `<ul>`)

- [ ] **Step 3: Rewrite the view**

Replace `app/views/admin/dated_agendas/index.html.erb` entirely:

```erb
<% content_for :title, "Dated Agendas" %>
<a class="back" href="<%= admin_root_path %>">&larr; Administration</a>

<div class="page-lead">
  <h1 class="page-title">Dated Agendas</h1>
  <p class="page-sub">Agendas for specific meeting dates, built from your meeting type templates.</p>
</div>

<div class="btnrow">
  <%= link_to "New dated agenda", new_admin_dated_agenda_path, class: "btn-primary" %>
</div>

<% if @dated_agendas.any? %>
  <div class="mrow-list">
    <% @dated_agendas.each do |dated_agenda| %>
      <%= link_to edit_admin_dated_agenda_path(dated_agenda), class: "mrow catrow", aria: { label: "Open #{dated_agenda.title}" } do %>
        <span class="mrow-id">
          <span class="mrow-name"><%= dated_agenda.title %></span>
          <span class="mrow-sub"><%= dated_agenda.meeting_body.name %> &middot; <%= legion_datetime(dated_agenda.starts_at) %></span>
        </span>
        <span class="catrow-meta">
          <%= dated_agenda_status_tag(dated_agenda.status) %>
          <span class="catrow-edit">Open<span class="catrow-caret" aria-hidden="true">&rsaquo;</span></span>
        </span>
      <% end %>
    <% end %>
  </div>
<% else %>
  <p class="page-sub">No dated agendas yet. Create one to prepare for an upcoming meeting.</p>
<% end %>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/admin/dated_agendas_controller_test.rb`
Expected: PASS (all tests in the file)

- [ ] **Step 5: Commit**

```bash
git add app/views/admin/dated_agendas/index.html.erb test/controllers/admin/dated_agendas_controller_test.rb
git commit -m "feat: restyle admin dated agendas index"
```

---

### Task 5: Admin create form (new + shared _form)

**Files:**
- Modify: `app/views/admin/dated_agendas/new.html.erb`
- Modify: `app/views/admin/dated_agendas/_form.html.erb`
- Test: `test/controllers/admin/dated_agendas_controller_test.rb`

**Interfaces:**
- Consumes: controller `new` sets `@dated_agenda`, `@meeting_bodies`, `@meeting_types` (existing). The `_form` is shared by `new` and Task 6's `edit`.

- [ ] **Step 1: Write the failing test**

Add to `test/controllers/admin/dated_agendas_controller_test.rb`:

```ruby
  test "new renders a stacked form with plain labels and a title field" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get new_admin_dated_agenda_path

    assert_response :success
    assert_select "form.stacked-form"
    assert_select "form.stacked-form select[name='dated_agenda[meeting_body_id]']"
    assert_select "form.stacked-form select[name='dated_agenda[meeting_type_id]']"
    assert_select "form.stacked-form input[name='dated_agenda[starts_at]']"
    assert_select "form.stacked-form input.btn-primary"
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/admin/dated_agendas_controller_test.rb -n /new renders a stacked form/`
Expected: FAIL (current form has no `.stacked-form`/`.btn-primary`)

- [ ] **Step 3: Rewrite `_form`**

Replace `app/views/admin/dated_agendas/_form.html.erb` entirely:

```erb
<%= form_with model: [ :admin, dated_agenda ], class: "stacked-form" do |form| %>
  <% if dated_agenda.errors.any? %>
    <div class="error-summary">
      <h2><%= pluralize(dated_agenda.errors.count, "error") %> prohibited this agenda from being saved:</h2>
      <ul>
        <% dated_agenda.errors.full_messages.each do |message| %><li><%= message %></li><% end %>
      </ul>
    </div>
  <% end %>

  <%= form.hidden_field :lock_version if dated_agenda.persisted? %>

  <% if dated_agenda.persisted? %>
    <div class="fl">
      <span class="fl-label-inline">Meeting body</span>
      <p><%= dated_agenda.meeting_body.name %></p>
    </div>
    <div class="fl">
      <span class="fl-label-inline">Meeting type</span>
      <p><%= dated_agenda.meeting_type.name %></p>
    </div>
  <% else %>
    <div class="fl">
      <%= form.label :meeting_body_id, "Meeting body" %>
      <%= form.collection_select :meeting_body_id, @meeting_bodies, :id, :name, {}, class: "f" %>
    </div>
    <div class="fl">
      <%= form.label :meeting_type_id, "Meeting type" %>
      <%= form.collection_select :meeting_type_id, @meeting_types, :id, :name, {}, class: "f" %>
    </div>
  <% end %>

  <div class="fl">
    <%= form.label :starts_at, "Date & time" %>
    <%= form.datetime_local_field :starts_at, class: "f" %>
  </div>

  <div class="fl">
    <%= form.label :title, "Title (optional)" %>
    <%= form.text_field :title, class: "f" %>
    <span class="fl-help">Leave blank to use the meeting type name and date.</span>
  </div>

  <% if dated_agenda.draft? || !dated_agenda.persisted? %>
    <div class="btnrow">
      <%= form.submit(dated_agenda.persisted? ? "Save details" : "Create agenda", class: "btn-primary") %>
      <%= link_to "Cancel", admin_dated_agendas_path, class: "btn-secondary" %>
    </div>
  <% else %>
    <p class="readonly-tip">This agenda is locked. Reopen it to edit these details.</p>
  <% end %>
<% end %>
```

- [ ] **Step 4: Rewrite `new`**

Replace `app/views/admin/dated_agendas/new.html.erb` entirely:

```erb
<% content_for :title, "New dated agenda" %>
<a class="back" href="<%= admin_dated_agendas_path %>">&larr; Dated Agendas</a>

<div class="page-lead">
  <h1 class="page-title">New dated agenda</h1>
  <p class="page-sub">Create an agenda for a specific meeting date from a meeting type template. Creating it copies that template's current items into this agenda; if the template is empty, the agenda starts empty.</p>
</div>

<%= render "form", dated_agenda: @dated_agenda %>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/dated_agendas_controller_test.rb`
Expected: PASS (new-form test plus the existing create/validation tests still green)

- [ ] **Step 6: Commit**

```bash
git add app/views/admin/dated_agendas/new.html.erb app/views/admin/dated_agendas/_form.html.erb test/controllers/admin/dated_agendas_controller_test.rb
git commit -m "feat: restyle admin dated agenda create form"
```

---

### Task 6: Admin management (edit) screen with drag-reorder items

**Files:**
- Modify: `app/views/admin/dated_agendas/edit.html.erb`
- Modify: `app/assets/tailwind/application.css` (add `.da-lifecycle` block)
- Test: `test/controllers/admin/dated_agendas_controller_test.rb`

**Interfaces:**
- Consumes: `dated_agenda_status_tag` (Task 1), `reorder_admin_dated_agenda_agenda_items_path` (Task 3), the shared `reorder` Stimulus controller + `.pos-handle`/`.row-del`/`.reorder-hint`/`.pos-status` CSS (on `main`).

- [ ] **Step 1: Write the failing tests**

Add to `test/controllers/admin/dated_agendas_controller_test.rb`. The existing setup creates a draft `@agenda` with at least one copied item; reuse it:

```ruby
  test "edit shows the lifecycle bar, drag-reorder list, and Approve for a draft" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get edit_admin_dated_agenda_path(@agenda)

    assert_response :success
    assert_select ".da-lifecycle .st.st--draft"
    assert_select "form[action='#{approve_admin_dated_agenda_path(@agenda)}']"
    assert_select "[data-controller='reorder'][data-reorder-url-value='#{reorder_admin_dated_agenda_agenda_items_path(@agenda)}']"
    assert_select ".mrow-list[data-reorder-target='list'] .mrow.catrow[data-reorder-item] .pos-handle"
    assert_select ".mrow.catrow .catrow-meta button.row-del"
  end

  test "edit locks the item list and shows Publish + Reopen when approved" do
    sign_in_as(user_with_capabilities("manage_agendas"))
    @agenda.approve!(User.last)

    get edit_admin_dated_agenda_path(@agenda)

    assert_response :success
    assert_select ".da-lifecycle .st.st--approved"
    assert_select "form[action='#{publish_admin_dated_agenda_path(@agenda)}']"
    assert_select "form[action='#{reopen_admin_dated_agenda_path(@agenda)}']"
    assert_select ".readonly-tip"
    assert_select "[data-controller='reorder']", false
    assert_select ".pos-handle", false
    assert_select "button.row-del", false
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/dated_agendas_controller_test.rb -n /edit /`
Expected: FAIL (current edit view has no `.da-lifecycle`, no reorder controller)

- [ ] **Step 3: Add the `.da-lifecycle` CSS**

Append to `app/assets/tailwind/application.css` (end of file is fine):

```css
/* Dated agenda management -------------------------------------------------- */
.da-lifecycle { margin: 8px 0 22px; }
.da-lifecycle .st { display: inline-block; margin-bottom: 12px; }
.da-lifecycle .btnrow { margin: 0; }
```

- [ ] **Step 4: Rewrite the edit view**

Replace `app/views/admin/dated_agendas/edit.html.erb` entirely:

```erb
<% content_for :title, @dated_agenda.title %>
<a class="back" href="<%= admin_dated_agendas_path %>">&larr; Dated Agendas</a>

<div class="page-lead">
  <h1 class="page-title"><%= @dated_agenda.title %></h1>
  <p class="page-sub"><%= @dated_agenda.meeting_body.name %> &middot; <%= legion_datetime(@dated_agenda.starts_at) %></p>
</div>

<div class="da-lifecycle">
  <%= dated_agenda_status_tag(@dated_agenda.status) %>
  <div class="btnrow">
    <% if @dated_agenda.draft? %>
      <%= button_to "Approve", approve_admin_dated_agenda_path(@dated_agenda), method: :patch, class: "btn-primary" %>
    <% elsif @dated_agenda.approved? %>
      <%= button_to "Publish", publish_admin_dated_agenda_path(@dated_agenda), method: :patch, class: "btn-primary" %>
      <%= button_to "Reopen for editing", reopen_admin_dated_agenda_path(@dated_agenda), method: :patch, class: "btn-secondary", data: { turbo_confirm: "Reopen this approved agenda for editing?" } %>
    <% else %>
      <%= button_to "Reopen for editing", reopen_admin_dated_agenda_path(@dated_agenda), method: :patch, class: "btn-secondary", data: { turbo_confirm: "Reopen this published agenda for editing? Members keep seeing the last published version until you publish again." } %>
    <% end %>
    <%= link_to "Print", print_admin_dated_agenda_path(@dated_agenda), class: "btn-secondary" %>
  </div>
  <% if @dated_agenda.locked_for_editing? %>
    <p class="readonly-tip">This agenda is <%= @dated_agenda.status %> and locked. Reopen it to make changes.</p>
  <% end %>
</div>

<%= render "form", dated_agenda: @dated_agenda %>

<div class="sec-head-row" style="margin-top: 22px">
  <%= render "shared/section_header", label: "Agenda items" %>
</div>

<% items = @dated_agenda.dated_agenda_items.active.ordered %>

<% if @dated_agenda.draft? %>
  <div class="btnrow" style="margin-top: 12px">
    <%= link_to "Add from catalog", new_admin_dated_agenda_agenda_item_path(@dated_agenda), class: "btn-primary" %>
  </div>

  <% if items.any? %>
    <p class="page-sub reorder-hint">Drag a row by its handle to change the order. Changes save automatically.</p>
    <div data-controller="reorder" data-reorder-url-value="<%= reorder_admin_dated_agenda_agenda_items_path(@dated_agenda) %>">
      <div class="mrow-list" data-reorder-target="list">
        <% items.each do |item| %>
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
              <%= link_to "Edit", edit_admin_dated_agenda_agenda_item_path(@dated_agenda, item), class: "catrow-edit" %>
              <%= button_to admin_dated_agenda_agenda_item_path(@dated_agenda, item), method: :delete, class: "row-del", aria: { label: "Remove #{item.title}" }, data: { turbo_confirm: "Remove “#{item.title}” from this agenda?" } do %>
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
    <p class="page-sub">This agenda has no items yet. Add items from the catalog to build this meeting agenda.</p>
  <% end %>
<% else %>
  <% if items.any? %>
    <div class="mrow-list">
      <% items.each do |item| %>
        <div class="mrow">
          <span class="mrow-id">
            <span class="mrow-name"><%= item.title %></span>
            <% if item.summary.present? %><span class="mrow-sub"><%= item.summary %></span><% end %>
          </span>
        </div>
      <% end %>
    </div>
  <% else %>
    <p class="page-sub">This agenda has no items.</p>
  <% end %>
<% end %>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/dated_agendas_controller_test.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/views/admin/dated_agendas/edit.html.erb app/assets/tailwind/application.css test/controllers/admin/dated_agendas_controller_test.rb
git commit -m "feat: redesign dated agenda management screen with drag reorder"
```

---

### Task 7: Member views (index, show, _agenda_body) + agenda-doc CSS

**Files:**
- Modify: `app/views/dated_agendas/index.html.erb`
- Modify: `app/views/dated_agendas/show.html.erb`
- Modify: `app/views/dated_agendas/_agenda_body.html.erb`
- Modify: `app/assets/tailwind/application.css` (add `.agenda-doc` / `.agenda-item` block)
- Test: `test/controllers/dated_agendas_controller_test.rb`

- [ ] **Step 1: Write the failing tests**

Add to `test/controllers/dated_agendas_controller_test.rb` (its setup creates a published agenda — reuse the existing published-agenda variable, referred to here as `@published`; match the setup's actual name):

```ruby
  test "member show renders a readable agenda document with house date format and a print link" do
    sign_in_as(user_with_capabilities)

    get dated_agenda_path(@published)

    assert_response :success
    assert_select "article.agenda-doc .agenda-masthead .page-title", text: @published.title
    assert_select "a.btn-secondary[href='#{print_dated_agenda_path(@published)}']", text: "Print"
    assert_select ".agenda-item .agenda-item-title"
    assert_select ".agenda-masthead", text: /#{Regexp.escape(legion_datetime(@published.starts_at))}/
  end

  test "member index lists published agendas in the design system" do
    sign_in_as(user_with_capabilities)

    get dated_agendas_path

    assert_response :success
    assert_select ".page-lead .page-title", text: "Upcoming Published Agendas"
    assert_select ".mrow-list .mrow.catrow .mrow-name", text: @published.title
  end
```

If the controller test class does not already include `LegionFormatHelper`, add `include LegionFormatHelper` at the top of the class so `legion_datetime` is available in assertions.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/dated_agendas_controller_test.rb`
Expected: FAIL (bare views have no `.agenda-doc`/`.mrow-list`)

- [ ] **Step 3: Add the CSS**

Append to `app/assets/tailwind/application.css`:

```css
/* Published / printable agenda document ------------------------------------ */
.agenda-doc { max-width: 720px; }
.agenda-masthead { margin-bottom: 22px; }
.agenda-masthead .page-title { margin: 4px 0; }
.agenda-item { padding: 18px 0; border-top: 1px solid #eadfbf; }
.agenda-item:first-child { border-top: none; }
.agenda-item-title { font-size: 20px; color: var(--color-navy); font-weight: 700; margin: 0 0 6px; }
.agenda-item-summary { font-size: 16px; color: var(--color-muted); margin: 0 0 8px; }
.agenda-item-body { font-size: 16px; line-height: 1.6; color: var(--color-ink); }
```

- [ ] **Step 4: Rewrite the three views**

`app/views/dated_agendas/_agenda_body.html.erb`:

```erb
<% dated_agenda.dated_agenda_items.active.ordered.each do |agenda_item| %>
  <section class="agenda-item">
    <h2 class="agenda-item-title"><%= agenda_item.title %></h2>
    <% if agenda_item.summary.present? %>
      <p class="agenda-item-summary"><%= agenda_item.summary %></p>
    <% end %>
    <div class="agenda-item-body"><%= agenda_item.body %></div>
  </section>
<% end %>
```

`app/views/dated_agendas/show.html.erb`:

```erb
<% content_for :title, @dated_agenda.title %>

<article class="agenda-doc">
  <header class="agenda-masthead">
    <p class="page-sub"><%= @dated_agenda.meeting_body.name %></p>
    <h1 class="page-title"><%= @dated_agenda.title %></h1>
    <p class="page-sub"><%= legion_datetime(@dated_agenda.starts_at) %></p>
  </header>

  <div class="btnrow">
    <%= link_to "Print", print_dated_agenda_path(@dated_agenda), class: "btn-secondary" %>
  </div>

  <%= render "agenda_body", dated_agenda: @dated_agenda %>
</article>
```

`app/views/dated_agendas/index.html.erb`:

```erb
<% content_for :title, "Upcoming Published Agendas" %>

<div class="page-lead">
  <h1 class="page-title">Upcoming Published Agendas</h1>
  <p class="page-sub">Agendas your post has published for upcoming meetings.</p>
</div>

<% if @dated_agendas.any? %>
  <div class="mrow-list">
    <% @dated_agendas.each do |dated_agenda| %>
      <%= link_to dated_agenda_path(dated_agenda), class: "mrow catrow", aria: { label: "View #{dated_agenda.title}" } do %>
        <span class="mrow-id">
          <span class="mrow-name"><%= dated_agenda.title %></span>
          <span class="mrow-sub"><%= dated_agenda.meeting_body.name %> &middot; <%= legion_datetime(dated_agenda.starts_at) %></span>
        </span>
        <span class="catrow-meta">
          <span class="catrow-edit">View<span class="catrow-caret" aria-hidden="true">&rsaquo;</span></span>
        </span>
      <% end %>
    <% end %>
  </div>
<% else %>
  <p class="page-sub">No upcoming published agendas are available yet.</p>
<% end %>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/dated_agendas_controller_test.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/views/dated_agendas/index.html.erb app/views/dated_agendas/show.html.erb app/views/dated_agendas/_agenda_body.html.erb app/assets/tailwind/application.css test/controllers/dated_agendas_controller_test.rb
git commit -m "feat: restyle member-facing dated agenda views"
```

---

### Task 8: Print layout + print views + print stylesheet

**Files:**
- Modify: `app/views/layouts/print.html.erb`
- Modify: `app/views/admin/dated_agendas/print.html.erb`
- Modify: `app/views/dated_agendas/print.html.erb`
- Modify: `app/assets/tailwind/application.css` (add `@media print` block)
- Test: `test/controllers/admin/dated_agendas_controller_test.rb`, `test/controllers/dated_agendas_controller_test.rb`

- [ ] **Step 1: Write the failing tests**

Add to `test/controllers/admin/dated_agendas_controller_test.rb`:

```ruby
  test "admin print renders a chrome-free agenda document" do
    sign_in_as(user_with_capabilities("manage_agendas"))

    get print_admin_dated_agenda_path(@agenda)

    assert_response :success
    assert_select "article.agenda-doc .agenda-masthead .page-title", text: @agenda.title
    assert_select ".agenda-item .agenda-item-title"
    assert_select "a.back", false
    assert_select ".btnrow", false
  end
```

Add to `test/controllers/dated_agendas_controller_test.rb` (reuse the published agenda variable name from its setup):

```ruby
  test "member print renders a chrome-free agenda document" do
    sign_in_as(user_with_capabilities)

    get print_dated_agenda_path(@published)

    assert_response :success
    assert_select "article.agenda-doc .agenda-masthead .page-title", text: @published.title
    assert_select ".agenda-item .agenda-item-title"
    assert_select "a.back", false
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/admin/dated_agendas_controller_test.rb test/controllers/dated_agendas_controller_test.rb -n /print renders a chrome-free/`
Expected: FAIL (bare print views have no `.agenda-doc`)

- [ ] **Step 3: Add the print CSS**

Append to `app/assets/tailwind/application.css`:

```css
@media print {
  .back, .btnrow, .app-header, .app-main > .app-flash, .nav-bar, .nav-inner { display: none !important; }
  body { background: #fff; color: #000; }
  .agenda-doc { max-width: none; }
  .agenda-item { break-inside: avoid; page-break-inside: avoid; }
  .agenda-masthead { border-bottom: 2px solid #000; padding-bottom: 10px; }
  @page { margin: 18mm; }
}
```

- [ ] **Step 4: Rewrite the print views**

`app/views/admin/dated_agendas/print.html.erb`:

```erb
<% content_for :title, @dated_agenda.title %>
<article class="agenda-doc">
  <header class="agenda-masthead">
    <p class="page-sub"><%= @dated_agenda.meeting_body.name %> &middot; <%= @dated_agenda.meeting_type.name %></p>
    <h1 class="page-title"><%= @dated_agenda.title %></h1>
    <p class="page-sub"><%= legion_datetime(@dated_agenda.starts_at) %> &middot; <%= @dated_agenda.status.titleize %></p>
  </header>
  <%= render "dated_agendas/agenda_body", dated_agenda: @dated_agenda %>
</article>
```

`app/views/dated_agendas/print.html.erb`:

```erb
<% content_for :title, @dated_agenda.title %>
<article class="agenda-doc">
  <header class="agenda-masthead">
    <p class="page-sub"><%= @dated_agenda.meeting_body.name %></p>
    <h1 class="page-title"><%= @dated_agenda.title %></h1>
    <p class="page-sub"><%= legion_datetime(@dated_agenda.starts_at) %></p>
  </header>
  <%= render "agenda_body", dated_agenda: @dated_agenda %>
</article>
```

The print layout (`app/views/layouts/print.html.erb`) already loads `tailwind` and yields into `<main>`; no change is required beyond the CSS. (Optional: add `class="print-body"` to `<body>` if future print-only tweaks need a hook — not required now.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/admin/dated_agendas_controller_test.rb test/controllers/dated_agendas_controller_test.rb`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/views/layouts/print.html.erb app/views/admin/dated_agendas/print.html.erb app/views/dated_agendas/print.html.erb app/assets/tailwind/application.css test/controllers/admin/dated_agendas_controller_test.rb test/controllers/dated_agendas_controller_test.rb
git commit -m "feat: printable dated agenda stylesheet and views"
```

---

### Task 9: Browser smoke test (system)

**Files:**
- Create: `test/system/dated_agendas_test.rb`

**Interfaces:**
- Consumes: `ApplicationSystemTestCase` + `system_sign_in` (on `main`), the reorder markup from Task 6.

- [ ] **Step 1: Write the system test**

Create `test/system/dated_agendas_test.rb`:

```ruby
require "application_system_test_case"

# Browser-driven coverage for the dated-agenda management screen: the Stimulus /
# SortableJS drag reorder and the locked-state hiding of edit controls that
# request tests can't exercise.
class DatedAgendasSystemTest < ApplicationSystemTestCase
  setup do
    @organization = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    @user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: @user, capability: "manage_agendas")

    @meeting_body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting_type = @organization.meeting_types.create!(name: "Membership Meeting", slug: "membership-meeting", position: 1, active: true)
    opening = @organization.agenda_item_catalog_entries.create!(title: "Opening Ceremony", slug: "opening-ceremony", category: "ceremony", behavior_type: "scripted_ceremony", position: 1, active: true, body: "Opening")
    report = @organization.agenda_item_catalog_entries.create!(title: "Commander Report", slug: "commander-report", category: "reports", behavior_type: "report_slot", position: 2, active: true, body: "Report")
    @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: opening, position: 1, title: "Opening Ceremony", active: true, body: "Opening")
    @meeting_type.meeting_type_agenda_items.create!(agenda_item_catalog_entry: report, position: 2, title: "Commander Report", active: true, body: "Report")
    @agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body: @meeting_body, meeting_type: @meeting_type, starts_at: Time.zone.local(2026, 8, 4, 19, 0))

    system_sign_in(@user)
  end

  test "drag-reordering agenda items auto-saves the new order" do
    visit edit_admin_dated_agenda_path(@agenda)

    items = @agenda.dated_agenda_items.ordered.to_a
    first = items.first
    last = items.last

    source = find("[data-reorder-id='#{first.id}'] .pos-handle")
    target = find("[data-reorder-id='#{last.id}']")
    source.drag_to(target, html5: true)

    assert_selector ".pos-status", text: /saved/i
    assert_not_equal first.id,
      @agenda.dated_agenda_items.ordered.first.id,
      "the first item should no longer be first after dragging it down"
  end

  test "approved agenda hides drag handles and item edit controls" do
    @agenda.approve!(@user)
    visit edit_admin_dated_agenda_path(@agenda)

    assert_selector ".da-lifecycle .st.st--approved"
    assert_selector ".readonly-tip"
    assert_no_selector ".pos-handle"
    assert_no_selector "button.row-del"
  end
end
```

- [ ] **Step 2: Run the system test**

Run: `bin/rails test:system TEST=test/system/dated_agendas_test.rb`
Expected: PASS (headless Chromium; both tests green)

- [ ] **Step 3: Commit**

```bash
git add test/system/dated_agendas_test.rb
git commit -m "test: browser smoke test for dated agenda drag reorder and locking"
```

---

### Task 10: Full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Rebuild CSS**

Run: `bin/rails tailwindcss:build`
Expected: `Done in ...` with no errors.

- [ ] **Step 2: Run the full request/model/helper suite**

Run: `bin/rails test`
Expected: all green, 0 failures / 0 errors.

- [ ] **Step 3: Run the system suite**

Run: `bin/rails test:system`
Expected: all green (meeting types + dated agendas).

- [ ] **Step 4: Grep for any remaining format violations in dated-agenda views**

Run: `grep -rn "format: :long\|strftime" app/views/admin/dated_agendas app/views/dated_agendas`
Expected: no matches (all display goes through `LegionFormatHelper`).

- [ ] **Step 5: Final commit if anything changed**

```bash
git status
# commit only if the CSS rebuild or grep cleanup changed tracked files
```

---

## Self-Review

**Spec coverage:**
- Cross-cutting date format → Task 4–8 use `legion_datetime`/`legion_date`; Task 10 greps for violations. ✅
- App shell everywhere → each view task adds `content_for :title` / `.back` / `.page-lead`. ✅
- Lifecycle status tag → Task 1. ✅
- Admin index → Task 4. ✅
- Management screen (lifecycle bar, details form, drag list, locked state, print link) → Task 6 (+ Task 5 form, Task 1 tag, Task 3 endpoint). ✅
- Create form → Task 5. ✅
- Member index/show/_agenda_body → Task 7. ✅
- Print layout + views + print CSS → Task 8. ✅
- Drag reorder (model/route/controller, remove move, reuse controller) → Tasks 2–3, markup in Task 6. ✅
- Tests (reorder controller, reorder model, system) → Tasks 2, 3, 9. ✅

**Placeholder scan:** No TBD/TODO; every code step shows complete code.

**Type/name consistency:** `dated_agenda_status_tag` (Task 1) used verbatim in Tasks 4/6. `reorder_admin_dated_agenda_agenda_items_path` (Task 3 route) used verbatim in Task 6 view + Task 3/9 tests. `DatedAgendaItem.reorder!` (Task 2) called in Task 3 controller. CSS classes (`.da-lifecycle`, `.agenda-doc`, `.agenda-item*`, `.st--draft/approved/published`) defined before first use.

**Note on test variable names:**
- Admin file (`admin/dated_agendas_controller_test`): its setup defines **no** agenda — Task 4 Step 1a adds `@agenda` (a draft created from template) to the setup; Tasks 6 and 8 reuse that `@agenda`.
- Member file (`dated_agendas_controller_test`): its setup already defines `@draft`, `@published` (a published agenda with one item), and `@user` (`user_with_capabilities`, no `manage_agendas`). Tasks 7 and 8 use `@published`. This file's member print/show only requires authentication, so signing in as `@user` is sufficient.
- The implementer should open each test file first and confirm these names before pasting assertions.
