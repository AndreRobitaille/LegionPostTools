# Admin & Roster Redesign — Plan 2: People & Person (Two-View) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Depends on Plan 1** (component partials + helpers) being merged first.

**Goal:** Promote People to a first-class destination open to all signed-in members, rendered at permission-appropriate depth — a member sees a clean directory + a dignified comrade profile (contact, service, offices); an officer sees the data-rich list + the full record with login/permission/role controls.

**Architecture:** Move People out of the `admin` namespace to a top-level `PeopleController` gated only on authentication, with an `officer?` gate controlling depth. The existing per-person mutation controllers (`Admin::UserAccounts`, `Admin::PermissionGrants`, `Admin::PositionAssignments`) stay `manage_settings`-gated and keep nesting under `admin/people` (nesting-only), with their redirects re-pointed to the new top-level `person_path`. Views compose Plan 1's partials; exact markup follows the persisted mockups.

**Tech Stack:** Rails (Minitest, ERB), the Plan 1 component vocabulary.

## Global Constraints

(Inherits all Global Constraints from Plan 1 — readability floors, no full-width, `DD MMM YYYY`/`HH:MM`, red discipline, palette tokens, no new deps, `bin/rails test` / `bin/rubocop` / `bin/brakeman` clean.)

- **Two-view gates:** `officer?` = `current_user.can?("manage_people") || current_user.can?("manage_settings")` — controls whether officer *depth* (full record, roles list, sign-in state) is shown. `manage_settings` alone gates the *mutations* (enable/disable login, permissions, assign/end role, correct dates); a `manage_people`-only officer sees the officer view read-only. Regular members see the limited view.
- **Member-visible person fields:** name, office(s), branch, war era, continuous years, contact (email + phone). **Officer-only:** mailing address, dues/paid-through, member status, undeliverable, Member ID, login account & permissions, all edit controls.
- **Visual source of truth (mockups under `.superpowers/brainstorm/`):** `people-directory-v5.html` (officer list), `people-list-member.html` (member list), `person-officer-v3.html` (officer person), `person-member-v2.html` (member person).
- **View-porting convention:** where a step says "port to the mockup," reproduce that mockup's markup and classes, substituting Plan 1 partials (`shared/section_panel`, `shared/section_header`, `shared/member_row`, `shared/date_field`, `membership_status_tag`, `legion_date`) for the inline equivalents. The test in each such task pins the behavior and key copy; the mockup pins the pixels.

## Permission grouping (used by the person page and Plan 3)

This constant is introduced here and reused in Plan 3.

---

### Task 1: Permission groups constant

**Files:**
- Modify: `app/models/permission_grant.rb`
- Test: `test/models/permission_grant_test.rb`

**Interfaces:**
- Produces: `PermissionGrant::GROUPS -> Array<[String, Array<String>]>` — ordered `[group_label, [capability, …]]` pairs covering exactly the nine `CAPABILITIES`.

- [ ] **Step 1: Write the failing test** (append to `test/models/permission_grant_test.rb`)

```ruby
  test "GROUPS covers every capability exactly once in order" do
    grouped = PermissionGrant::GROUPS.flat_map { |(_label, caps)| caps }
    assert_equal PermissionGrant::CAPABILITIES.sort, grouped.sort
    assert_equal grouped, grouped.uniq
    assert_equal "Administration", PermissionGrant::GROUPS.first.first
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/permission_grant_test.rb`
Expected: FAIL (`uninitialized constant PermissionGrant::GROUPS`).

- [ ] **Step 3: Add the constant** (in `app/models/permission_grant.rb`, after `CAPABILITIES`)

```ruby
  GROUPS = [
    [ "Administration", %w[manage_settings manage_people] ],
    [ "Meetings", %w[manage_meeting_bodies manage_agendas manage_minutes] ],
    [ "Approvals", %w[approve_minutes attest_minutes record_acceptance_motions] ],
    [ "Records", %w[view_internal_records] ]
  ].freeze
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/permission_grant_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/models/permission_grant.rb test/models/permission_grant_test.rb
git commit -m "feat: add PermissionGrant::GROUPS for grouped permission display"
```

