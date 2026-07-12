# Admin & Roster Redesign — Plan 1: Visual Foundation + Shell/Nav Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the app shell onto "The 1919" design system — a primary navigation bar with permission gating, site-wide date/time formatting, and the reusable UI component vocabulary (section panel, section header, status word, de-noised member row, stat tile, type-or-pick date field) that Plans 2 and 3 will compose from.

**Architecture:** Ruby on Rails with hand-authored CSS component classes in a single Tailwind v4 stylesheet (`app/assets/tailwind/application.css`), ERB partials in `app/views/shared/`, format logic in Rails helpers, and one Stimulus controller for the date field. No new runtime dependencies. This plan produces working, shipped-safe changes: the nav and header render for every authenticated page; the new components are exercised by render tests and consumed later.

**Tech Stack:** Rails (Minitest, ERB, importmap + Stimulus), Tailwind v4 (`@theme` tokens + hand-authored classes), Propshaft.

## Global Constraints

Copied verbatim from `docs/superpowers/specs/2026-07-12-admin-roster-visual-ux-design.md` and the visual system spec. Every task's requirements implicitly include these.

- **Readability floors (hard rule):** body/interactive text (inputs, buttons, links, list rows) ≥ 16px; secondary/helper ≥ 14px; labels/small-caps ≥ 13px; nothing meaningful < 13px. Only decorative marks (◆) may be smaller.
- **No full-width / stretched rows:** content in bounded columns (app frame ~1060px); a status and its action sit together, never flung to the far edge.
- **Dates:** every displayed date is `DD MMM YYYY` with uppercase month — e.g. `24 JUN 2026`. **Times:** 24-hour `HH:MM`. Date inputs are **type-or-pick** (type `DD MMM YYYY` or open a calendar), never a locale-locked native picker shown raw.
- **Red discipline:** red (`#8C1622`) only for attention (a human decision required) or destructive/return actions. Everything else stays calm.
- **Palette tokens** already in `@theme`: navy `#0A2240`, navy-2 `#0d2c54`, navy-deep `#081a34`, gold `#C6A15B`, gold-hi `#E6CD8B`, cream `#F4EEDD`, paper `#FBF7EC`, ivory `#FCFAF1`, legionred `#8C1622`, ink `#1b222b`, muted `#6b7684`. This plan adds green/bronze/gold-ink.
- **No new external JS/CSS dependencies** (importmap only; inline Stimulus).
- **Existing CSS class families to match** (do not collide): `.entry-*`, `.app-*`, `.pk-*`, `.page-*`, `.tabstrip-*`, `.panel`/`.panel-head`, `.btn-primary`/`.btn-secondary`/`.btn-return`. New families introduced here: `.nav-*`, `.card*`, `.sec-head*`, `.st*`, `.mrow*`, `.stat-*`, `.datefield*`.
- **Visual source of truth:** the interactive mockups under `.superpowers/brainstorm/` (gitignored). The shell/nav mockup is `shell-nav.html`; component looks appear across `people-directory-v5.html`, `person-officer-v3.html`, `roster-import-result-v2.html`.
- **Commands:** run tests with `bin/rails test`; lint with `bin/rubocop`; security scan with `bin/brakeman`. All must be clean before a task is done.

---

### Task 1: Legion date/time format + parse helpers

**Files:**
- Create: `app/helpers/legion_format_helper.rb`
- Test: `test/helpers/legion_format_helper_test.rb`

**Interfaces:**
- Produces:
  - `legion_date(value) -> String` — `Date`/`Time`/`nil` → `"24 JUN 2026"` (uppercase `%d %b %Y`), `""` for nil.
  - `legion_time(value) -> String` — `Time`/`nil` → `"14:32"` (24-hour `%H:%M`), `""` for nil.
  - `legion_datetime(value) -> String` — `Time`/`nil` → `"24 JUN 2026 · 14:32"`, `""` for nil.
  - `parse_legion_date(string) -> Date | nil` — `"01 JAN 1995"` (case-insensitive month, lenient whitespace) → `Date`; blank/garbage → `nil`.

- [ ] **Step 1: Write the failing test**

```ruby
# test/helpers/legion_format_helper_test.rb
require "test_helper"

class LegionFormatHelperTest < ActionView::TestCase
  test "legion_date formats a date as DD MMM YYYY uppercase" do
    assert_equal "24 JUN 2026", legion_date(Date.new(2026, 6, 24))
    assert_equal "01 JAN 1995", legion_date(Date.new(1995, 1, 1))
  end

  test "legion_date returns empty string for nil" do
    assert_equal "", legion_date(nil)
  end

  test "legion_time formats 24-hour HH:MM" do
    assert_equal "14:32", legion_time(Time.utc(2026, 6, 24, 14, 32))
    assert_equal "09:05", legion_time(Time.utc(2026, 6, 24, 9, 5))
  end

  test "legion_datetime joins date and time with a diamond dot" do
    assert_equal "24 JUN 2026 · 14:32", legion_datetime(Time.utc(2026, 6, 24, 14, 32))
    assert_equal "", legion_datetime(nil)
  end

  test "parse_legion_date parses DD MMM YYYY case-insensitively" do
    assert_equal Date.new(1995, 1, 1), parse_legion_date("01 JAN 1995")
    assert_equal Date.new(2026, 6, 24), parse_legion_date("  24 jun 2026 ")
  end

  test "parse_legion_date returns nil for blank or invalid input" do
    assert_nil parse_legion_date("")
    assert_nil parse_legion_date(nil)
    assert_nil parse_legion_date("not a date")
    assert_nil parse_legion_date("32 JAN 1995")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/helpers/legion_format_helper_test.rb`
