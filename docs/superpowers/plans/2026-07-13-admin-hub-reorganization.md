# Admin Hub Reorganization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the flat, scrolling admin dashboard into a capability-aware hub of bounded tile cards grouped into three topical sections, and give `manage_settings` admins full management access so they can act as the tool's tech support.

**Architecture:** The admin landing (`Admin::DashboardController#show`) becomes a hub of small bounded tiles in three sections (Meetings & Roster, Officers & Elections, Setup & Administration), each tile linking to a focused page. Two things currently rendered inline on the dashboard — Post Positions and Administrators — move to their own focused pages. `User#can?` gains a superset rule so a `manage_settings` grant implies the management capabilities (but not the identity-bound attestation acts). The hub is rendered per-viewer-capability and reachable by any admin-capable user, which lets us drop the nav special-case that routed agenda managers straight to the catalog.

**Tech Stack:** Ruby on Rails, ERB views, Minitest integration tests, Tailwind v4 (bespoke component CSS in `app/assets/tailwind/application.css`).

## Global Constraints

- **Readability floors (hard rule):** body/interactive text ≥16px, secondary/caption ≥14px, labels ≥13px, nothing meaningful below 13px. Source: `docs/superpowers/specs/2026-07-11-visual-design-system-design.md`.
- **No full-width boxes or stretched rows with stranded actions.** Status and action stay grouped with their subject. Tiles must never span the full content width.
- **Dates render `DD MMM YYYY`** (e.g. `28 JUN 2026`) via the `legion_date` helper; times 24-hour `HH:MM`.
- **Reuse existing visual language** (`shared/_section_panel`, `.card`, `.btn-secondary`, design tokens like `var(--color-navy)`), do not invent new chrome where an existing class fits.
- **Keep Rails conventional. Do not overbuild.** The capability boundary is a plain check, not an audit/enforcement system.
- **Never hand-edit `app/assets/builds/tailwind.css`** — it is generated. Edit `app/assets/tailwind/application.css` and rebuild with `bin/rails tailwindcss:build`.

Design spec: `docs/superpowers/specs/2026-07-13-admin-hub-reorganization-design.md`.

---

## File Structure

**Task 1 — Capability superset**
- Modify: `app/models/permission_grant.rb` (add `IMPLIED_BY_MANAGE_SETTINGS` constant)
- Modify: `app/models/user.rb` (`can?` superset rule)
- Test: `test/models/user_test.rb`

**Task 2 — Post Positions focused page**
- Modify: `config/routes.rb` (add `index` to `position_titles`)
- Modify: `app/controllers/admin/position_titles_controller.rb` (add `index`, redirect targets)
- Create: `app/views/admin/position_titles/index.html.erb`
- Test: `test/controllers/admin/position_titles_controller_test.rb`

**Task 3 — Administrators focused page**
- Modify: `config/routes.rb` (add `administrators` resource)
- Create: `app/controllers/admin/administrators_controller.rb`
- Create: `app/views/admin/administrators/index.html.erb`
- Test: `test/controllers/admin/administrators_controller_test.rb`

**Task 4 — Reshape the hub (tiles, reachability, nav, CSS)**
- Modify: `app/controllers/admin/dashboard_controller.rb` (inherit `ApplicationController`, own gate, slim data)
- Modify: `app/views/admin/dashboard/show.html.erb` (three tile sections, capability-gated)
- Modify: `app/assets/tailwind/application.css` (hub/tile styles)
- Modify: `app/views/shared/_primary_nav.html.erb` (single Admin link to the hub)
- Test: `test/controllers/admin/dashboard_controller_test.rb` (rewrite), `test/integration/primary_nav_test.rb` (update one test)

---

## Task 1: `manage_settings` capability superset

**Files:**
- Modify: `app/models/permission_grant.rb`
- Modify: `app/models/user.rb:14-16`
- Test: `test/models/user_test.rb`

**Interfaces:**
- Consumes: nothing.
- Produces: `PermissionGrant::IMPLIED_BY_MANAGE_SETTINGS` (frozen `Array<String>`); `User#can?(capability)` now returns `true` for any capability in that list when the user holds `manage_settings`.