---

### Task 2: `officer?` gate + Person query helpers

**Files:**
- Modify: `app/controllers/application_controller.rb` (add `officer?` + `helper_method`)
- Modify: `app/models/person.rb` (add `roster_paid_through_display`, `service_summary`, `active_role_labels`)
- Test: `test/models/person_test.rb` (create if absent)

**Interfaces:**
- Produces:
  - `ApplicationController#officer? -> Boolean` (also a `helper_method`).
  - `Person#roster_paid_through_display -> String` — `"Paid up for life"` when membership type indicates PUFL, else `"Paid through: <year>"`, else `""`.
  - `Person#service_summary -> String` — `"U.S. Army · Vietnam"` from branch + war era (blank parts dropped).
  - `Person#active_role_labels(today = Date.current) -> Array<String>` — names of all currently-active offices.

- [ ] **Step 1: Write the failing model test**

```ruby
# test/models/person_test.rb
require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "service_summary joins branch and era, dropping blanks" do
    assert_equal "U.S. Army · Vietnam", Person.new(roster_branch: "U.S. Army", roster_war_era: "Vietnam").service_summary
    assert_equal "U.S. Army", Person.new(roster_branch: "U.S. Army").service_summary
    assert_equal "", Person.new.service_summary
  end

  test "roster_paid_through_display shows PUFL or the year" do
    assert_equal "Paid up for life", Person.new(roster_membership_type: "Paid Up For Life member").roster_paid_through_display
    assert_equal "Paid through: 2027", Person.new(roster_paid_through_year: 2027).roster_paid_through_display
    assert_equal "", Person.new.roster_paid_through_display
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/person_test.rb`
Expected: FAIL (`undefined method 'service_summary'`).

- [ ] **Step 3: Implement**

Add to `app/models/person.rb`:

```ruby
  def service_summary
    [ roster_branch, roster_war_era ].compact_blank.join(" · ")
  end

  def paid_up_for_life?
    roster_membership_type.to_s.downcase.include?("paid up for life")
  end

  def roster_paid_through_display
    return "Paid up for life" if paid_up_for_life?
    return "Paid through: #{roster_paid_through_year}" if roster_paid_through_year.present?

    ""
  end

  def active_role_labels(today = Date.current)
    position_assignments
      .select { |assignment| assignment.active_on?(today) }
      .sort_by { |assignment| [ assignment.position_title.display_order, assignment.position_title.name ] }
      .map { |assignment| assignment.position_title.name }
  end
```

Add to `app/controllers/application_controller.rb` (add `:officer?` to the existing `helper_method` on line 11, and define the method in the public section):

```ruby
  def officer?
    current_user&.can?("manage_people") || current_user&.can?("manage_settings")
  end
```

Line 11 becomes: `helper_method :current_user, :authenticated?, :officer?`

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/person_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/application_controller.rb app/models/person.rb test/models/person_test.rb
git commit -m "feat: add officer? gate and Person display helpers"
```

---

### Task 3: Routes — promote People to top-level; keep admin mutation nesting

**Files:**
- Modify: `config/routes.rb`

**Interfaces:**
- Produces: `people_path`, `person_path(person)`; the admin namespace keeps `admin_person_user_account_path`, `admin_person_position_assignments_path`, `admin_person_position_assignment_path`, `admin_user_permission_grants_path`, plus roster_imports.

- [ ] **Step 1: Edit `config/routes.rb`**

Add a top-level People resource (place near the other top-level resources, before the `namespace :admin` block):

```ruby
  resources :people, only: %i[index show]
```

Inside `namespace :admin do`, change `resources :people, only: %i[index show]` to nesting-only, and remove the now-duplicate second `resources :people` block by merging. The admin block's people lines become exactly:

```ruby
    resources :people, only: [] do
      resource :user_account, only: %i[create destroy]
      resources :position_assignments, only: %i[create update]
    end