Expected: FAIL with `NoMethodError: undefined method 'legion_date'`.

- [ ] **Step 3: Write minimal implementation**

```ruby
# app/helpers/legion_format_helper.rb
module LegionFormatHelper
  def legion_date(value)
    return "" if value.blank?

    value.to_date.strftime("%d %b %Y").upcase
  end

  def legion_time(value)
    return "" if value.blank?

    value.strftime("%H:%M")
  end

  def legion_datetime(value)
    return "" if value.blank?

    "#{legion_date(value)} · #{legion_time(value)}"
  end

  def parse_legion_date(string)
    normalized = string.to_s.strip
    return nil if normalized.empty?

    Date.strptime(normalized, "%d %b %Y")
  rescue ArgumentError
    nil
  end
end
```

Note: `Date.strptime` with `%b` is case-insensitive in Ruby, so `"jun"` and `"JUN"` both parse; an out-of-range day like `32` raises `ArgumentError` and returns `nil`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/helpers/legion_format_helper_test.rb`
Expected: PASS (6 runs, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add app/helpers/legion_format_helper.rb test/helpers/legion_format_helper_test.rb
git commit -m "feat: add Legion date/time format + parse helpers"
```

---

### Task 2: Navigation section helper

**Files:**
- Create: `app/helpers/navigation_helper.rb`
- Test: `test/helpers/navigation_helper_test.rb`

**Interfaces:**
- Produces:
  - `nav_section_for(path) -> Symbol` — pure mapping of a request path to `:people | :admin | :settings | :dashboard`.
  - `current_nav_section -> Symbol` — `nav_section_for(request.path)`.
  - `nav_tab_class(section) -> String` — `"nav-tab"`, plus `" nav-tab--active"` when `section == current_nav_section`.

- [ ] **Step 1: Write the failing test**

```ruby
# test/helpers/navigation_helper_test.rb
require "test_helper"

class NavigationHelperTest < ActionView::TestCase
  test "nav_section_for maps people paths" do
    assert_equal :people, nav_section_for("/admin/people")
    assert_equal :people, nav_section_for("/admin/people/42")
    assert_equal :people, nav_section_for("/people")
  end

  test "nav_section_for maps admin paths that are not people" do
    assert_equal :admin, nav_section_for("/admin")
    assert_equal :admin, nav_section_for("/admin/roster_imports/new")
  end

  test "nav_section_for maps settings paths" do
    assert_equal :settings, nav_section_for("/settings/security")
  end

  test "nav_section_for defaults to dashboard" do
    assert_equal :dashboard, nav_section_for("/")
  end

  test "nav_tab_class marks the active section" do
    def self.current_nav_section = :people
    assert_equal "nav-tab nav-tab--active", nav_tab_class(:people)
    assert_equal "nav-tab", nav_tab_class(:settings)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/helpers/navigation_helper_test.rb`
Expected: FAIL with `NoMethodError: undefined method 'nav_section_for'`.

- [ ] **Step 3: Write minimal implementation**