- [ ] **Step 1: Write the failing tests**

Add to `test/models/user_test.rb` (inside the `class UserTest`):

```ruby
test "manage_settings implies the management capabilities" do
  person = Person.create!(first_name: "Ada", last_name: "Admin")
  user = User.create!(person: person, email_address: "ada@example.com", email_verified_at: Time.current)
  PermissionGrant.create!(user: user, capability: "manage_settings")

  assert user.can?("manage_agendas")
  assert user.can?("manage_people")
  assert user.can?("manage_meeting_bodies")
  assert user.can?("manage_minutes")
  assert user.can?("view_internal_records")
end

test "manage_settings does not imply the identity-bound attestation acts" do
  person = Person.create!(first_name: "Ada", last_name: "Admin")
  user = User.create!(person: person, email_address: "ada2@example.com", email_verified_at: Time.current)
  PermissionGrant.create!(user: user, capability: "manage_settings")

  assert_not user.can?("attest_minutes")
  assert_not user.can?("approve_minutes")
  assert_not user.can?("record_acceptance_motions")
end

test "a manage_agendas grant alone grants only manage_agendas" do
  person = Person.create!(first_name: "Sam", last_name: "Agenda")
  user = User.create!(person: person, email_address: "sam2@example.com", email_verified_at: Time.current)
  PermissionGrant.create!(user: user, capability: "manage_agendas")

  assert user.can?("manage_agendas")
  assert_not user.can?("manage_settings")
  assert_not user.can?("manage_people")
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bin/rails test test/models/user_test.rb`
Expected: FAIL — `manage_settings implies...` fails because `can?("manage_agendas")` returns false under the current exact-match implementation.

- [ ] **Step 3: Add the implied-capabilities constant**

In `app/models/permission_grant.rb`, add this constant just after the `GROUPS` constant (before `belongs_to :user`):

```ruby
  # Capabilities a manage_settings admin implicitly holds so they can act as the
  # tool's tech support. Deliberately excludes the identity-bound attestation acts
  # (approve_minutes, attest_minutes, record_acceptance_motions), which stay explicit
  # personal grants to preserve official-record authenticity.
  # See docs/superpowers/specs/2026-07-13-admin-hub-reorganization-design.md.
  IMPLIED_BY_MANAGE_SETTINGS = %w[
    manage_people
    manage_meeting_bodies
    manage_agendas
    manage_minutes
    view_internal_records
  ].freeze
```

- [ ] **Step 4: Apply the superset rule in `User#can?`**

Replace `app/models/user.rb:14-16`:

```ruby
  def can?(capability)
    permission_grants.exists?(capability: capability.to_s)
  end
```

with:

```ruby
  def can?(capability)
    capability = capability.to_s
    return true if permission_grants.exists?(capability: capability)
    return false unless PermissionGrant::IMPLIED_BY_MANAGE_SETTINGS.include?(capability)

    permission_grants.exists?(capability: "manage_settings")
  end
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bin/rails test test/models/user_test.rb`
Expected: PASS (all tests, including the pre-existing ones).

- [ ] **Step 6: Commit**