```

(Delete the standalone `resources :people, only: %i[index show]` line at the top of the admin block. Leave `resources :users`, `resource :permission_grants`, and `resources :roster_imports` untouched. The `admin` root stays `dashboard#show`.)

- [ ] **Step 2: Verify routes resolve**

Run: `bin/rails routes | grep -E 'people|person'`
Expected: `people GET /people`, `person GET /people/:id`, and `admin_person_user_account`, `admin_person_position_assignments`, `admin_person_position_assignment` present. No `admin_people`/`admin_person` GET index/show.

- [ ] **Step 3: Commit** (tests will be red until Task 4/9 — commit routes with the controller in Task 4; skip standalone commit)

Defer commit; proceed to Task 4.

---

### Task 4: Top-level `PeopleController#index` (officer + member)

**Files:**
- Create: `app/controllers/people_controller.rb`
- Delete: `app/controllers/admin/people_controller.rb`
- Create: `app/views/people/index.html.erb`, `app/views/people/_member_directory.html.erb`, `app/views/people/_officer_directory.html.erb`
- Delete: `app/views/admin/people/index.html.erb`
- Test: rename `test/controllers/admin/people_controller_test.rb` → `test/controllers/people_controller_test.rb` and update paths

**Interfaces:**
- Consumes: `officer?` (Task 2), `Person` helpers (Task 2), `shared/member_row`, `shared/section_header`, `membership_status_tag`, `legion_date`.
- Produces: `GET /people` renders the officer directory for officers, the member directory otherwise.

- [ ] **Step 1: Write the failing controller test**

Rename the file and rewrite the index tests to the new route and gating. Create `test/controllers/people_controller_test.rb`:

```ruby
require "test_helper"

class PeopleControllerTest < ActionDispatch::IntegrationTest
  def prepare_setup_complete_state
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_officer
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
  end

  def sign_in_plain_member
    person = Person.create!(first_name: "Ann", last_name: "Roe")
    user = User.create!(person: person, email_address: "ann@example.com", email_verified_at: Time.current)
    sign_in_as(user)
  end

  test "officer index lists members with membership status column" do
    prepare_setup_complete_state
    sign_in_officer
    Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent", roster_member_status: "Active")
    get people_path
    assert_response :success
    assert_select "h1", "People"
    assert_select ".mrow-name", text: /Alber/
    assert_select ".mrow-status .st"
  end

  test "member index omits the membership status column" do
    prepare_setup_complete_state
    sign_in_plain_member
    Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent", roster_member_status: "Active")
    get people_path
    assert_response :success
    assert_select ".mrow-name", text: /Alber/
    assert_select ".mrow-status", count: 0
  end

  test "officer index search filters by name" do
    prepare_setup_complete_state
    sign_in_officer
    Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "1", roster_name: "Alber, Vincent")
    Person.create!(first_name: "Jane", last_name: "Roe", member_number: "2", roster_name: "Roe, Jane")
    get people_path, params: { q: "Vincent" }
    assert_select ".mrow-name", text: /Alber/
    assert_select ".mrow-name", text: /Roe, Jane/, count: 0
  end

  test "officer index filters by member status, paid year, and sign-in" do
    prepare_setup_complete_state
    sign_in_officer
    active = Person.create!(first_name: "A", last_name: "One", member_number: "1", roster_member_status: "Active", roster_paid_through_year: 2027)
    Person.create!(first_name: "B", last_name: "Two", member_number: "2", roster_member_status: "Expired", roster_paid_through_year: 2024)
    get people_path, params: { roster_member_status: "Active" }
    assert_select ".mrow-name", text: /One/
    assert_select ".mrow-name", text: /Two/, count: 0
    get people_path, params: { roster_paid_through_year: 2027 }
    assert_select ".mrow-name", text: /One/
    assert_select ".mrow-name", text: /Two/, count: 0
    User.create!(person: active, email_address: "a@example.com", email_verified_at: Time.current)
    get people_path, params: { login_status: "no_login" }
    assert_select ".mrow-name", text: /Two/
    assert_select ".mrow-name", text: /One/, count: 0
  end
end
```