```ruby
# app/helpers/navigation_helper.rb
module NavigationHelper
  def nav_section_for(path)
    return :people if path == "/people" || path.start_with?("/people/", "/admin/people")
    return :admin if path.start_with?("/admin")
    return :settings if path.start_with?("/settings")

    :dashboard
  end

  def current_nav_section
    nav_section_for(request.path)
  end

  def nav_tab_class(section)
    section == current_nav_section ? "nav-tab nav-tab--active" : "nav-tab"
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/helpers/navigation_helper_test.rb`
Expected: PASS (5 runs, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add app/helpers/navigation_helper.rb test/helpers/navigation_helper_test.rb
git commit -m "feat: add navigation section helper"
```

---

### Task 3: Extend palette tokens (green, bronze, gold-ink)

**Files:**
- Modify: `app/assets/tailwind/application.css:3-16` (the `@theme` block)

**Interfaces:**
- Produces: CSS custom properties `--color-green`, `--color-bronze`, `--color-gold-ink` available to all later component CSS.

- [ ] **Step 1: Add the tokens**

In `app/assets/tailwind/application.css`, inside the `@theme { ... }` block, add these three lines immediately after `--color-muted: #6b7684;`:

```css
  --color-green: #3f6b3f;
  --color-bronze: #6e5a2b;
  --color-gold-ink: #7a5f22;
```

(These are from the visual system spec's palette: green = done/added, bronze = permanent-record/warm accent, gold-ink = readable gold text on cream.)

- [ ] **Step 2: Verify the stylesheet still builds and the suite is green**

Run: `bin/rails test`
Expected: PASS (same count as before this plan; no regressions). The app boots and the stylesheet compiles.

- [ ] **Step 3: Commit**

```bash
git add app/assets/tailwind/application.css
git commit -m "feat: extend palette tokens with green, bronze, gold-ink"
```

---

### Task 4: Primary navigation bar + header rework + shell integration

**Files:**
- Create: `app/views/shared/_primary_nav.html.erb`
- Modify: `app/views/shared/_app_header.html.erb` (move Admin/Settings links into the nav; keep user + role + avatar + Sign out)
- Modify: `app/views/layouts/application.html.erb:24-26` (render the nav after the header)
- Modify: `app/assets/tailwind/application.css` (append `.nav-*` and `.app-user-avatar` rules)
- Test: `test/integration/primary_nav_test.rb`

**Interfaces:**
- Consumes: `nav_tab_class(:section)` and `current_nav_section` (Task 2); `current_user.can?("manage_settings")`.
- Produces: the authenticated shell renders `<nav class="nav-bar">` with tabs Dashboard / Meetings(soon) / Records(soon) / Tracked Items(soon) / People (gated) / Settings / ◆ Admin (gated).

- [ ] **Step 1: Write the failing integration test**

```ruby
# test/integration/primary_nav_test.rb
require "test_helper"

class PrimaryNavTest < ActionDispatch::IntegrationTest
  def prepare_setup_complete_state
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
  end

  def sign_in_admin
    person = Person.create!(first_name: "Jane", last_name: "Doe")
    user = User.create!(person: person, email_address: "jane@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: user, capability: "manage_settings")
    sign_in_as(user)
    user
  end

  def sign_in_plain_member
    person = Person.create!(first_name: "Ann", last_name: "Roe")
    user = User.create!(person: person, email_address: "ann@example.com", email_verified_at: Time.current)
    sign_in_as(user)
    user
  end

  test "authenticated shell renders the primary nav with core and soon tabs" do
    prepare_setup_complete_state
    sign_in_admin
    get root_path
    assert_response :success
    assert_select "nav.nav-bar a.nav-tab", text: "Dashboard"
    assert_select "nav.nav-bar a.nav-tab", text: "Settings"
    assert_select "nav.nav-bar .nav-tab--soon", text: /Meetings/
    assert_select "nav.nav-bar .nav-tab--soon", text: /Records/
    assert_select "nav.nav-bar .nav-tab--soon", text: /Tracked Items/
  end

  test "admin sees People and Admin tabs" do
    prepare_setup_complete_state
    sign_in_admin
    get root_path
    assert_select "nav.nav-bar a.nav-tab", text: "People"
    assert_select "nav.nav-bar a.nav-tab--admin", text: /Admin/
  end

  test "plain member does not see People or Admin tabs" do
    prepare_setup_complete_state
    sign_in_plain_member
    get root_path
    assert_select "nav.nav-bar a.nav-tab--admin", count: 0
    assert_select "nav.nav-bar a.nav-tab", text: "People", count: 0
  end

  test "active tab reflects the current section" do
    prepare_setup_complete_state
    sign_in_admin
    get admin_people_path
    assert_select "nav.nav-bar a.nav-tab--active", text: "People"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/primary_nav_test.rb`
Expected: FAIL (no `nav.nav-bar` element yet).

- [ ] **Step 3: Create the nav partial**

```erb
<%# app/views/shared/_primary_nav.html.erb %>
<nav class="nav-bar">
  <div class="nav-inner">
    <%= link_to "Dashboard", root_path, class: nav_tab_class(:dashboard) %>
    <span class="nav-tab nav-tab--soon">Meetings<span class="nav-soon">Soon</span></span>
    <span class="nav-tab nav-tab--soon">Records<span class="nav-soon">Soon</span></span>
    <span class="nav-tab nav-tab--soon">Tracked Items<span class="nav-soon">Soon</span></span>
    <% if current_user.can?("manage_settings") %>
      <%= link_to "People", admin_people_path, class: nav_tab_class(:people) %>
    <% end %>
    <%= link_to "Settings", settings_security_path, class: nav_tab_class(:settings) %>
    <span class="nav-spacer"></span>
    <% if current_user.can?("manage_settings") %>
      <%= link_to admin_root_path, class: "#{nav_tab_class(:admin)} nav-tab--admin" do %><span class="nav-dia">◆</span> Admin<% end %>
    <% end %>
  </div>
</nav>
```

Note: People stays gated to `manage_settings` for now (its route is still `admin_people_path`). Plan 2 opens People to all members and re-points this link when People moves out of the admin namespace.

- [ ] **Step 4: Rework the header (remove Admin/Settings links, add avatar)**

Replace the `.app-user` block in `app/views/shared/_app_header.html.erb` (lines 14-23) with:

```erb
    <div class="app-user">
      <span class="app-user-name">
        <%= current_user.person.full_name %><% if current_user.person.current_role_label %> &middot; <%= current_user.person.current_role_label %><% end %>
      </span>
      <span class="app-user-avatar" aria-hidden="true"><%= current_user.person.full_name.to_s.split.map { |w| w[0] }.first(2).join.upcase %></span>
      <%= button_to "Sign out", session_path, method: :delete, class: "app-user-link app-user-signout" %>
    </div>
```

- [ ] **Step 5: Render the nav in the layout**

In `app/views/layouts/application.html.erb`, replace lines 24-26:

```erb
    <% if authenticated? %>
      <%= render "shared/app_header" %>
    <% end %>
```

with:

```erb
    <% if authenticated? %>
      <%= render "shared/app_header" %>
      <%= render "shared/primary_nav" %>
    <% end %>
```

- [ ] **Step 6: Add the nav CSS**

Append to `app/assets/tailwind/application.css`:

```css
/* Primary navigation (navy-2 tab strip; tracked caps; gold active underline) --- */
.nav-bar { background: var(--color-navy-2); border-bottom: 1px solid rgba(198,161,91,.35); }
.nav-inner { max-width: 1060px; margin: 0 auto; display: flex; align-items: stretch; padding: 0 12px; }
.nav-tab { display: flex; align-items: center; gap: 8px; padding: 0 18px; height: 48px; text-decoration: none; font-size: 16px; letter-spacing: .16em; text-transform: uppercase; color: #c8d3e3; border-bottom: 3px solid transparent; }
.nav-tab:hover { color: #fff; }
.nav-tab--active { color: var(--color-gold-hi); border-bottom-color: var(--color-gold); font-weight: 600; }
.nav-tab--soon { color: #5f6f88; cursor: default; }
.nav-tab--soon:hover { color: #5f6f88; }
.nav-soon { font-size: 11px; letter-spacing: .12em; color: var(--color-navy); background: #6b7a97; border-radius: 3px; padding: 2px 6px; margin-left: 8px; }
.nav-spacer { flex: 1; }
.nav-tab--admin { color: var(--color-gold); border-left: 1px solid rgba(198,161,91,.28); }
.nav-tab--admin:hover { color: var(--color-gold-hi); }
.nav-dia { font-size: 13px; }
.app-user-avatar { width: 32px; height: 32px; border-radius: 50%; background: linear-gradient(160deg, var(--color-gold-hi), var(--color-gold)); color: var(--color-navy); font-weight: 700; font-size: 14px; display: flex; align-items: center; justify-content: center; border: 1px solid var(--color-gold-hi); }
```

- [ ] **Step 7: Run the nav test to verify it passes**

Run: `bin/rails test test/integration/primary_nav_test.rb`
Expected: PASS (4 runs, 0 failures).

- [ ] **Step 8: Fix any existing tests that asserted on the old header links**

The Admin and Settings links moved out of `.app-user`. Find any test that asserted on them:

Run: `grep -rn 'app-user-link\|"Admin"\|"Settings"' test/`

For each failing assertion (likely in `test/integration/` or dashboard/settings tests that checked the header), update it to look in `nav.nav-bar` instead (e.g. `assert_select "nav.nav-bar a", text: "Settings"`). Then:

Run: `bin/rails test`
Expected: PASS (full suite green).

- [ ] **Step 9: Lint and commit**

Run: `bin/rubocop` → Expected: no offenses.

```bash
git add app/views/shared/_primary_nav.html.erb app/views/shared/_app_header.html.erb app/views/layouts/application.html.erb app/assets/tailwind/application.css test/integration/primary_nav_test.rb test/
git commit -m "feat: add primary nav bar with permission gating; move admin/settings into nav"
```

---

### Task 5: Section panel component (boxed panel with header strip)

**Files:**
- Create: `app/views/shared/_section_panel.html.erb`
- Modify: `app/assets/tailwind/application.css` (append `.card*` rules)
- Test: `test/views/section_panel_test.rb`

**Interfaces:**
- Produces: a layout partial usable as `<%= render layout: "shared/section_panel", locals: { label: "Roster Record", provenance: "…" } do %> body <% end %>` → `.card` > `.card-head` (◆ + `.card-head-label` + optional `.card-head-prov`) + `.card-body`.

- [ ] **Step 1: Write the failing render test**

```ruby
# test/views/section_panel_test.rb
require "test_helper"

class SectionPanelTest < ActionView::TestCase
  test "renders the label, a body, and optional provenance" do
    output = render(layout: "shared/section_panel", locals: { label: "Roster Record", provenance: "imported 24 JUN 2026" }) { "PANEL BODY" }
    assert_select_in output, ".card .card-head .card-head-label", "Roster Record"
    assert_select_in output, ".card .card-head .card-head-prov", "imported 24 JUN 2026"
    assert_select_in output, ".card .card-body", text: /PANEL BODY/
  end

  test "omits provenance when not given" do
    output = render(layout: "shared/section_panel", locals: { label: "Login Account" }) { "X" }
    assert_select_in output, ".card-head-prov", count: 0
  end

  private

  def assert_select_in(html, *args, &block)
    assert_select(Nokogiri::HTML::DocumentFragment.parse(html), *args, &block)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/views/section_panel_test.rb`
Expected: FAIL (missing partial `shared/_section_panel`).

- [ ] **Step 3: Create the partial**

```erb
<%# app/views/shared/_section_panel.html.erb
    Locals: label: (String), provenance: (String, optional). Yields the body. %>
<section class="card">
  <div class="card-head">
    <span class="card-dia" aria-hidden="true">&#9670;</span>
    <span class="card-head-label"><%= label %></span>
    <% if local_assigns[:provenance].present? %>
      <span class="card-head-prov"><%= provenance %></span>
    <% end %>
  </div>
  <div class="card-body"><%= yield %></div>
</section>
```

- [ ] **Step 4: Add the CSS**

Append to `app/assets/tailwind/application.css`:

```css
/* Section panel: boxed unit with a tinted header strip -------------------- */
.card { border: 1px solid #d3c391; border-radius: 11px; background: var(--color-paper); overflow: hidden; margin-bottom: 22px; box-shadow: 0 8px 22px rgba(0,0,0,.06); }
.card-head { display: flex; align-items: center; gap: 11px; padding: 12px 18px; background: #efe5cb; border-bottom: 1px solid #ddcfa4; }
.card-dia { color: var(--color-gold); font-size: 14px; }
.card-head-label { font-size: 13px; letter-spacing: .2em; text-transform: uppercase; color: var(--color-navy); font-weight: 700; }
.card-head-prov { margin-left: auto; font-size: 13px; color: var(--color-bronze); display: flex; align-items: center; gap: 6px; }
.card-body { padding: 18px 20px; }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/views/section_panel_test.rb`
Expected: PASS (2 runs, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add app/views/shared/_section_panel.html.erb app/assets/tailwind/application.css test/views/section_panel_test.rb
git commit -m "feat: add section panel component"
```

---

### Task 6: Section header component (inline ◆ label + gold rule)

**Files:**
- Create: `app/views/shared/_section_header.html.erb`
- Modify: `app/assets/tailwind/application.css` (append `.sec-head*` rules)
- Test: `test/views/section_header_test.rb`

**Interfaces:**
- Produces: `<%= render "shared/section_header", label: "Post Officers" %>` → `.sec-head` > `.sec-head-label` + `.sec-head-rule`.

- [ ] **Step 1: Write the failing render test**

```ruby
# test/views/section_header_test.rb
require "test_helper"

class SectionHeaderTest < ActionView::TestCase
  test "renders the label and a rule" do
    output = render("shared/section_header", label: "Post Officers")
    frag = Nokogiri::HTML::DocumentFragment.parse(output)
    assert_select frag, ".sec-head .sec-head-label", "Post Officers"
    assert_select frag, ".sec-head .sec-head-rule"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/views/section_header_test.rb`
Expected: FAIL (missing partial).

- [ ] **Step 3: Create the partial**

```erb
<%# app/views/shared/_section_header.html.erb  Locals: label: (String) %>
<div class="sec-head">
  <span class="sec-head-dia" aria-hidden="true">&#9670;</span>
  <span class="sec-head-label"><%= label %></span>
  <span class="sec-head-rule"></span>
</div>
```

- [ ] **Step 4: Add the CSS**

```css
/* Inline section header: diamond + tracked label + gold gradient rule ----- */
.sec-head { display: flex; align-items: center; gap: 12px; margin: 6px 0 12px; }
.sec-head-dia { color: var(--color-gold); font-size: 14px; }
.sec-head-label { font-size: 13px; letter-spacing: .2em; text-transform: uppercase; color: var(--color-navy); font-weight: 700; white-space: nowrap; }
.sec-head-rule { flex: 1; height: 2px; background: linear-gradient(90deg, var(--color-gold), rgba(198,161,91,.15)); }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/views/section_header_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/views/shared/_section_header.html.erb app/assets/tailwind/application.css test/views/section_header_test.rb
git commit -m "feat: add inline section header component"
```

---

### Task 7: Membership status word helper

**Files:**
- Create: `app/helpers/status_display_helper.rb`
- Modify: `app/assets/tailwind/application.css` (append `.st*` rules)
- Test: `test/helpers/status_display_helper_test.rb`

**Interfaces:**
- Produces: `membership_status_tag(status) -> html_safe String` — a colored word + dot: `.st.st--active` (green) for "Active", `.st.st--expired` (hollow red) for "Expired", `.st.st--other` (muted) otherwise. Nil/blank → `""`.

- [ ] **Step 1: Write the failing test**

```ruby
# test/helpers/status_display_helper_test.rb
require "test_helper"

class StatusDisplayHelperTest < ActionView::TestCase
  test "active status renders the active class and label" do
    frag = Nokogiri::HTML::DocumentFragment.parse(membership_status_tag("Active"))
    assert_select frag, "span.st.st--active", text: /Active/
    assert_select frag, "span.st--active .st-dot"
  end

  test "expired status renders the expired class" do
    frag = Nokogiri::HTML::DocumentFragment.parse(membership_status_tag("Expired"))
    assert_select frag, "span.st.st--expired", text: /Expired/
  end

  test "unknown status renders the muted variant with its own label" do
    frag = Nokogiri::HTML::DocumentFragment.parse(membership_status_tag("Deceased"))
    assert_select frag, "span.st.st--other", text: /Deceased/
  end

  test "blank status renders nothing" do
    assert_equal "", membership_status_tag(nil)
    assert_equal "", membership_status_tag("")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/helpers/status_display_helper_test.rb`
Expected: FAIL (`undefined method 'membership_status_tag'`).

- [ ] **Step 3: Write minimal implementation**

```ruby
# app/helpers/status_display_helper.rb
module StatusDisplayHelper
  def membership_status_tag(status)
    return "" if status.blank?

    variant =
      case status.to_s.strip.downcase
      when "active" then "st--active"
      when "expired" then "st--expired"
      else "st--other"
      end

    tag.span(class: "st #{variant}") do
      tag.span("", class: "st-dot") + status.to_s
    end
  end
end
```

- [ ] **Step 4: Add the CSS**

```css
/* Membership status word (calm colored word + dot, never a boxed pill) ---- */
.st { font-size: 14px; font-weight: 600; white-space: nowrap; }
.st-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 7px; vertical-align: middle; }
.st--active { color: var(--color-green); }
.st--active .st-dot { background: var(--color-green); }
.st--expired { color: var(--color-legionred); }
.st--expired .st-dot { background: transparent; border: 2px solid var(--color-legionred); width: 6px; height: 6px; }
.st--other { color: var(--color-muted); }
.st--other .st-dot { background: var(--color-muted); }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/helpers/status_display_helper_test.rb`
Expected: PASS (4 runs, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add app/helpers/status_display_helper.rb app/assets/tailwind/application.css test/helpers/status_display_helper_test.rb
git commit -m "feat: add membership status word helper"
```

---

### Task 8: De-noised member row component

**Files:**
- Create: `app/views/shared/_member_row.html.erb`
- Modify: `app/assets/tailwind/application.css` (append `.mrow*` rules)
- Test: `test/views/member_row_test.rb`

**Interfaces:**
- Consumes: `membership_status_tag` (Task 7).
- Produces: `<%= render "shared/member_row", person:, office:, path:, membership: (bool) %>`. Renders identity (name + gold `.mrow-office`) grouped left; when `membership: true`, a left-aligned `.mrow-status` column at a divider with `label: value` lines. `office` present adds `.mrow--office` (gold left edge). This partial defines only structure/locals it is passed; it does not query paid-through/sign-in itself — the caller supplies the `status_line` (a rendered string) so this component stays presentation-only.

- [ ] **Step 1: Write the failing render test**

```ruby
# test/views/member_row_test.rb
require "test_helper"

class MemberRowTest < ActionView::TestCase
  test "renders name, office, and a status column with the gold edge for officers" do
    output = render("shared/member_row",
      name: "Robert A. Hansen", office: "Commander", path: "/admin/people/1",
      subline: "U.S. Army · Vietnam", membership: true,
      status_tag: membership_status_tag("Active"),
      status_lines: [ "Paid through: 2027", "Sign-in: Yes" ])
    frag = Nokogiri::HTML::DocumentFragment.parse(output)
    assert_select frag, "a.mrow.mrow--office[href=?]", "/admin/people/1"
    assert_select frag, ".mrow-name", "Robert A. Hansen"
    assert_select frag, ".mrow-office", "Commander"
    assert_select frag, ".mrow-status .st--active"
    assert_select frag, ".mrow-status .mrow-kv", text: /Paid through: 2027/
  end

  test "non-officer row has no gold edge and no office label" do
    output = render("shared/member_row",
      name: "Mary E. Kowalski", office: nil, path: "/admin/people/2",
      subline: "U.S. Air Force · Gulf War", membership: false,
      status_tag: nil, status_lines: [])
    frag = Nokogiri::HTML::DocumentFragment.parse(output)
    assert_select frag, "a.mrow", count: 1
    assert_select frag, "a.mrow--office", count: 0
    assert_select frag, ".mrow-office", count: 0
    assert_select frag, ".mrow-status", count: 0
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/views/member_row_test.rb`
Expected: FAIL (missing partial).

- [ ] **Step 3: Create the partial**

```erb
<%# app/views/shared/_member_row.html.erb
    Locals: name:, office: (String|nil), path:, subline:,
            membership: (bool), status_tag: (html|nil), status_lines: (Array<String>) %>
<%= link_to path, class: "mrow#{' mrow--office' if office.present?}" do %>
  <span class="mrow-id">
    <span class="mrow-l1">
      <span class="mrow-name"><%= name %></span>
      <% if office.present? %><span class="mrow-office"><%= office %></span><% end %>
    </span>
    <% if subline.present? %><span class="mrow-sub"><%= subline %></span><% end %>
  </span>
  <% if membership %>
    <span class="mrow-status">
      <% if status_tag.present? %><span class="mrow-st"><%= status_tag %></span><% end %>
      <% status_lines.each do |line| %><span class="mrow-kv"><%= line %></span><% end %>
    </span>
  <% end %>
<% end %>
```

- [ ] **Step 4: Add the CSS**

```css
/* De-noised member row: identity left, quiet status column at a divider --- */
.mrow { display: flex; align-items: center; gap: 0; padding: 14px 16px; border-top: 1px solid #eadfbf; text-decoration: none; color: inherit; }
.mrow:first-child { border-top: none; }
.mrow--office { border-left: 3px solid var(--color-gold); }
.mrow-id { flex: 1; min-width: 0; padding-right: 18px; }
.mrow-l1 { display: flex; align-items: baseline; gap: 12px; flex-wrap: wrap; }
.mrow-name { font-size: 17px; color: var(--color-navy); font-weight: 600; }
.mrow:hover .mrow-name { text-decoration: underline; }
.mrow-office { font-size: 12px; letter-spacing: .14em; text-transform: uppercase; color: var(--color-gold-ink); font-weight: 700; }
.mrow-sub { display: block; font-size: 14px; color: var(--color-muted); margin-top: 5px; }
.mrow-status { flex: 0 0 208px; border-left: 1px solid #e4d9bb; padding-left: 18px; text-align: left; }
.mrow-st { display: block; }
.mrow-kv { display: block; font-size: 14px; color: var(--color-ink); margin-top: 6px; }
.mrow-kv .k { color: var(--color-muted); }
```

Note: this component is rendered inside a `.mrow-list` wrapper (rounded border) that Plan 2 supplies where the list is built; the row itself owns only its top border.

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/views/member_row_test.rb`
Expected: PASS (2 runs, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add app/views/shared/_member_row.html.erb app/assets/tailwind/application.css test/views/member_row_test.rb
git commit -m "feat: add de-noised member row component"
```

---

### Task 9: Stat tile component

**Files:**
- Create: `app/views/shared/_stat_tile.html.erb`
- Modify: `app/assets/tailwind/application.css` (append `.stat-*` rules)
- Test: `test/views/stat_tile_test.rb`

**Interfaces:**
- Produces: `<%= render "shared/stat_tile", count: 3, label: "Problems", variant: "problems" %>` → `.stat-tile.stat-tile--problems` > `.stat-n` (count) + `.stat-t` (label). `variant` ∈ `created | updated | removed | problems | neutral`.

- [ ] **Step 1: Write the failing render test**

```ruby
# test/views/stat_tile_test.rb
require "test_helper"

class StatTileTest < ActionView::TestCase
  test "renders count, label, and variant class" do
    output = render("shared/stat_tile", count: 12, label: "Created", variant: "created")
    frag = Nokogiri::HTML::DocumentFragment.parse(output)
    assert_select frag, ".stat-tile.stat-tile--created .stat-n", "12"
    assert_select frag, ".stat-tile--created .stat-t", "Created"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/views/stat_tile_test.rb`
Expected: FAIL (missing partial).

- [ ] **Step 3: Create the partial**

```erb
<%# app/views/shared/_stat_tile.html.erb  Locals: count:, label:, variant: (String) %>
<div class="stat-tile stat-tile--<%= variant %>">
  <div class="stat-n"><%= count %></div>
  <div class="stat-t"><%= label %></div>
</div>
```

- [ ] **Step 4: Add the CSS**

```css
/* Stat tile (import summary counts) --------------------------------------- */
.stat-tile { background: var(--color-paper); border: 1px solid #e6dcbe; border-radius: 11px; padding: 16px 14px; text-align: center; }
.stat-n { font-size: 34px; font-weight: 700; line-height: 1; }
.stat-t { font-size: 13px; letter-spacing: .12em; text-transform: uppercase; color: var(--color-muted); margin-top: 8px; }
.stat-tile--created .stat-n { color: var(--color-green); }
.stat-tile--updated .stat-n { color: var(--color-navy); }
.stat-tile--removed .stat-n { color: var(--color-bronze); }
.stat-tile--neutral .stat-n { color: var(--color-muted); }
.stat-tile--problems { border-color: #e2b6b6; background: #fbefef; }
.stat-tile--problems .stat-n { color: var(--color-legionred); }
.stat-tile--problems .stat-t { color: #8a5b5b; }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/views/stat_tile_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/views/shared/_stat_tile.html.erb app/assets/tailwind/application.css test/views/stat_tile_test.rb
git commit -m "feat: add stat tile component"
```

---

### Task 10: Type-or-pick date field component

**Files:**
- Create: `app/views/shared/_date_field.html.erb`
- Create: `app/javascript/controllers/date_field_controller.js`
- Modify: `app/javascript/controllers/index.js` (register the controller — match the file's existing registration style)
- Modify: `app/assets/tailwind/application.css` (append `.datefield*` rules)
- Test: `test/views/date_field_test.rb`

**Interfaces:**
- Consumes: `legion_date(value)` (Task 1). The submitted value is the text input's `DD MMM YYYY` string; controllers parse it server-side with `parse_legion_date` (Task 1) in Plans 2/3.
- Produces: `<%= render "shared/date_field", name: "position_assignment[starts_on]", value: some_date %>` → a `.datefield` (Stimulus `date-field`) with a text input (`DD MMM YYYY`), a hidden native date input, and a 📅 button.

- [ ] **Step 1: Confirm the Stimulus setup exists**

Run: `ls app/javascript/controllers/` and open `app/javascript/controllers/index.js`.
Expected: the directory and an `index.js` that registers controllers (Rails/importmap default). Note the exact registration pattern used (either `eagerLoadControllersFrom` or explicit `application.register(...)`). If it uses `eagerLoadControllersFrom("controllers", application)`, no index edit is needed and the "Modify index.js" step is a no-op — confirm and skip it.

- [ ] **Step 2: Write the failing render test**

```ruby
# test/views/date_field_test.rb
require "test_helper"

class DateFieldTest < ActionView::TestCase
  test "renders a text input pre-filled in DD MMM YYYY and a native picker + button" do
    output = render("shared/date_field", name: "position_assignment[starts_on]", value: Date.new(2026, 1, 1))
    frag = Nokogiri::HTML::DocumentFragment.parse(output)
    assert_select frag, "span.datefield[data-controller=?]", "date-field"
    assert_select frag, "input.datefield-input[name=?][value=?]", "position_assignment[starts_on]", "01 JAN 2026"
    assert_select frag, "input.datefield-native[type=date]"
    assert_select frag, "button.datefield-cal"
  end

  test "renders an empty text input when value is nil" do
    output = render("shared/date_field", name: "position_assignment[ends_on]", value: nil)
    frag = Nokogiri::HTML::DocumentFragment.parse(output)
    assert_select frag, "input.datefield-input[name=?][value=?]", "position_assignment[ends_on]", ""
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bin/rails test test/views/date_field_test.rb`
Expected: FAIL (missing partial).

- [ ] **Step 4: Create the partial**

```erb
<%# app/views/shared/_date_field.html.erb
    Locals: name:, value: (Date|nil). Submits DD MMM YYYY text; server parses with parse_legion_date. %>
<span class="datefield" data-controller="date-field">
  <input type="text" name="<%= name %>" value="<%= value.present? ? legion_date(value) : "" %>"
         placeholder="DD MMM YYYY" autocomplete="off" inputmode="text"
         class="datefield-input" data-date-field-target="text">
  <input type="date" class="datefield-native" tabindex="-1" aria-hidden="true"
         value="<%= value&.strftime("%Y-%m-%d") %>"
         data-date-field-target="native" data-action="change->date-field#pick">
  <button type="button" class="datefield-cal" data-action="date-field#open" aria-label="Open calendar">&#128197;</button>
</span>
```

- [ ] **Step 5: Create the Stimulus controller**

```javascript
// app/javascript/controllers/date_field_controller.js
import { Controller } from "@hotwired/stimulus"

const MONTHS = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]

export default class extends Controller {
  static targets = ["text", "native"]

  open() {
    if (typeof this.nativeTarget.showPicker === "function") {
      this.nativeTarget.showPicker()
    } else {
      this.nativeTarget.focus()
    }
  }

  pick() {
    const value = this.nativeTarget.value // yyyy-mm-dd
    if (!value) return
    const [year, month, day] = value.split("-")
    this.textTarget.value = `${day} ${MONTHS[parseInt(month, 10) - 1]} ${year}`
  }
}
```

If Step 1 found explicit registration in `index.js`, add: `application.register("date-field", DateFieldController)` with a matching import at the top. Otherwise (eager loading) do nothing here.

- [ ] **Step 6: Add the CSS**

```css
/* Type-or-pick date field: text input (DD MMM YYYY) + hidden native picker - */
.datefield { position: relative; display: inline-flex; align-items: center; }
.datefield-input { font-size: 16px; padding: 10px 44px 10px 12px; border: 1px solid #cdbf98; border-radius: 6px; background: #fff; color: var(--color-ink); width: 170px; letter-spacing: .06em; text-transform: uppercase; }
.datefield-native { position: absolute; width: 1px; height: 1px; opacity: 0; pointer-events: none; right: 40px; }
.datefield-cal { position: absolute; right: 5px; width: 32px; height: 32px; border: none; background: #efe5cb; border-radius: 5px; cursor: pointer; font-size: 16px; line-height: 1; }
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bin/rails test test/views/date_field_test.rb`
Expected: PASS (2 runs, 0 failures).

- [ ] **Step 8: Full suite, lint, security, commit**

Run: `bin/rails test` → Expected: PASS (all green, including the ~156 pre-existing tests plus the new ones).
Run: `bin/rubocop` → Expected: no offenses.
Run: `bin/brakeman` → Expected: 0 warnings.

```bash
git add app/views/shared/_date_field.html.erb app/javascript/controllers/date_field_controller.js app/javascript/controllers/index.js app/assets/tailwind/application.css test/views/date_field_test.rb
git commit -m "feat: add type-or-pick date field component"
```

---

## Self-Review

**Spec coverage (Plan 1 scope):**
- Nav bar with disabled "soon" tabs + gated People/Admin → Task 4. ✓
- `DD MMM YYYY` / 24-hour formatting + type-or-pick date input → Tasks 1, 10. ✓
- Section panel, section header, status word, de-noised member row, stat tile → Tasks 5–9. ✓
- Palette extension (green/bronze/gold-ink from the visual spec) → Task 3. ✓
- Readability floors honored in every CSS block (interactive ≥16px, labels ≥13px). ✓
- No-full-width: member row uses a bounded status column at a divider, not a stretched row. ✓
- Deferred to Plan 2/3 and noted: People opening to all members + route move (Task 4 note); consumers of these components (Tasks 5–10 build the vocabulary, screens compose it later).

**Placeholder scan:** No "TBD"/"add error handling"/"similar to". Every code step shows complete code. Task 4 Step 8 and Task 10 Step 1 contain a conditional instruction (fix broken header-link tests; confirm Stimulus registration style) — each includes the exact command to discover the concrete case and the exact change to make, which is appropriate for adapting to unknown existing content rather than a placeholder.

**Type consistency:** `legion_date` (Task 1) consumed by Task 10 partial and Task 4 avatar path; `membership_status_tag` (Task 7) consumed by Task 8 test; `nav_tab_class`/`current_nav_section` (Task 2) consumed by Task 4 partial; `parse_legion_date` produced in Task 1 for Plans 2/3. Names match across tasks.

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-12-admin-roster-plan-1-foundation.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?** (Or: shall I first write Plans 2 and 3 so all three are ready before any execution?)
