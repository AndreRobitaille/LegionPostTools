# Login Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the "1919" Art Deco login screen (monumental emblem hero + warm sign-in card) in the real Rails app, plus the minimal design tokens and Tailwind plumbing it needs.

**Architecture:** A dedicated full-bleed `entry` layout renders unauthenticated screens (sign-in and magic-link confirmation) without the app container. Design tokens and the entry component styles live in the Tailwind input file so they compile into the served `tailwind.css`. The official American Legion emblem is added as an asset. Behavior for the magic-link form already exists; the passkey button is a designed placeholder to be wired later.

**Tech Stack:** Rails 8.1, Propshaft, tailwindcss-rails 4.6 (Tailwind v4, CSS `@theme` tokens), Hotwire/Turbo, importmap, ERB.

## Global Constraints

Copied from `docs/superpowers/specs/2026-07-11-visual-design-system-design.md`. Every task inherits these.

- Palette (exact): navy `#0A2240`, navy-2 `#0d2c54`, navy-deep `#081a34`, gold `#C6A15B`, gold-highlight `#E6CD8B`, cream `#F4EEDD`, paper `#FBF7EC`, ivory `#FCFAF1`, red `#8C1622`, ink `#1b222b`, muted `#6b7684`.
- Sans-serif for app chrome; serif (`Georgia, "Times New Roman"`) reserved for official documents. (Login is chrome → sans.)
- Red is the only loud color; use it sparingly and only for attention/return actions.
- No full-width / 100% content layouts; content lives in bounded columns.
- The monumental hero is used ONLY for entry screens (login / magic-link confirm), never as persistent app chrome.
- Warm cream backgrounds, never a full screen of pure white.
- Do NOT hard-code Post 165: the post name, unit type, and location come from the `Organization` record and must degrade gracefully when absent. Keep the app configurable for other installations.
- Keep Rails conventional.
- Dev servers must bind to `0.0.0.0` (developer works off-box).

---

### Task 1: Design tokens, emblem asset, and Tailwind linking

Adds the palette/type tokens and entry component CSS to the Tailwind input, downloads the official emblem into assets, and fixes the broken stylesheet link so compiled CSS actually loads.

**Files:**
- Modify: `app/assets/tailwind/application.css`
- Create: `app/assets/images/al-emblem.png` (downloaded)
- Modify: `app/views/layouts/application.html.erb:19`
- Test: `test/assets_test.rb`

**Interfaces:**
- Produces: CSS custom properties `--color-navy`, `--color-navy-2`, `--color-navy-deep`, `--color-gold`, `--color-gold-hi`, `--color-cream`, `--color-paper`, `--color-ivory`, `--color-legionred`, `--color-ink`, `--color-muted`, `--font-serif`; and the component classes `.entry`, `.entry-hero`, `.entry-rays`, `.entry-fade`, `.entry-col`, `.entry-emb`, `.entry-kick`, `.entry-title`, `.entry-diamonds`, `.entry-loc`, `.entry-card`, `.entry-card-title`, `.entry-lead`, `.entry-field`, `.entry-btn`, `.entry-reassure`, `.entry-orline`, `.entry-passkey`, `.entry-flash`, `.entry-flash-notice`, `.entry-flash-alert`. Asset `al-emblem.png`.

- [ ] **Step 1: Write the failing test**

Create `test/assets_test.rb`:

```ruby
require "test_helper"

class AssetsTest < ActiveSupport::TestCase
  test "the American Legion emblem asset is available" do
    path = ActionController::Base.helpers.image_path("al-emblem.png")
    assert path.present?, "al-emblem.png should resolve to an asset path"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/assets_test.rb`
Expected: FAIL with `Propshaft::MissingAssetError: The asset 'al-emblem.png' was not found`.

- [ ] **Step 3: Download the official emblem into assets**

Run:

```bash
curl -sL -o /tmp/al-emblem.zip "https://www.legion.org/getmedia/4566cea9-a7bd-4914-960e-71dec35038b7/American-Legion-Emblem.zip"
unzip -o -j /tmp/al-emblem.zip "American Legion Emblem/For Digital Use (PNG)/TAL-emblem-full-detail-RGB.png" -d app/assets/images/
mv "app/assets/images/TAL-emblem-full-detail-RGB.png" app/assets/images/al-emblem.png
```