Delete `test/controllers/admin/people_controller_test.rb` (the `show` tests move to Task 5's new file).

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/people_controller_test.rb`
Expected: FAIL (`uninitialized constant PeopleController` / routing error).

- [ ] **Step 3: Create the controller** (port the existing Admin::PeopleController#index query verbatim; add officer branch + filter option data)

```ruby
# app/controllers/people_controller.rb
class PeopleController < ApplicationController
  before_action :require_authentication

  def index
    scope = Person.left_outer_joins(:user).includes(:user, position_assignments: :position_title)
                  .order(:last_name, :first_name)

    if params[:q].present?
      scope = scope.where(
        "first_name ILIKE :q OR last_name ILIKE :q OR roster_name ILIKE :q OR member_number ILIKE :q",
        q: "%#{params[:q]}%"
      )
    end

    if officer?
      scope = apply_officer_filters(scope)
      @filter_options = build_filter_options
    end

    people = scope.limit(500).to_a
    @officers = people.select { |person| person.active_role_labels.any? }
    @members = people - @officers

    render officer? ? :index : :index
  end

  private

  def apply_officer_filters(scope)
    scope = scope.where(roster_member_status: params[:roster_member_status]) if params[:roster_member_status].present?
    scope = scope.where(roster_paid_through_year: params[:roster_paid_through_year]) if params[:roster_paid_through_year].present?
    case params[:login_status]
    when "enabled"  then scope.where.not(users: { id: nil }).where(users: { disabled_at: nil })
    when "disabled" then scope.where.not(users: { id: nil }).where.not(users: { disabled_at: nil })
    when "no_login" then scope.where(users: { id: nil })
    else scope
    end
  end

  def build_filter_options
    {
      statuses: Person.where.not(roster_member_status: [ nil, "" ]).distinct.order(:roster_member_status).pluck(:roster_member_status),
      years: Person.where.not(roster_paid_through_year: nil).distinct.order(roster_paid_through_year: :desc).pluck(:roster_paid_through_year)
    }
  end
end
```

Note: `render officer? ? :index : :index` renders one template that branches on `officer?`; the branch lives in the view (Step 4). Delete `app/controllers/admin/people_controller.rb`.

- [ ] **Step 4: Create the index view + directory partials**

`app/views/people/index.html.erb` — page head (title "People", member count), and:

```erb
<% if officer? %>
  <%= render "officer_directory" %>
<% else %>
  <%= render "member_directory" %>
<% end %>
```

Build `_officer_directory.html.erb` to match `people-directory-v5.html`: the search field, the filter bar (Member status + Paid through as `select`s populated from `@filter_options`, "Can sign in?" select mapping to `login_status`), a Sort control, then a `.sec-head` "Post Officers" + a `.mrow-list` of `shared/member_row` for `@officers` (with `membership: true`, `status_tag: membership_status_tag(person.roster_member_status)`, `status_lines: [person.roster_paid_through_display.presence || "…", signin_line(person)]`), then "All Members" + `@members`. Build `_member_directory.html.erb` to match `people-list-member.html`: search + sort, "Post Officers"/"All Members" `shared/member_row` with `membership: false`, `office:` the person's `active_role_labels.first`, `subline:` `person.service_summary`.

Add a small private helper for the sign-in line. Create `app/helpers/people_helper.rb`:

```ruby
module PeopleHelper
  def signin_line(person)
    user = person.user
    state = if user.nil? then "No account"
            elsif user.disabled_at.present? then "No"
            else "Yes"
            end
    "Sign-in: #{state}"
  end
end
```

Wrap the `.mrow-list` in `<div class="mrow-list">…</div>` and add its CSS to `app/assets/tailwind/application.css`:

```css
.mrow-list { border: 1px solid #eadfbf; border-radius: 10px; overflow: hidden; background: var(--color-ivory); margin-bottom: 22px; }
.mrow-list .mrow:first-child { border-top: none; }
```

Exact classes for the toolbar/filter bar/sort come from `people-directory-v5.html` (`.search`, `.filterbar`, `.fl`, `.sort`) — reproduce them into `application.css` under a `/* People directory toolbar */` comment.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/people_controller_test.rb`
Expected: PASS (4 runs, 0 failures).

- [ ] **Step 6: Commit** (routes from Task 3 + controller + views together)

```bash
git add config/routes.rb app/controllers/people_controller.rb app/views/people/ app/helpers/people_helper.rb app/assets/tailwind/application.css test/controllers/people_controller_test.rb
git rm app/controllers/admin/people_controller.rb app/views/admin/people/index.html.erb test/controllers/admin/people_controller_test.rb
git commit -m "feat: promote People to top-level directory with officer/member views"
```

---

### Task 5: `PeopleController#show` (officer + member person page)

**Files:**
- Modify: `app/controllers/people_controller.rb` (add `show`)
- Create: `app/views/people/show.html.erb`, `_officer_person.html.erb`, `_member_person.html.erb`, `_login_account.html.erb`, `_permission_groups.html.erb`, `_post_roles.html.erb`
- Delete: `app/views/admin/people/show.html.erb`
- Test: `test/controllers/people_show_test.rb`

**Interfaces:**
- Consumes: `officer?`, `manage_settings` via `current_user.can?`, Plan 1 partials (`shared/section_panel`, `shared/date_field`), `PermissionGrant::GROUPS`, `Person` helpers, `legion_date`.
- Produces: `GET /people/:id` renders the officer person page (record + login account + roles) for officers with mutation forms only when `can?("manage_settings")`; the member comrade profile otherwise.

- [ ] **Step 1: Write the failing test** (port the `show` assertions from the old admin people test, updated to new routes/markup)

```ruby
# test/controllers/people_show_test.rb
require "test_helper"

class PeopleShowTest < ActionDispatch::IntegrationTest
  def prepare_setup_complete_state
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_officer
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
  end

  def sign_in_plain_member
    person = Person.create!(first_name: "Ann", last_name: "Roe")
    user = User.create!(person: person, email_address: "ann@example.com", email_verified_at: Time.current)
    sign_in_as(user)
  end

  def build_person
    Person.create!(first_name: "Vincent", last_name: "Alber", member_number: "000204540637", roster_name: "Alber, Vincent",
      roster_member_status: "Active", roster_paid_through_year: 2027, roster_email_address: "vincent@example.com",
      roster_phone_number: "555-1212", roster_branch: "U.S. Army", roster_war_era: "Vietnam", roster_continuous_years: 12,
      roster_undeliverable: false, roster_address: "123 Main St", roster_imported_at: Time.current)
  end

  test "officer sees the full record with login and role controls" do
    prepare_setup_complete_state
    sign_in_officer
    person = build_person
    user = User.create!(person: person, email_address: "vincent.alt@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_people")
    get person_path(person)
    assert_response :success
    assert_select "h1", "Alber, Vincent"
    assert_select ".card-head-label", text: /Roster Record/
    assert_select ".card-head-label", text: /Login Account/
    assert_select "input[type=email][name=?]", "user[email_address]", count: 0 # roster fields read-only
    assert_select "p", /123 Main St/ # officer sees address
    assert_select "form[action=?]", admin_user_permission_grants_path(user)
    assert_select "input[type=submit][value=?], button", text: /Disable sign-in/
  end

  test "member sees contact, service, and roles but no record or controls" do
    prepare_setup_complete_state
    sign_in_plain_member
    person = build_person
    person.position_assignments.create!(
      position_title: PositionTitle.create!(organization: Organization.first, name: "Commander", display_order: 1),
      starts_on: Date.new(2026, 1, 1)
    )
    get person_path(person)
    assert_response :success
    assert_select ".card-head-label", text: /Contact/
    assert_select ".card-head-label", text: /Service/
    assert_select ".card-head-label", text: /Post Roles/
    assert_select "a[href=?]", "mailto:vincent@example.com"
    assert_select ".card-head-label", text: /Roster Record/, count: 0
    assert_select ".card-head-label", text: /Login Account/, count: 0
    assert_select "body", text: /123 Main St/, count: 0 # address hidden from members
  end

  test "manage_people officer sees officer view but not mutation forms" do
    prepare_setup_complete_state
    person_officer = Person.create!(first_name: "Pat", last_name: "Lee")
    officer_user = User.create!(person: person_officer, email_address: "pat@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: officer_user, capability: "manage_people")
    sign_in_as(officer_user)
    person = build_person
    get person_path(person)
    assert_response :success
    assert_select ".card-head-label", text: /Roster Record/
    assert_select "input[type=submit][value=?], button", text: /Disable sign-in/, count: 0
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/people_show_test.rb`
Expected: FAIL (no `show` action / template).

- [ ] **Step 3: Add the `show` action**

```ruby
  def show
    @person = Person.includes(:user, position_assignments: :position_title).find(params[:id])
    @user = @person.user
    @can_manage = current_user.can?("manage_settings")
    if officer?
      @position_assignment = @person.position_assignments.new
      @position_titles = PositionTitle.where(active: true).order(:display_order, :name)
    end
  end
```

- [ ] **Step 4: Build the views**

`show.html.erb`:

```erb
<% content_for :title, @person.roster_display_name %>
<a class="back" href="<%= people_path %>">← People</a>
<% if officer? %>
  <%= render "officer_person" %>
<% else %>
  <%= render "member_person" %>
<% end %>
```

- `_officer_person.html.erb` → port `person-officer-v3.html`: identity header (name, `active_role_labels.first` as office, `membership_status_tag`), then `shared/section_panel` for Roster Record (read-only `<dl>`/grid of roster fields incl. address; provenance `"National roster · imported #{legion_date(@person.roster_imported_at)}"`); then `render "login_account"` inside a section panel; then `render "post_roles"` inside a section panel.
- `_login_account.html.erb` → the account line + `roster_email_mismatch?` warning (buttons post to `roster_email_review_path` PATCH with `decision`), then `render "permission_groups"` (only when `@can_manage`), then the "Disable sign-in" `button_to admin_person_user_account_path(@person), method: :delete` with helper text (only when `@can_manage`). When no `@user`: an enable-login form posting to `admin_person_user_account_path(@person)` with `user[email_address]` prefilled to `@person.roster_email_address`. When disabled: re-enable form (same create action). Preserve the existing controller contract exactly (it keys off `user[email_address]` and toggles `disabled_at`).
- `_permission_groups.html.erb`:

```erb
<%= form_with url: admin_user_permission_grants_path(@user), method: :patch do |f| %>
  <div class="permhead">Permissions</div>
  <p class="permsub">What this member can do in the app.</p>
  <% PermissionGrant::GROUPS.each do |label, caps| %>
    <div class="pg">
      <div class="gname"><%= label %></div>
      <% caps.each do |cap| %>
        <label class="perm">
          <%= check_box_tag "permission_grant[capabilities][]", cap, @user.can?(cap) %>
          <%= cap.humanize %>
        </label>
      <% end %>
    </div>
  <% end %>
  <div class="btnrow"><%= f.submit "Save permissions", class: "btn-primary" %></div>
<% end %>
```

- `_post_roles.html.erb` → port `person-officer-v3.html` roles: for each `@person.position_assignments` (ordered), the role name + `legion_date(starts_on)`/`legion_date(ends_on)` or "Present"; when `@can_manage`, an "Edit dates" form (update action) using `shared/date_field` for `position_assignment[starts_on]` and `position_assignment[ends_on]`, and for open roles an "End role" control; then the assign form (`shared/date_field` for `position_assignment[starts_on]`, `collection_select` of `@position_titles`) posting to `admin_person_position_assignments_path(@person)`.
- `_member_person.html.erb` → port `person-member-v2.html`: identity (name, office, `service_summary`), `shared/section_panel` Contact (mailto/tel links to `roster_email_address`/`roster_phone_number`), Service (branch, war era, continuous years honor), Post Roles (read-only list). No record/account/controls; never renders address.

Reproduce the supporting CSS (`.back`, `.permhead`, `.permsub`, `.pg`, `.gname`, `.perm`, `.honor`, `.crow`, etc.) from the mockups into `application.css`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/people_show_test.rb`
Expected: PASS (3 runs, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add app/controllers/people_controller.rb app/views/people/ app/assets/tailwind/application.css test/controllers/people_show_test.rb
git rm app/views/admin/people/show.html.erb
git commit -m "feat: officer/member person pages with grouped permissions and role controls"
```

---

### Task 6: Editable role start dates + `DD MMM YYYY` parsing

**Files:**
- Modify: `app/controllers/admin/position_assignments_controller.rb` (accept `starts_on` on update; parse typed dates)
- Test: `test/controllers/admin/position_assignments_controller_test.rb`

**Interfaces:**
- Consumes: `parse_legion_date` (Plan 1 Task 1).
- Produces: `PATCH admin_person_position_assignment_path` accepts a corrected `starts_on` and/or `ends_on` in `DD MMM YYYY`; `POST …position_assignments` accepts `starts_on` in `DD MMM YYYY`.

- [ ] **Step 1: Write the failing test** (append to the existing controller test; create the file if missing, following the `sign_in_member`/`prepare_setup_complete_state` pattern from other admin controller tests)

```ruby
  test "update corrects both start and end dates from DD MMM YYYY text" do
    prepare_setup_complete_state
    sign_in_admin
    person = Person.create!(first_name: "V", last_name: "A")
    title = PositionTitle.create!(organization: Organization.first, name: "Commander", display_order: 1)
    assignment = person.position_assignments.create!(position_title: title, starts_on: Date.new(2026, 1, 1))

    patch admin_person_position_assignment_path(person, assignment),
      params: { position_assignment: { starts_on: "02 FEB 2023", ends_on: "31 DEC 2025" } }

    assignment.reload
    assert_equal Date.new(2023, 2, 2), assignment.starts_on
    assert_equal Date.new(2025, 12, 31), assignment.ends_on
  end
```

(Add `sign_in_admin` mirroring the `sign_in_member` helper used in `test/controllers/admin/user_accounts_controller_test.rb`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/admin/position_assignments_controller_test.rb`
Expected: FAIL (`starts_on` unchanged — update only permits `ends_on`, and text isn't parsed).

- [ ] **Step 3: Implement — parse typed dates and permit `starts_on` on update**

Replace the private params methods and `update`/`create` date handling in `app/controllers/admin/position_assignments_controller.rb`:

```ruby
    def update
      @person = Person.find(params[:person_id])
      @position_assignment = @person.position_assignments.find(params[:id])

      if @position_assignment.update(dated_update_params)
        redirect_to person_path(@person), notice: "Post role updated."
      else
        redirect_to person_path(@person), alert: @position_assignment.errors.full_messages.to_sentence
      end
    end

    private

    def position_assignment_params
      raw = params.require(:position_assignment).permit(:position_title_id, :starts_on, :ends_on)
      raw.merge(starts_on: coerce_date(raw[:starts_on]), ends_on: coerce_date(raw[:ends_on]))
    end

    def dated_update_params
      raw = params.require(:position_assignment).permit(:starts_on, :ends_on)
      permitted = {}
      permitted[:starts_on] = coerce_date(raw[:starts_on]) if raw.key?(:starts_on)
      permitted[:ends_on] = coerce_date(raw[:ends_on]) if raw.key?(:ends_on)
      permitted
    end

    def coerce_date(value)
      return nil if value.blank?

      parse_legion_date(value) || value
    end
```

Update `create` to use `position_assignment_params.except(:position_title_id)` as before (it already does) and redirect to `person_path`. Change the two `redirect_to admin_person_path(@person)` in `create` to `redirect_to person_path(@person)`.

Note: `parse_legion_date` is a helper; make it available to the controller by adding `include LegionFormatHelper` at the top of the controller class (it is a plain module method with no view dependency).

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/admin/position_assignments_controller_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/position_assignments_controller.rb test/controllers/admin/position_assignments_controller_test.rb
git commit -m "feat: correct role start/end dates via DD MMM YYYY input"
```

---

### Task 7: Re-point mutation redirects + nav People link; fix remaining tests

**Files:**
- Modify: `app/controllers/admin/user_accounts_controller.rb`, `app/controllers/admin/permission_grants_controller.rb` (redirects `admin_person_path` → `person_path`)
- Modify: `app/views/shared/_primary_nav.html.erb` (People link → `people_path`, ungate)
- Modify: `test/integration/primary_nav_test.rb`, `test/controllers/admin/user_accounts_controller_test.rb`, `test/controllers/admin/permission_grants_controller_test.rb`

**Interfaces:**
- Consumes: `people_path`, `person_path` (Task 3).
- Produces: all per-person mutations redirect to the top-level person page; the People tab shows for every signed-in member.

- [ ] **Step 1: Re-point redirects**

In `admin/user_accounts_controller.rb` and `admin/permission_grants_controller.rb`, replace every `admin_person_path(...)` with `person_path(...)` (there are several in each — `redirect_to admin_person_path(@person)` and `admin_person_path(@user.person)`).

- [ ] **Step 2: Update the nav partial**

In `app/views/shared/_primary_nav.html.erb`, replace the gated People block:

```erb
    <% if current_user.can?("manage_settings") %>
      <%= link_to "People", admin_people_path, class: nav_tab_class(:people) %>
    <% end %>
```

with (ungated, top-level path):

```erb
    <%= link_to "People", people_path, class: nav_tab_class(:people) %>
```

- [ ] **Step 3: Update the affected tests**

- `test/integration/primary_nav_test.rb`: the "plain member does not see People" test now expects People to show; change it to assert the member **does** see People (`assert_select "nav.nav-bar a.nav-tab", text: "People"`) but not Admin.
- `test/controllers/admin/user_accounts_controller_test.rb` and `permission_grants_controller_test.rb`: change any `assert_redirected_to admin_person_path(...)` to `person_path(...)`.

- [ ] **Step 4: Run the full suite**

Run: `bin/rails test`
Expected: PASS (all green — the People/person tests from Tasks 4–6, nav, and the re-pointed mutation controllers).

- [ ] **Step 5: Lint, security, commit**

Run: `bin/rubocop` → no offenses. Run: `bin/brakeman` → 0 warnings.

```bash
git add app/controllers/admin/user_accounts_controller.rb app/controllers/admin/permission_grants_controller.rb app/views/shared/_primary_nav.html.erb test/
git commit -m "refactor: re-point person mutations to top-level person page; open People tab to all members"
```

---

## Self-Review

**Spec coverage (Plan 2 scope):**
- People first-class, open to all members → Tasks 3, 4, 7. ✓
- Officer vs member list (columns, filters) → Task 4. ✓
- Officer vs member person page + field visibility (address/contact) → Task 5. ✓
- Grouped permissions (always-visible vertical checklist) → Tasks 1, 5. ✓
- Editable role start/end dates via type-or-pick + `DD MMM YYYY` → Task 6. ✓
- `officer?` (manage_people||manage_settings) depth vs `manage_settings` mutations → Tasks 2, 5. ✓
- Deferred (noted): finer `manage_people`-for-roles mutation split stays `manage_settings` for now.

**Placeholder scan:** View-porting steps (Tasks 4, 5) reference the persisted mockups for exact markup — the spec designates these the visual source of truth, and each such task carries a controller test pinning behavior and key copy. No "TBD"/"add validation". The date coercion, filters, and gating show complete code.

**Type consistency:** `officer?` (Task 2) used in Tasks 4/5; `PermissionGrant::GROUPS` (Task 1) used in Task 5; `parse_legion_date`/`legion_date`/`membership_status_tag`/`shared/member_row`/`shared/date_field` all from Plan 1; `people_path`/`person_path`/`admin_person_user_account_path`/`admin_user_permission_grants_path` consistent across routes (Task 3) and consumers (Tasks 5–7).

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-12-admin-roster-plan-2-people-person.md`.** Execute after Plan 1 (subagent-driven recommended). Plan 3 (roster import behaviors + screens + Admin landing) follows.