```bash
git add app/models/permission_grant.rb app/models/user.rb test/models/user_test.rb
git commit -m "feat: make manage_settings imply the management capabilities

Admins act as the tool's tech support, so a manage_settings grant now
satisfies the management capability checks (people, agendas, meeting bodies,
minutes, internal records). The identity-bound attestation acts are
deliberately excluded to preserve official-record authenticity.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Post Positions focused page

Moves the inline position list + add form off the dashboard onto its own page at `/admin/position_titles`.

**Files:**
- Modify: `config/routes.rb:40` (the `position_titles` route)
- Modify: `app/controllers/admin/position_titles_controller.rb`
- Create: `app/views/admin/position_titles/index.html.erb`
- Test: `test/controllers/admin/position_titles_controller_test.rb`

**Interfaces:**
- Consumes: `admin_position_titles_path` (index/create), `admin_position_title_path` (update) — enabled by the route change.
- Produces: a reachable `GET /admin/position_titles` index page (route helper `admin_position_titles_path`) that Task 4's Post Positions tile links to.

- [ ] **Step 1: Write the failing tests**

Replace the body of `test/controllers/admin/position_titles_controller_test.rb` with (helpers preserved, redirect targets updated, index test added):

```ruby
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

  test "index lists the post's positions" do
    prepare_setup_complete_state
    sign_in_admin
    PositionTitle.create!(organization: @org, name: "Commander", display_order: 1, active: true)
    PositionTitle.create!(organization: @org, name: "Adjutant", display_order: 2, active: false)

    get admin_position_titles_path

    assert_response :success
    assert_select ".pos .pn", text: "Commander"
    assert_select ".pos .pn", text: "Adjutant"
    assert_select "a[href=?]", admin_root_path, text: /Back to Administration/
  end

  test "index requires manage_settings" do
    prepare_setup_complete_state
    person = Person.create!(first_name: "Ann", last_name: "Roe")
    user = User.create!(person: person, email_address: "ann@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_agendas")
    sign_in_as(user)

    get admin_position_titles_path

    assert_redirected_to root_path
  end

  test "create adds a position title and returns to the positions page" do
    prepare_setup_complete_state
    sign_in_admin
    assert_difference -> { PositionTitle.count }, 1 do
      post admin_position_titles_path, params: { position_title: { name: "Chaplain", display_order: 5 } }
    end
    assert_redirected_to admin_position_titles_path
    assert_equal @org.id, PositionTitle.last.organization_id
  end

  test "update can deactivate a title" do
    prepare_setup_complete_state
    sign_in_admin
    title = PositionTitle.create!(organization: @org, name: "Historian", display_order: 9, active: true)
    patch admin_position_title_path(title), params: { position_title: { active: "0" } }
    assert_not title.reload.active
    assert_redirected_to admin_position_titles_path
  end
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bin/rails test test/controllers/admin/position_titles_controller_test.rb`
Expected: FAIL — `admin_position_titles_path` for GET has no route (index not defined), and the create/update redirect assertions fail (they still redirect to `admin_root_path`).

- [ ] **Step 3: Add the `index` route**

In `config/routes.rb`, change:

```ruby
    resources :position_titles, only: %i[create update]
```

to:

```ruby
    resources :position_titles, only: %i[index create update]
```

- [ ] **Step 4: Add the `index` action and repoint redirects**

Replace `app/controllers/admin/position_titles_controller.rb` with:

```ruby
module Admin
  class PositionTitlesController < BaseController
    def index
      @position_titles = Organization.first.position_titles.order(:display_order, :name)
    end

    def create
      title = Organization.first.position_titles.new(position_title_params)
      if title.save
        redirect_to admin_position_titles_path, notice: "Post position added."
      else
        redirect_to admin_position_titles_path, alert: title.errors.full_messages.to_sentence
      end
    end

    def update
      title = PositionTitle.find(params[:id])
      if title.update(position_title_params)
        redirect_to admin_position_titles_path, notice: "Post position updated."
      else
        redirect_to admin_position_titles_path, alert: title.errors.full_messages.to_sentence
      end
    end

    private

    def position_title_params
      params.require(:position_title).permit(:name, :display_order, :active)
    end
  end
end
```

- [ ] **Step 5: Create the index view**

Create `app/views/admin/position_titles/index.html.erb`:

```erb
<% content_for :title, "Post Positions" %>

<div class="page-lead">
  <h1 class="page-title">Post Positions</h1>
  <p class="page-sub">The offices your post fills, their wording, and their order.</p>
</div>

<%= render "shared/section_panel", label: "Post Positions" do %>
  <% if @position_titles.present? %>
    <% @position_titles.each do |title| %>
      <div class="pos">
        <span class="pn"><%= title.name %></span>
        <span class="state <%= title.active? ? "on" : "off" %>"><%= title.active? ? "Active" : "Inactive" %></span>
        <%= button_to title.active? ? "Deactivate" : "Activate", admin_position_title_path(title), method: :patch,
              params: { position_title: { active: !title.active? } }, class: "toggle", form: { class: "posform" } %>
      </div>
    <% end %>
  <% else %>
    <p class="page-sub">No post positions yet.</p>
  <% end %>

  <div class="addrow">
    <%= form_with url: admin_position_titles_path, method: :post, scope: :position_title do |form| %>
      <div class="fl">
        <%= form.label :name, "Position name" %>
        <%= form.text_field :name, class: "f" %>
      </div>
      <div class="fl">
        <%= form.label :display_order, "Order" %>
        <%= form.number_field :display_order, class: "f", value: (@position_titles.map(&:display_order).max || 0) + 1 %>
      </div>
      <%= form.submit "+ Add position", class: "btn-secondary" %>
    <% end %>
  </div>