Expected: `app/assets/images/al-emblem.png` exists (~659 KB, 1000×1000 RGBA).

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/assets_test.rb`
Expected: PASS.

- [ ] **Step 5: Add tokens and entry component CSS**

Replace the entire contents of `app/assets/tailwind/application.css` with:

```css
@import "tailwindcss";

@theme {
  --color-navy: #0A2240;
  --color-navy-2: #0d2c54;
  --color-navy-deep: #081a34;
  --color-gold: #C6A15B;
  --color-gold-hi: #E6CD8B;
  --color-cream: #F4EEDD;
  --color-paper: #FBF7EC;
  --color-ivory: #FCFAF1;
  --color-legionred: #8C1622;
  --color-ink: #1b222b;
  --color-muted: #6b7684;
  --font-serif: Georgia, "Times New Roman", serif;
}

/* ---------------------------------------------------------------------------
   Entry screens (sign-in / magic-link confirm): the reserved monumental hero.
   Deco: sunburst rays, stepped gold, tracked capitals, warm cream sign-in card.
   --------------------------------------------------------------------------- */
.entry {
  min-height: 100vh;
  background: var(--color-navy-deep);
  font-family: system-ui, "Segoe UI", Helvetica, Arial, sans-serif;
}
.entry-hero {
  position: relative;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  padding: 40px 20px;
  background: radial-gradient(120% 100% at 50% 0%, #123059, var(--color-navy-deep));
}
.entry-rays {
  position: absolute;
  inset: -60% -20% auto -20%;
  height: 190%;
  background: repeating-conic-gradient(from 0deg at 50% 0%, rgba(198,161,91,.14) 0deg 2.5deg, transparent 2.5deg 10deg);
  pointer-events: none;
}
.entry-fade {
  position: absolute;
  inset: 0;
  background: radial-gradient(120% 80% at 50% 0%, transparent 34%, var(--color-navy-deep) 78%);
  pointer-events: none;
}
.entry-col { position: relative; width: 100%; max-width: 430px; text-align: center; }
.entry-emb { width: 132px; height: 132px; margin: 0 auto 10px; display: block; filter: drop-shadow(0 8px 16px rgba(0,0,0,.55)); }
.entry-kick { color: var(--color-gold-hi); font-size: 11px; letter-spacing: .42em; text-transform: uppercase; }
.entry-title { margin: 8px 0 0; color: #fff; font-weight: 800; letter-spacing: .12em; text-transform: uppercase; font-size: 22px; line-height: 1.25; }
.entry-diamonds { color: var(--color-gold); letter-spacing: .5em; font-size: 9px; margin: 10px 0 6px; }
.entry-loc { color: #9fb0c6; font-size: 11px; letter-spacing: .22em; text-transform: uppercase; }
.entry-card { background: var(--color-cream); border-top: 3px solid var(--color-gold); border-radius: 6px; margin-top: 24px; padding: 22px; text-align: left; box-shadow: 0 16px 40px rgba(0,0,0,.4); }
.entry-card-title { margin: 0 0 3px; color: var(--color-navy); font-size: 17px; }
.entry-lead { color: #5b6b7e; font-size: 12.5px; margin: 0 0 16px; line-height: 1.5; }
.entry-field { margin-bottom: 4px; }
.entry-field label { display: block; font-size: 11px; letter-spacing: .1em; text-transform: uppercase; font-weight: 700; color: #6a5320; margin-bottom: 6px; }
.entry-field input { width: 100%; font-size: 16px; padding: 13px 14px; border: 1.5px solid #cbb98c; border-radius: 6px; background: #fff; color: var(--color-ink); }
.entry-btn { width: 100%; margin-top: 14px; background: var(--color-navy); color: #fff; border: 0; padding: 14px; border-radius: 6px; font-size: 15px; font-weight: 700; cursor: pointer; }
.entry-reassure { font-size: 12px; color: #6b7684; margin: 12px 2px 0; line-height: 1.5; text-align: center; }
.entry-orline { display: flex; align-items: center; gap: 12px; color: #9a8a63; font-size: 10px; letter-spacing: .2em; text-transform: uppercase; margin: 18px 0; }
.entry-orline::before, .entry-orline::after { content: ""; flex: 1; height: 1px; background: #d8caa2; }
.entry-passkey { width: 100%; background: #fff; border: 1.5px solid var(--color-navy); color: var(--color-navy); padding: 12px; border-radius: 6px; font-size: 14px; font-weight: 700; cursor: pointer; }
.entry-flash { border-radius: 6px; padding: 10px 12px; font-size: 13px; margin-bottom: 14px; }
.entry-flash-notice { background: #eafaf0; border: 1px solid #b7e0c4; color: #2f6b43; }
.entry-flash-alert { background: #fbeaea; border: 1px solid #e3c3c3; color: var(--color-legionred); }
```

- [ ] **Step 6: Fix the broken stylesheet link in the application layout**

In `app/views/layouts/application.html.erb`, line 19, change:

```erb
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
```

to:

```erb
    <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
```

(`:app` resolves to a non-existent `app.css` and raises `Propshaft::MissingAssetError`; `"tailwind"` is the compiled Tailwind output.)

- [ ] **Step 7: Build the CSS and verify tokens + entry styles compile**

Run:

```bash
bin/rails tailwindcss:build
grep -c -- "--color-navy" app/assets/builds/tailwind.css
grep -c "\.entry-hero" app/assets/builds/tailwind.css
```

Expected: the build exits 0, and both `grep -c` commands print a number ≥ 1.

- [ ] **Step 8: Commit**

```bash
git add app/assets/tailwind/application.css app/assets/images/al-emblem.png app/views/layouts/application.html.erb test/assets_test.rb
git commit -m "feat: add design tokens, emblem asset, and fix Tailwind stylesheet link"
```

---

### Task 2: Entry layout and the sign-in hero

Creates the full-bleed entry layout and rebuilds the sign-in page as the Deco hero with a sign-in card.

**Files:**
- Create: `app/views/layouts/entry.html.erb`
- Modify: `app/controllers/sessions_controller.rb`
- Modify: `app/views/sessions/new.html.erb`
- Test: `test/integration/login_page_test.rb`

**Interfaces:**
- Consumes: `.entry*` classes and `al-emblem.png` from Task 1; existing route helpers `session_path` (POST create) and `new_session_path`.
- Produces: `entry` layout usable by any unauthenticated screen; `@organization` (an `Organization` or `nil`) assigned in `SessionsController#new` and `#magic_link`.

- [ ] **Step 1: Write the failing test**

Create `test/integration/login_page_test.rb`:

```ruby
require "test_helper"

class LoginPageTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      unit_number: "165",
      timezone: "America/Chicago",
      default_location_name: "Two Rivers, Wisconsin"
    )
  end

  test "sign-in page renders the entry hero with emblem and post identity" do
    get new_session_path
    assert_response :success
    assert_select ".entry-hero", count: 1
    assert_select "img.entry-emb[src*=?]", "al-emblem"
    assert_select "h1.entry-title", text: /Robert E\. Burns Post 165/
    assert_select ".entry-loc", text: /Two Rivers, Wisconsin/
  end

  test "sign-in page has the magic-link form and passkey placeholder" do
    get new_session_path
    assert_response :success
    assert_select "form[action=?][method=post]", session_path do
      assert_select "input[type=email][name=email_address]"
      assert_select "button", text: /Send my sign-in link/
    end
    assert_select "button.entry-passkey", text: /passkey/i
  end

  test "flash notice renders inside the sign-in card" do
    post session_path, params: { email_address: "nobody@example.com" }
    follow_redirect!
    assert_select ".entry-flash-notice", text: /Check your email/
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/login_page_test.rb`
Expected: FAIL (no `.entry-hero`, current `sessions/new` is plain HTML).

- [ ] **Step 3: Create the entry layout**

Create `app/views/layouts/entry.html.erb`:

```erb
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "LegionPostTools" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body>
    <%= yield %>
  </body>
</html>
```

- [ ] **Step 4: Wire the controller to the entry layout and load the organization**

In `app/controllers/sessions_controller.rb`, add the layout line just inside the class and set `@organization` in `new` and `magic_link`:

```ruby
class SessionsController < ApplicationController
  layout "entry", only: %i[new create magic_link]
  skip_before_action :redirect_to_setup_if_needed, only: %i[new create magic_link]

  def new
    @organization = Organization.first
  end
```

And at the top of the `magic_link` method body, add:

```ruby
  def magic_link
    @organization = Organization.first

    if request.get? || request.head?
      return render :magic_link
    end
```

(Leave the rest of `create`, `magic_link`, and `destroy` unchanged.)

- [ ] **Step 5: Rebuild the sign-in page**

Replace the entire contents of `app/views/sessions/new.html.erb` with:

```erb
<% content_for :title, "Sign in" %>

<div class="entry">
  <div class="entry-hero">
    <div class="entry-rays"></div>
    <div class="entry-fade"></div>

    <div class="entry-col">
      <%= image_tag "al-emblem.png", alt: "The American Legion emblem", class: "entry-emb" %>
      <% if @organization&.unit_type.present? %>
        <div class="entry-kick"><%= @organization.unit_type.titleize %></div>
      <% end %>
      <h1 class="entry-title"><%= @organization&.name || "LegionPostTools" %></h1>
      <div class="entry-diamonds">&#9670; &#9670; &#9670;</div>
      <% if @organization&.default_location_name.present? %>
        <div class="entry-loc"><%= @organization.default_location_name %></div>
      <% end %>

      <div class="entry-card">
        <% if flash[:notice] %>
          <div class="entry-flash entry-flash-notice"><%= flash[:notice] %></div>
        <% end %>
        <% if flash[:alert] %>
          <div class="entry-flash entry-flash-alert"><%= flash[:alert] %></div>
        <% end %>

        <h2 class="entry-card-title">Sign in</h2>
        <p class="entry-lead">Enter your email and we'll send you a secure sign-in link. There's no password to remember.</p>

        <%= form_with url: session_path, method: :post do |form| %>
          <div class="entry-field">
            <%= form.label :email_address, "Email address" %>
            <%= form.email_field :email_address, autocomplete: "email", placeholder: "you@example.com", required: true %>
          </div>
          <%= form.button "Send my sign-in link", class: "entry-btn" %>
        <% end %>

        <p class="entry-reassure">The link works once and expires shortly. Check your inbox after you tap the button.</p>

        <div class="entry-orline">Already set up a passkey?</div>
        <%# TODO: passkey sign-in JS is not wired yet. This is a designed placeholder; behavior to follow. %>
        <button type="button" class="entry-passkey" data-passkey-signin>&#128273; Sign in with a passkey</button>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bin/rails test test/integration/login_page_test.rb`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add app/views/layouts/entry.html.erb app/controllers/sessions_controller.rb app/views/sessions/new.html.erb test/integration/login_page_test.rb
git commit -m "feat: Deco sign-in hero on a dedicated entry layout"
```

---

### Task 3: Magic-link confirmation page

Restyles the "confirm sign in" page (the landing after clicking an emailed link) to match the entry hero.

**Files:**
- Modify: `app/views/sessions/magic_link.html.erb`
- Test: `test/integration/login_page_test.rb` (add one test)

**Interfaces:**
- Consumes: `.entry*` classes (Task 1), `entry` layout and `@organization` (Task 2), route helper `magic_link_session_path`.

- [ ] **Step 1: Write the failing test**

Append this test inside `class LoginPageTest` in `test/integration/login_page_test.rb`:

```ruby
  test "magic-link confirmation renders in the entry hero" do
    get magic_link_session_path(token: "sometoken")
    assert_response :success
    assert_select ".entry-hero", count: 1
    assert_select "form[action=?][method=post]", magic_link_session_path do
      assert_select "input[type=hidden][name=token]"
      assert_select "button", text: /Finish signing in/
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/login_page_test.rb`
Expected: FAIL (current `magic_link.html.erb` is plain HTML with no `.entry-hero`).

- [ ] **Step 3: Rebuild the confirmation page**

Replace the entire contents of `app/views/sessions/magic_link.html.erb` with:

```erb
<% content_for :title, "Confirm sign in" %>

<div class="entry">
  <div class="entry-hero">
    <div class="entry-rays"></div>
    <div class="entry-fade"></div>

    <div class="entry-col">
      <%= image_tag "al-emblem.png", alt: "The American Legion emblem", class: "entry-emb" %>
      <% if @organization&.unit_type.present? %>
        <div class="entry-kick"><%= @organization.unit_type.titleize %></div>
      <% end %>
      <h1 class="entry-title"><%= @organization&.name || "LegionPostTools" %></h1>
      <div class="entry-diamonds">&#9670; &#9670; &#9670;</div>

      <div class="entry-card">
        <h2 class="entry-card-title">Confirm sign in</h2>
        <p class="entry-lead">You're almost in. Tap the button below to finish signing in on this device.</p>

        <%= form_with url: magic_link_session_path, method: :post do |form| %>
          <%= hidden_field_tag :token, params[:token] %>
          <%= form.button "Finish signing in", class: "entry-btn" %>
        <% end %>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/integration/login_page_test.rb`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add app/views/sessions/magic_link.html.erb test/integration/login_page_test.rb
git commit -m "feat: style magic-link confirmation in the entry hero"
```

---

### Task 4: Full verification (suite, lint, real-app smoke)

Confirms the whole slice works together and looks right in the running app.

**Files:** none (verification only).

- [ ] **Step 1: Run the full test suite**

Run: `bin/rails test`
Expected: all tests pass (including the pre-existing suite; the Task 1 layout fix keeps other pages rendering).

- [ ] **Step 2: Run the linter**

Run: `bin/rubocop`
Expected: no offenses in the changed files. Fix any that appear, then re-run.

- [ ] **Step 3: Rebuild assets**

Run: `bin/rails tailwindcss:build`
Expected: exits 0.

- [ ] **Step 4: Smoke-test in the real app (bound to 0.0.0.0)**

Ensure an organization and a completed setup exist (create via the setup wizard if needed), then run:

```bash
bin/rails server -b 0.0.0.0
```

Visit `http://<host-ip>:3000/session/new` from a browser and confirm:
- The navy hero renders with sunburst rays and the full-color emblem.
- The post name shows in tracked gold-flanked capitals; the location line appears below the diamonds.
- The cream sign-in card shows the email field, the navy "Send my sign-in link" button, and the outlined passkey button.
- Submitting an email returns to the page with the green "Check your email" flash inside the card.

- [ ] **Step 5: Final commit (only if lint/verification required file changes)**

```bash
git add -A
git commit -m "chore: verification fixes for login screen"
```

---

## Self-Review

**Spec coverage (login-relevant sections):**
- North star / Deco hero → Task 2 (rays, stepped card, tracked capitals, emblem). ✓
- Palette + type tokens → Task 1 `@theme`. ✓
- Reserved-hero rule → hero only on entry layout (sessions), not application layout. ✓
- Login screen (emblem hero, big email field, big primary button, reassurance, secondary passkey) → Task 2. ✓
- Emblem asset guidance (official full-color emblem) → Task 1 download. ✓
- Configurable / no hard-coded Post 165 → org-driven identity with nil fallbacks. ✓
- Cream not white → sign-in card is `--color-cream`. ✓
- Deferred: passkey behavior (placeholder button only, JS not wired) — intentional, noted in Task 2 Step 5. Full foundation (shell/nav, component library, dashboard) is out of this slice per the agreed scope.

**Placeholder scan:** No "TBD/TODO-implement-later" steps; the one `TODO` comment in the ERB is an intentional, documented placeholder for future passkey wiring, not a plan gap. All code steps show complete code.

**Type/name consistency:** `.entry*` class names and `al-emblem.png` used in Tasks 2–3 match those defined in Task 1. `@organization` is defined in Task 2 (controller) and consumed by the Task 3 view. Route helpers (`session_path`, `new_session_path`, `magic_link_session_path`) match `config/routes.rb`. Button label "Finish signing in" is consistent between the Task 3 test and view.
