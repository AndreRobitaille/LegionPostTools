# Position Titles — Modern Reordering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let admins drag Post Position rows into order by a grip handle (auto-saving on drop), and make new positions append to the end instead of asking for an order number.

**Architecture:** Add a server endpoint that rewrites `display_order` for an org's positions from a posted ID sequence, backed by an atomic org-scoped `PositionTitle.reorder!`. On the client, a thin Stimulus controller wraps the row list with SortableJS (touch- and mouse-capable), POSTing the new order on drop. The add form drops its manual "Order" field; the controller assigns `max + 1` server-side.

**Tech Stack:** Rails 7 + importmap + Hotwired (Stimulus/Turbo), SortableJS (vendored via importmap), Tailwind CSS file (`app/assets/tailwind/application.css`), Minitest.

## Global Constraints

- Body/interactive text ≥ 16px, secondary ≥ 14px, labels ≥ 13px; nothing meaningful below 13px. Err larger.
- No full-width stranded rows: keep handle + name grouped left, state + toggle grouped right.
- Any dev server binds to `0.0.0.0` (e.g. `bin/rails server -b 0.0.0.0`), never `127.0.0.1`/`localhost`.
- Single-org app pattern: scope through `Organization.first` in controllers, matching existing `PositionTitlesController`.
- Keep Rails conventional; do not hard-code Post 165 assumptions; do not overbuild.
- `display_order` is 1-based and contiguous by convention (existing seeds use 1, 2, 3…).

---

### Task 1: `PositionTitle.reorder!` (org-scoped, atomic)

**Files:**
- Modify: `app/models/position_title.rb`
- Test: `test/models/position_title_test.rb` (create)

**Interfaces:**
- Produces: `PositionTitle.reorder!(organization, ordered_ids)` — rewrites `display_order` to `1..n` in the order of `ordered_ids`. Raises `ActiveRecord::RecordNotFound` if any id is not one of `organization`'s position titles, or if `ordered_ids` contains duplicates. Atomic: on failure no row's `display_order` changes.

- [ ] **Step 1: Write the failing tests**

Create `test/models/position_title_test.rb`:

```ruby
require "test_helper"

class PositionTitleTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @a = PositionTitle.create!(organization: @org, name: "Commander", display_order: 1)
    @b = PositionTitle.create!(organization: @org, name: "Adjutant", display_order: 2)
    @c = PositionTitle.create!(organization: @org, name: "Chaplain", display_order: 3)
  end

  test "reorder! rewrites display_order to the given 1-based sequence" do
    PositionTitle.reorder!(@org, [@c.id, @a.id, @b.id])

    assert_equal 1, @c.reload.display_order
    assert_equal 2, @a.reload.display_order
    assert_equal 3, @b.reload.display_order
  end

  test "reorder! rejects ids outside the organization and changes nothing" do
    other_org = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = PositionTitle.create!(organization: other_org, name: "Historian", display_order: 1)

    assert_raises(ActiveRecord::RecordNotFound) do
      PositionTitle.reorder!(@org, [@a.id, foreign.id, @b.id])
    end

    assert_equal 1, @a.reload.display_order
    assert_equal 2, @b.reload.display_order
    assert_equal 3, @c.reload.display_order
  end

  test "reorder! rejects duplicate ids" do
    assert_raises(ActiveRecord::RecordNotFound) do
      PositionTitle.reorder!(@org, [@a.id, @a.id, @b.id])
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/position_title_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'reorder!' for PositionTitle`.

- [ ] **Step 3: Implement `reorder!`**

In `app/models/position_title.rb`, add the class method inside the class:

```ruby
class PositionTitle < ApplicationRecord
  belongs_to :organization
  has_many :position_assignments, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :display_order, numericality: { only_integer: true }

  # Rewrites display_order to a contiguous 1-based sequence matching ordered_ids.
  # Raises ActiveRecord::RecordNotFound if any id is not one of the organization's
  # position titles, or if ordered_ids contains duplicates. Atomic.
  def self.reorder!(organization, ordered_ids)
    ids = Array(ordered_ids).map(&:to_i)
    titles = organization.position_titles.where(id: ids).index_by(&:id)
    raise ActiveRecord::RecordNotFound unless titles.length == ids.length

    transaction do
      ids.each_with_index do |id, index|
        titles.fetch(id).update!(display_order: index + 1)
      end
    end
  end
end
```