<% end %>

<p class="page-sub"><%= link_to "← Back to Administration", admin_root_path %></p>
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bin/rails test test/controllers/admin/position_titles_controller_test.rb`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/admin/position_titles_controller.rb app/views/admin/position_titles/index.html.erb test/controllers/admin/position_titles_controller_test.rb
git commit -m "feat: give post positions their own focused admin page

Move the position list and add form off the dashboard onto
/admin/position_titles, with create/update returning there.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Administrators focused page

Moves the inline administrator list off the dashboard onto its own page at `/admin/administrators`.

**Files:**
- Modify: `config/routes.rb` (add `administrators` inside the `admin` namespace)
- Create: `app/controllers/admin/administrators_controller.rb`
- Create: `app/views/admin/administrators/index.html.erb`
- Test: `test/controllers/admin/administrators_controller_test.rb`

**Interfaces:**
- Consumes: nothing new (reuses the administrator query from the old dashboard).
- Produces: a reachable `GET /admin/administrators` index page (route helper `admin_administrators_path`) that Task 4's Administrators tile links to.

- [ ] **Step 1: Write the failing test**

Create `test/controllers/admin/administrators_controller_test.rb`:

```ruby
require "test_helper"

class Admin::AdministratorsControllerTest < ActionDispatch::IntegrationTest
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

  test "index lists enabled administrators and links to their person pages" do
    prepare_setup_complete_state
    admin = sign_in_admin

    get admin_administrators_path

    assert_response :success
    assert_select ".admrow .an", text: admin.person.full_name
    assert_select "a[href=?]", person_path(admin.person), text: /Manage on their page/
    assert_select "a[href=?]", admin_root_path, text: /Back to Administration/
  end

  test "index requires manage_settings" do
    prepare_setup_complete_state
    person = Person.create!(first_name: "Sam", last_name: "Roe")
    user = User.create!(person: person, email_address: "sam@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_agendas")
    sign_in_as(user)

    get admin_administrators_path

    assert_redirected_to root_path
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/admin/administrators_controller_test.rb`
Expected: FAIL — no route/controller for `admin_administrators_path`.

- [ ] **Step 3: Add the route**

In `config/routes.rb`, inside the `namespace :admin do` block (e.g. after the `agenda_item_catalog_entries` line), add:

```ruby
    resources :administrators, only: %i[index]
```

- [ ] **Step 4: Create the controller**

Create `app/controllers/admin/administrators_controller.rb`:

```ruby
module Admin
  class AdministratorsController < BaseController
    def index
      @administrators = User.where(disabled_at: nil).joins(:permission_grants)
        .where(permission_grants: { capability: "manage_settings" }).includes(:person).distinct
    end
  end
end
```

- [ ] **Step 5: Create the view**

Create `app/views/admin/administrators/index.html.erb`:

```erb
<% content_for :title, "Administrators" %>

<div class="page-lead">
  <h1 class="page-title">Administrators</h1>
  <p class="page-sub">Who can administer the app.</p>
</div>

<%= render "shared/section_panel", label: "Administrators" do %>
  <% @administrators.each do |admin| %>
    <div class="admrow">
      <span class="an"><%= admin.person.full_name %></span>
      <% if (role = admin.person.current_role_label) %>
        <span class="ao"><%= role %></span>
      <% end %>
      <%= link_to "Manage on their page →", person_path(admin.person), class: "go" %>
    </div>
  <% end %>
  <p class="safe">Permissions are granted on each person's page. At least one enabled administrator is always required — the last one can't be removed or disabled.</p>
<% end %>

<p class="page-sub"><%= link_to "← Back to Administration", admin_root_path %></p>
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bin/rails test test/controllers/admin/administrators_controller_test.rb`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/admin/administrators_controller.rb app/views/admin/administrators/index.html.erb test/controllers/admin/administrators_controller_test.rb
git commit -m "feat: give administrators their own focused admin page

Move the administrator list off the dashboard onto /admin/administrators,
each entry linking to the person page where permissions are granted.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Reshape the hub into capability-aware tiles

Replaces the four stacked panels with three sections of bounded tiles, makes the hub reachable to any admin-capable user, renders tiles per capability, and points the nav's Admin link at the hub for everyone.

**Files:**
- Modify: `app/controllers/admin/dashboard_controller.rb`
- Modify: `app/views/admin/dashboard/show.html.erb`
- Modify: `app/assets/tailwind/application.css`
- Modify: `app/views/shared/_primary_nav.html.erb`
- Test: `test/controllers/admin/dashboard_controller_test.rb` (rewrite), `test/integration/primary_nav_test.rb` (one test)

**Interfaces:**
- Consumes: `PermissionGrant::IMPLIED_BY_MANAGE_SETTINGS` via `User#can?` (Task 1); `admin_position_titles_path` (Task 2); `admin_administrators_path` (Task 3); existing `new_admin_roster_import_path`, `admin_roster_imports_path`, `admin_agenda_item_catalog_entries_path`; `RosterImport.latest_successful`, `RosterImport.roster_stale?`; `legion_date`.
- Produces: the finished hub. No later task depends on it.

- [ ] **Step 1: Rewrite the dashboard controller test**

Replace the entire contents of `test/controllers/admin/dashboard_controller_test.rb` with:

```ruby
require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated admin root redirects to sign in" do
    prepare_setup_complete_state
    get admin_root_path
    assert_redirected_to new_session_path
  end

  test "member with no admin capability is denied" do
    prepare_setup_complete_state
    person = Person.create!(first_name: "Ann", last_name: "Roe")
    user = User.create!(person: person, email_address: "ann@example.com", email_verified_at: Time.current)
    sign_in_as(user)

    get admin_root_path

    assert_redirected_to root_path
    assert_equal "You do not have permission to open that page.", flash[:alert]
  end

  test "full admin sees all four tiles and their links" do
    prepare_setup_complete_state
    admin = sign_in_member(can_manage_settings: true)

    get admin_root_path

    assert_response :success
    assert_select ".hub-sec-h", text: "Meetings & Roster"
    assert_select ".hub-sec-h", text: "Officers & Elections"
    assert_select ".hub-sec-h", text: "Setup & Administration"
    assert_select ".tile .tile-t", text: "Roster"
    assert_select "a[href=?]", new_admin_roster_import_path, text: /Import roster/
    assert_select "a[href=?]", admin_roster_imports_path, text: /View imports/
    assert_select "a[href=?]", admin_agenda_item_catalog_entries_path, text: /Open catalog/
    assert_select "a[href=?]", admin_position_titles_path, text: /Manage positions/
    assert_select "a[href=?]", admin_administrators_path, text: /View administrators/
  end

  test "agenda-only manager reaches the hub and sees only the agenda catalog tile" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: false, can_manage_agendas: true)

    get admin_root_path

    assert_response :success
    assert_select ".hub-sec-h", text: "Meetings & Roster"
    assert_select "a[href=?]", admin_agenda_item_catalog_entries_path, text: /Open catalog/
    assert_select ".hub-sec-h", text: "Officers & Elections", count: 0
    assert_select ".hub-sec-h", text: "Setup & Administration", count: 0
    assert_select "a[href=?]", admin_position_titles_path, count: 0
    assert_select "a[href=?]", new_admin_roster_import_path, count: 0
  end

  test "roster tile reads current when a recent import exists" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: true)
    RosterImport.create!(uploaded_filename: "roster.csv", status: "completed", imported_at: 2.days.ago,
                         created_count: 1, updated_count: 0, unchanged_count: 0, problem_count: 0)

    get admin_root_path

    assert_response :success
    assert_select ".tile .tile-status.ok", text: /Current/
    assert_select ".tile--due", count: 0
  end

  test "roster tile turns due and flags an overdue import" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: true)
    RosterImport.create!(uploaded_filename: "roster.csv", status: "completed", imported_at: 31.days.ago,
                         created_count: 1, updated_count: 0, unchanged_count: 0, problem_count: 0)

    get admin_root_path

    assert_response :success
    assert_select ".tile.tile--due .tile-status", text: /Import due/
  end

  test "roster tile flags when no roster has been imported" do
    prepare_setup_complete_state
    sign_in_member(can_manage_settings: true)

    get admin_root_path

    assert_response :success
    assert_select ".tile.tile--due .tile-status", text: /Not imported/
  end

  private

  def prepare_setup_complete_state
    @org = Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_member(can_manage_settings: true, can_manage_agendas: false)
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings") if can_manage_settings
    PermissionGrant.create!(user: user, capability: "manage_agendas") if can_manage_agendas
    sign_in_as(user)
    user
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/admin/dashboard_controller_test.rb`
Expected: FAIL — the current view has no `.hub-sec-h`/`.tile` markup, and an agenda-only manager is denied by the inherited `manage_settings` gate.