(`index_by(&:id)` collapses duplicates, so a duplicated id makes `titles.length < ids.length` and triggers the guard.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/models/position_title_test.rb`
Expected: PASS (3 runs, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add app/models/position_title.rb test/models/position_title_test.rb
git commit -m "feat: add org-scoped PositionTitle.reorder!"
```

---

### Task 2: New positions append to the end

**Files:**
- Modify: `app/controllers/admin/position_titles_controller.rb`
- Test: `test/controllers/admin/position_titles_controller_test.rb:42-50`

**Interfaces:**
- Consumes: existing `Organization has_many :position_titles`.
- Produces: `POST /admin/position_titles` ignores any submitted `display_order` and assigns `(max display_order for the org) + 1`.

- [ ] **Step 1: Update the create test to assert append-to-end and ignored order**

Replace the existing `"create adds a position title..."` test (lines 42-50) in `test/controllers/admin/position_titles_controller_test.rb` with:

```ruby
  test "create appends the position to the end and ignores any submitted order" do
    prepare_setup_complete_state
    sign_in_admin
    PositionTitle.create!(organization: @org, name: "Commander", display_order: 3, active: true)

    assert_difference -> { PositionTitle.count }, 1 do
      post admin_position_titles_path, params: { position_title: { name: "Chaplain", display_order: 1 } }
    end

    assert_redirected_to admin_position_titles_path
    created = PositionTitle.find_by!(name: "Chaplain")
    assert_equal @org.id, created.organization_id
    assert_equal 4, created.display_order
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/admin/position_titles_controller_test.rb -n "/create appends/"`
Expected: FAIL — `display_order` is 1 (submitted value honored), not 4.

- [ ] **Step 3: Assign display_order server-side and drop it from params**

In `app/controllers/admin/position_titles_controller.rb`, update `create` and `position_title_params`:

```ruby
    def create
      org = Organization.first
      title = org.position_titles.new(position_title_params)
      title.display_order = (org.position_titles.maximum(:display_order) || 0) + 1
      if title.save
        redirect_to admin_position_titles_path, notice: "Post position added."
      else
        redirect_to admin_position_titles_path, alert: title.errors.full_messages.to_sentence
      end
    end
```

```ruby
    def position_title_params
      params.require(:position_title).permit(:name, :active)
    end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/controllers/admin/position_titles_controller_test.rb -n "/create appends/"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/admin/position_titles_controller.rb test/controllers/admin/position_titles_controller_test.rb
git commit -m "feat: append new position titles to the end"
```

---

### Task 3: `reorder` route + controller action

**Files:**
- Modify: `config/routes.rb:39`
- Modify: `app/controllers/admin/position_titles_controller.rb`
- Test: `test/controllers/admin/position_titles_controller_test.rb`

**Interfaces:**
- Consumes: `PositionTitle.reorder!(organization, ordered_ids)` from Task 1.
- Produces: `POST /admin/position_titles/reorder` with body `{ ids: [<id>, ...] }`. Helper: `reorder_admin_position_titles_path`. Returns `head :ok` on success, `head :unprocessable_entity` when ids are invalid.

- [ ] **Step 1: Add the collection route**

In `config/routes.rb`, change line 39 from:

```ruby
    resources :position_titles, only: %i[index create update]
```

to:

```ruby
    resources :position_titles, only: %i[index create update] do
      post :reorder, on: :collection
    end
```

- [ ] **Step 2: Write the failing controller tests**

Add to `test/controllers/admin/position_titles_controller_test.rb`, before the final `end`:

```ruby
  test "reorder persists the new order" do
    prepare_setup_complete_state
    sign_in_admin
    a = PositionTitle.create!(organization: @org, name: "Commander", display_order: 1)
    b = PositionTitle.create!(organization: @org, name: "Adjutant", display_order: 2)
    c = PositionTitle.create!(organization: @org, name: "Chaplain", display_order: 3)

    post reorder_admin_position_titles_path, params: { ids: [c.id, a.id, b.id] }, as: :json

    assert_response :success
    assert_equal 1, c.reload.display_order
    assert_equal 2, a.reload.display_order
    assert_equal 3, b.reload.display_order
  end

  test "reorder rejects ids from another organization" do
    prepare_setup_complete_state
    sign_in_admin
    a = PositionTitle.create!(organization: @org, name: "Commander", display_order: 1)
    other_org = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = PositionTitle.create!(organization: other_org, name: "Historian", display_order: 1)

    post reorder_admin_position_titles_path, params: { ids: [a.id, foreign.id] }, as: :json

    assert_response :unprocessable_entity
    assert_equal 1, a.reload.display_order
  end
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `bin/rails test test/controllers/admin/position_titles_controller_test.rb -n "/reorder/"`
Expected: FAIL — `undefined method 'reorder_admin_position_titles_path'` (route/action missing).

- [ ] **Step 4: Implement the `reorder` action**

In `app/controllers/admin/position_titles_controller.rb`, add after `update`:

```ruby
    def reorder
      PositionTitle.reorder!(Organization.first, params.require(:ids))
      head :ok
    rescue ActiveRecord::RecordNotFound
      head :unprocessable_entity
    end
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bin/rails test test/controllers/admin/position_titles_controller_test.rb -n "/reorder/"`
Expected: PASS (2 runs, 0 failures).

- [ ] **Step 6: Run the whole controller + model file to confirm nothing regressed**

Run: `bin/rails test test/controllers/admin/position_titles_controller_test.rb test/models/position_title_test.rb`
Expected: PASS (all runs, 0 failures).

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/admin/position_titles_controller.rb test/controllers/admin/position_titles_controller_test.rb
git commit -m "feat: add position title reorder endpoint"
```

---

### Task 4: Vendor SortableJS via importmap

**Files:**
- Modify: `config/importmap.rb`
- Create: `vendor/javascript/sortablejs.js` (downloaded)

**Interfaces:**
- Produces: `import Sortable from "sortablejs"` resolves in Stimulus controllers.

- [ ] **Step 1: Pin and download SortableJS**

Run: `bin/importmap pin sortablejs --download`
Expected: prints `Pinning "sortablejs"...`, adds a `pin "sortablejs"` line to `config/importmap.rb`, and writes `vendor/javascript/sortablejs.js`.

- [ ] **Step 2: Verify the pin and vendored file**

Run: `grep sortablejs config/importmap.rb && ls -l vendor/javascript/sortablejs.js`
Expected: a `pin "sortablejs"` line is present and the vendored file exists (non-empty).

If the download fails (no network), fall back to manually saving the SortableJS UMD/ESM build (v1.15.x) to `vendor/javascript/sortablejs.js` and adding `pin "sortablejs", to: "sortablejs.js"` to `config/importmap.rb`.

- [ ] **Step 3: Commit**

```bash
git add config/importmap.rb vendor/javascript/sortablejs.js
git commit -m "chore: vendor sortablejs via importmap"
```

---

### Task 5: `reorder_controller.js` Stimulus controller

**Files:**
- Create: `app/javascript/controllers/reorder_controller.js`

**Interfaces:**
- Consumes: `import Sortable from "sortablejs"` (Task 4); `POST` to the URL in `data-reorder-url-value` (Task 3); rows carry `data-position-id`; drag handle has class `.pos-handle`; an optional status element with `data-reorder-target="status"`.
- Produces: Stimulus controller registered as `reorder` (auto-registered by `eagerLoadControllersFrom`).

- [ ] **Step 1: Write the controller**

Create `app/javascript/controllers/reorder_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Drag-to-reorder for the Post Positions list. Progressive enhancement: without
// JS the rows render in saved order (just not draggable). With JS, each row is
// draggable by its .pos-handle grip; dropping a row POSTs the new id order and
// persists immediately. On failure the pre-drag order is restored.
export default class extends Controller {
  static targets = ["status"]
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      handle: ".pos-handle",
      animation: 150,
      ghostClass: "pos-ghost",
      dragClass: "pos-drag",
      onStart: () => { this.snapshot = this.rows() },
      onEnd: () => this.save(),
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  rows() {
    return Array.from(this.element.querySelectorAll("[data-position-id]"))
  }

  async save() {
    const ids = this.rows().map((el) => el.dataset.positionId)
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
        },
        body: JSON.stringify({ ids }),
      })
      if (!response.ok) throw new Error(`Reorder failed: ${response.status}`)
      this.flash("Order saved")
    } catch (error) {
      this.restore()
      this.flash("Could not save order — please try again", true)
    }
  }

  // Re-append rows in their pre-drag sequence to undo the visual move.
  restore() {
    this.snapshot?.forEach((el) => this.element.appendChild(el))
  }

  flash(message, isError = false) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.classList.toggle("pos-status-error", isError)
    clearTimeout(this.flashTimer)
    this.flashTimer = setTimeout(() => { this.statusTarget.textContent = "" }, 2500)
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/javascript/controllers/reorder_controller.js
git commit -m "feat: add reorder Stimulus controller"
```

(No unit test — no JS/system-test harness exists in this repo. Behavior is verified end-to-end in Task 7.)

---

### Task 6: View grip handles + remove the Order field + CSS

**Files:**
- Modify: `app/views/admin/position_titles/index.html.erb`
- Modify: `app/assets/tailwind/application.css` (near the existing `.pos` block, ~line 356)

**Interfaces:**
- Consumes: `reorder` controller (Task 5) via `data-controller`/`data-reorder-url-value`/`data-reorder-target`; `reorder_admin_position_titles_path` (Task 3).

- [ ] **Step 1: Rewrite the list and add form in the view**

Replace lines 8-35 (the `section_panel` render block) in `app/views/admin/position_titles/index.html.erb` with:

```erb
<%= render "shared/section_panel", label: "Post Positions" do %>
  <% if @position_titles.present? %>
    <p class="page-sub" id="reorder-hint">Drag a row by its handle to change the order. Changes save automatically.</p>
    <div data-controller="reorder"
         data-reorder-url-value="<%= reorder_admin_position_titles_path %>">
      <% @position_titles.each do |title| %>
        <div class="pos" data-position-id="<%= title.id %>">
          <button type="button" class="pos-handle" aria-label="Drag to reorder <%= title.name %>">
            <svg width="12" height="18" viewBox="0 0 12 18" aria-hidden="true" focusable="false">
              <g fill="currentColor">
                <circle cx="3" cy="3" r="1.6"/><circle cx="9" cy="3" r="1.6"/>
                <circle cx="3" cy="9" r="1.6"/><circle cx="9" cy="9" r="1.6"/>
                <circle cx="3" cy="15" r="1.6"/><circle cx="9" cy="15" r="1.6"/>
              </g>
            </svg>
          </button>
          <span class="pn"><%= title.name %></span>
          <span class="state <%= title.active? ? "on" : "off" %>"><%= title.active? ? "Active" : "Inactive" %></span>
          <%= button_to title.active? ? "Deactivate" : "Activate", admin_position_title_path(title), method: :patch,
                params: { position_title: { active: !title.active? } }, class: "toggle", form: { class: "posform" } %>
        </div>
      <% end %>
      <span class="pos-status" data-reorder-target="status" role="status" aria-live="polite"></span>
    </div>
  <% else %>
    <p class="page-sub">No post positions yet.</p>
  <% end %>

  <div class="addrow">
    <%= form_with url: admin_position_titles_path, method: :post, scope: :position_title do |form| %>
      <div class="fl">
        <%= form.label :name, "Position name" %>
        <%= form.text_field :name, class: "f" %>
      </div>
      <%= form.submit "+ Add position", class: "btn-secondary" %>
    <% end %>
  </div>
<% end %>
```

(The manual "Order" number field is removed; the add form is now just name + submit.)

- [ ] **Step 2: Add the handle and status styles**

In `app/assets/tailwind/application.css`, immediately after the existing `.pos .toggle { ... }` rule (~line 363), add:

```css
.pos-handle { flex: 0 0 auto; display: inline-flex; align-items: center; justify-content: center; width: 28px; height: 32px; padding: 0; margin: 0; border: none; background: none; color: #b3a67d; cursor: grab; touch-action: none; }
.pos-handle:hover { color: var(--color-navy); }
.pos-handle:active { cursor: grabbing; }
.pos-ghost { opacity: .4; }
.pos-drag { box-shadow: 0 8px 20px rgba(0,0,0,.18); border-radius: 6px; background: #fff; }
.pos-status { display: block; min-height: 20px; margin-top: 10px; font-size: 14px; font-weight: 600; color: var(--color-green); }
.pos-status.pos-status-error { color: var(--color-red, #b00020); }
```

- [ ] **Step 3: Verify the full test suite still passes**

Run: `bin/rails test`
Expected: PASS (0 failures, 0 errors). If a `--color-red` variable is undefined the CSS falls back to `#b00020`; no test depends on it.

- [ ] **Step 4: Commit**

```bash
git add app/views/admin/position_titles/index.html.erb app/assets/tailwind/application.css
git commit -m "feat: drag-handle reordering UI for post positions"
```

---

### Task 7: Manual end-to-end verification

**Files:** none (verification only).

- [ ] **Step 1: Start the server bound to 0.0.0.0**

Run: `bin/rails server -b 0.0.0.0`
(Andre works off-box; must bind `0.0.0.0`, host IP 192.168.37.41. WebAuthn passkeys need a secure context, so sign in over `localhost`/HTTPS if the login path requires a passkey.)

- [ ] **Step 2: Verify the interaction**

Visit `/admin/position_titles` and confirm:
- Every row shows a grip handle on the left; the whole row groups handle + name on the left, state + toggle on the right (nothing stranded).
- Dragging a row by its handle reorders it; on drop, "Order saved" appears briefly.
- Reloading the page shows the new order persisted.
- The add form has no "Order" field; adding a position places it at the bottom of the list.
- On a touch device / browser touch emulation, dragging by the handle works.
- Type sizes remain ≥ 16px for names, ≥ 13px for state labels.

- [ ] **Step 3: Confirm reorder persists across a hard reload**

Reorder two rows, note the sequence, then hard-reload (`Ctrl/Cmd+Shift+R`). The order must match what you left.