- [ ] **Step 3: Rework the controller (gate + slim data)**

Replace `app/controllers/admin/dashboard_controller.rb` with:

```ruby
module Admin
  class DashboardController < ApplicationController
    before_action :require_admin_area

    def show
      @latest_roster_import = RosterImport.latest_successful
      @roster_stale = RosterImport.roster_stale?
    end

    private

    # The hub is reachable to anyone who can use at least one tile. Each linked
    # page keeps its own require_capability guard; this only gates the hub itself.
    def require_admin_area
      require_authentication
      return if performed?
      return if current_user.can?("manage_settings") || current_user.can?("manage_agendas")

      redirect_to root_path, alert: "You do not have permission to open that page."
    end
  end
end
```

- [ ] **Step 4: Add the hub/tile CSS**

Append to `app/assets/tailwind/application.css`:

```css
/* ---------------------------------------------------------------------------
   Admin hub: bounded tile cards grouped into topical sections. Tiles never
   stretch full width; the auto-fill/minmax grid keeps a lone tile card-width.
   Type floors: title 18px, description 15px, status label 13px.
   --------------------------------------------------------------------------- */
.hub-sec { margin-top: 26px; }
.hub-sec:first-of-type { margin-top: 10px; }
.hub-sec-h { font-size: 19px; font-weight: 800; color: var(--color-navy); margin: 0 0 2px; }
.hub-sec-n { font-size: 14px; color: var(--color-muted); margin: 0 0 13px; }
.hub-tiles { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 290px)); gap: 15px; }
.tile { display: flex; flex-direction: column; background: var(--color-paper); border: 1px solid #d3c391; border-radius: 11px; padding: 16px 17px 17px; box-shadow: 0 8px 22px rgba(0,0,0,.06); }
.tile .tile-ic { font-size: 22px; margin-bottom: 9px; }
.tile .tile-t { font-size: 18px; font-weight: 800; color: var(--color-navy); margin: 0 0 5px; }
.tile .tile-d { font-size: 15px; color: var(--color-muted); line-height: 1.42; margin: 0 0 14px; flex: 1; }
.tile .tile-actions { display: flex; flex-direction: column; gap: 9px; align-items: flex-start; }
.tile .tile-act { font-size: 15px; font-weight: 700; color: var(--color-legionred); text-decoration: none; }
.tile .tile-act:hover { text-decoration: underline; }
.tile .tile-btn { display: inline-block; font-size: 15px; font-weight: 800; color: #fff; background: var(--color-legionred); border-radius: 8px; padding: 9px 15px; text-decoration: none; }
.tile .tile-status { align-self: flex-start; display: inline-flex; align-items: center; gap: 7px; font-size: 13px; font-weight: 800; color: var(--color-gold-ink); background: #f0e2c2; border-radius: 20px; padding: 3px 10px; margin: 0 0 10px; }
.tile .tile-status .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--color-gold-ink); }
.tile .tile-status.ok { color: var(--color-green); background: #dfebd9; }
.tile .tile-status.ok .dot { background: var(--color-green); }
.tile.tile--due { background: #f8efe0; border-color: #e6cf9c; box-shadow: inset 3px 0 0 var(--color-gold-ink), 0 8px 22px rgba(0,0,0,.06); }
```

- [ ] **Step 5: Rewrite the hub view**

Replace the entire contents of `app/views/admin/dashboard/show.html.erb` with:

```erb
<% content_for :title, "Administration" %>

<div class="page-lead">
  <h1 class="page-title">Administration</h1>
  <p class="page-sub">Everything that keeps the post’s tools running.</p>
</div>

<% show_roster = current_user.can?("manage_settings") %>
<% show_agendas = current_user.can?("manage_agendas") %>
<% show_positions = current_user.can?("manage_settings") %>
<% show_admins = current_user.can?("manage_settings") %>

<% if show_roster || show_agendas %>
  <section class="hub-sec">
    <h2 class="hub-sec-h">Meetings &amp; Roster</h2>
    <p class="hub-sec-n">Keep the membership current and prepare your agendas.</p>
    <div class="hub-tiles">
      <% if show_roster %>
        <div class="tile<%= " tile--due" if @roster_stale %>">
          <div class="tile-ic" aria-hidden="true">📇</div>
          <% if @roster_stale %>
            <span class="tile-status"><span class="dot" aria-hidden="true"></span><%= @latest_roster_import ? "Import due" : "Not imported" %></span>
          <% else %>
            <span class="tile-status ok"><span class="dot" aria-hidden="true"></span>Current</span>
          <% end %>
          <p class="tile-t">Roster</p>
          <p class="tile-d">
            <% if @latest_roster_import %>
              Last imported <%= legion_date(@latest_roster_import.imported_at) %>.
            <% else %>
              No roster has been imported yet.
            <% end %>
            Upload the latest National roster to bring the post current.
          </p>
          <div class="tile-actions">
            <%= link_to "Import roster", new_admin_roster_import_path, class: "tile-btn" %>
            <%= link_to "View imports →", admin_roster_imports_path, class: "tile-act" %>
          </div>
        </div>
      <% end %>

      <% if show_agendas %>
        <div class="tile">
          <div class="tile-ic" aria-hidden="true">📋</div>
          <p class="tile-t">Agenda Catalog</p>
          <p class="tile-d">Standard agenda building blocks your post can drop into meeting templates.</p>
          <div class="tile-actions">
            <%= link_to "Open catalog →", admin_agenda_item_catalog_entries_path, class: "tile-act" %>
          </div>
        </div>
      <% end %>
    </div>
  </section>
<% end %>

<% if show_positions %>
  <section class="hub-sec">
    <h2 class="hub-sec-h">Officers &amp; Elections</h2>
    <p class="hub-sec-n">The offices your post fills and who holds them — usually only after an election.</p>
    <div class="hub-tiles">
      <div class="tile">
        <div class="tile-ic" aria-hidden="true">🎖️</div>
        <p class="tile-t">Post Positions</p>
        <p class="tile-d">The offices your post fills, their wording, and their order.</p>
        <div class="tile-actions">
          <%= link_to "Manage positions →", admin_position_titles_path, class: "tile-act" %>
        </div>
      </div>
    </div>
  </section>
<% end %>

<% if show_admins %>
  <section class="hub-sec">
    <h2 class="hub-sec-h">Setup &amp; Administration</h2>
    <p class="hub-sec-n">Accounts, access, and post details. Rarely changed.</p>
    <div class="hub-tiles">
      <div class="tile">
        <div class="tile-ic" aria-hidden="true">👥</div>
        <p class="tile-t">Administrators</p>
        <p class="tile-d">Who can administer the app. Permissions are granted on each person’s page.</p>
        <div class="tile-actions">
          <%= link_to "View administrators →", admin_administrators_path, class: "tile-act" %>
        </div>
      </div>
    </div>
  </section>
<% end %>
```

- [ ] **Step 6: Point the nav's Admin link at the hub for everyone**

In `app/views/shared/_primary_nav.html.erb`, replace:

```erb
    <% if current_user.can?("manage_settings") %>
      <%= link_to admin_root_path, class: "#{nav_tab_class(:admin)} nav-tab--admin" do %><span class="nav-dia">◆</span> Admin<% end %>
    <% elsif current_user.can?("manage_agendas") %>
      <%= link_to admin_agenda_item_catalog_entries_path, class: "#{nav_tab_class(:admin)} nav-tab--admin" do %><span class="nav-dia">◆</span> Admin<% end %>
    <% end %>
```

with:

```erb
    <% if current_user.can?("manage_settings") || current_user.can?("manage_agendas") %>
      <%= link_to admin_root_path, class: "#{nav_tab_class(:admin)} nav-tab--admin" do %><span class="nav-dia">◆</span> Admin<% end %>
    <% end %>
```

- [ ] **Step 7: Update the nav integration test**

In `test/integration/primary_nav_test.rb`, replace the test named `"agenda manager sees Admin tab linking to catalog"` (lines 53–59) with:

```ruby
  test "agenda manager sees Admin tab linking to the hub" do
    prepare_setup_complete_state
    sign_in_agenda_manager
    get root_path
    assert_select "nav.nav-bar a.nav-tab--admin[href=?]", admin_root_path, text: /Admin/
    assert_select "nav.nav-bar a.nav-tab--admin[href=?]", admin_agenda_item_catalog_entries_path, count: 0
  end
```

- [ ] **Step 8: Run the affected tests to verify they pass**

Run: `bin/rails test test/controllers/admin/dashboard_controller_test.rb test/integration/primary_nav_test.rb`
Expected: PASS.

- [ ] **Step 9: Rebuild CSS and run the full suite**

Run:
```bash
bin/rails tailwindcss:build
bin/rails test
```
Expected: CSS builds without error; full suite PASS.

- [ ] **Step 10: Commit**

```bash
git add app/controllers/admin/dashboard_controller.rb app/views/admin/dashboard/show.html.erb app/assets/tailwind/application.css app/assets/builds/tailwind.css app/views/shared/_primary_nav.html.erb test/controllers/admin/dashboard_controller_test.rb test/integration/primary_nav_test.rb
git commit -m "feat: reshape the admin dashboard into a capability-aware tile hub

Replace the four stacked panels with three topical sections of bounded
tiles (Meetings & Roster, Officers & Elections, Setup & Administration).
Roster status rides its own tile instead of a full-width banner. The hub is
now reachable to any admin-capable user and renders tiles per capability, so
the nav's Admin link points everyone at the hub.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Manual Verification

After Task 4, run the app and confirm the redesign in the browser (bind to `0.0.0.0` so it is reachable off-box):

```bash
bin/rails server -b 0.0.0.0
```

Check at `http://192.168.37.41:3000/admin`:
- As a full admin: three sections, four tiles, no full-width boxes; Roster tile shows its status pill; every tile link lands on its focused page.
- Tiles reflow to card-width (never stretched) as the window widens; a lone tile stays card-width.
- As an agenda-only manager (grant only `manage_agendas`): the Admin nav tab and the hub show just the Agenda Catalog tile.

---

## Self-Review

**Spec coverage:**
- Hub of bounded tiles in three topical, frequency-ordered sections → Task 4 (view + CSS).
- Roster status on its own tile, no full-width banner → Task 4 (roster tile + `.tile--due`).
- No "coming soon" tiles → Task 4 renders only the four real tiles.
- Capability-aware hub reachable to any admin; nav special-case removed → Task 4 (controller gate + nav).
- `manage_settings` superset over management capabilities, attestation acts excluded → Task 1.
- Post Positions and Administrators become focused pages → Tasks 2 and 3.
- Readability floors / no full-width / date format → Global Constraints; tile CSS honors floors; `legion_date` used.

**Placeholder scan:** none — every step contains full code and exact commands.

**Type/name consistency:** `admin_position_titles_path` (Task 2) and `admin_administrators_path` (Task 3) are produced before Task 4 consumes them; `PermissionGrant::IMPLIED_BY_MANAGE_SETTINGS` (Task 1) is referenced only by `User#can?`; CSS class names (`.hub-sec-h`, `.tile`, `.tile--due`, `.tile-status`, `.tile-t`, `.tile-act`, `.tile-btn`) match between the view (Task 4 Step 5), the CSS (Step 4), and the tests (Step 1).
