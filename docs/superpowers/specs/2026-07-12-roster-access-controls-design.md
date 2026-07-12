# Roster Access Controls — Status, Overrides, and Large-Removal Confirmation

This spec updates the roster-import access rules after the Admin & Roster redesign. It
supersedes the earlier rule in
`docs/superpowers/specs/2026-07-12-admin-roster-visual-ux-design.md` that said returning
members do **not** auto-re-enable sign-in.

The goal is to keep National roster status as the default source of truth for sign-in access,
while giving administrators an explicit, reviewable way to make exceptions.

## Problem

The current importer disables sign-in when a roster-backed person disappears from an import.
That solved the immediate “left the post but still has app access” problem, but it leaves two
gaps before real post use:

1. National membership status should also drive access. Active and grace members should retain
   access; expired, deceased, and roster-removed members should not.
2. A wrong but structurally valid spreadsheet can remove many members at once. Large removals
   need an explicit no-JS confirmation before People/User records are changed.

Administrators also need an escape hatch. A manual admin enable/disable should persist as an
exception until an administrator deliberately returns the account to roster-controlled access.

## Scope

In scope:

- Import-controlled sign-in access from roster membership status:
  - `active` and `grace` enable existing login accounts.
  - `expired`, `deceased`, and roster removal disable existing login accounts.
- Manual admin sign-in overrides on the person page.
- A “return to roster-controlled access” action.
- Import-result reminder of current sign-in exceptions.
- Large-removal confirmation when an import would remove more than 10 roster-backed people.
- Tests for importer safety, controller flow, and privacy/authz boundaries touched by this work.

Out of scope:

- Creating login accounts during import. Imports never create accounts.
- A permanent Admin subsection for all sign-in exceptions. The data/model should support one
  later, but this slice only surfaces exceptions on import results and the person page.
- Free-form override notes or a full audit log. The override timestamp/source state is enough
  for this slice.
- Changing member-facing People/person privacy. Members still never see login/access details.

## Access State Model

Add explicit override state to `users`:

- `login_access_override` — boolean, default `false`.
- `login_access_override_at` — datetime, nullable.

The existing `disabled_at` remains the actual sign-in gate.

Definitions:

- **Roster-controlled account:** `login_access_override == false`. Imports and revert actions may
  change `disabled_at` according to roster status/removal.
- **Admin override account:** `login_access_override == true`. Imports must not change
  `disabled_at`, whether the account is currently enabled or disabled.

Manual admin enable/disable on the person page:

- updates `disabled_at` as today;
- sets `login_access_override = true`;
- sets `login_access_override_at = Time.current`.

Returning to roster-controlled access:

- clears the override fields;
- immediately reapplies the roster-controlled policy from the person’s current roster state;
- must respect the last-enabled-administrator guard.

Last-admin guard:

- Any import-controlled disable or revert-to-roster-controlled action that would disable the last
  enabled `manage_settings` administrator is blocked.
- The account stays enabled.
- The operation records/shows a problem telling the administrator to review manually.

## Roster Status Policy

Normalize imported `member_status` by stripping whitespace and lowercasing. The only supported
status values for this slice are:

- `active`
- `grace`
- `expired`
- `deceased`

Policy:

| Person state | Roster-controlled login action |
|---|---|
| present with `active` | enable existing login |
| present with `grace` | enable existing login |
| present with `expired` | disable existing login |
| present with `deceased` | disable existing login |
| absent from imported roster | mark removed and disable existing login |

Unknown statuses should not silently grant or remove access. They should become import problems
for the row while preserving the rest of the import behavior. If the row is otherwise imported,
the access policy should skip changing that user and report the unsupported status clearly.

Imports never create login accounts. A lapsed member who had a disabled roster-controlled login
and later returns to `active`/`grace` is auto-re-enabled. A member with an admin override is not.

## Import Flow and Large-Removal Confirmation

The first upload parses the CSV and computes pending changes before mutating People/User records.

If the import would remove **10 or fewer** roster-backed people:

- apply the import immediately;
- update People/User records in one transaction;
- show the normal completed result page.

If the import would remove **more than 10** roster-backed people:

- create a `RosterImport` in `pending_confirmation`;
- persist the uploaded CSV or enough pending data to apply the same import after confirmation;
- do **not** change People/User records yet;
- show a no-JS confirmation page/result.

The confirmation page shows both numbers:

- “This would remove N members.”
- “This would turn off sign-in for M roster-controlled accounts.”

It also lists the removed members and shows current sign-in exceptions as context. Confirmation
requires an explicit checked box with grounded copy such as:

> Yes, remove N members and turn off sign-in where roster-controlled.

After confirmation, the app applies the stored pending import. If the checkbox is missing, the
page re-renders/redirects with a clear alert and no records are changed. If the pending import is
ignored, People/User records remain unchanged; the pending record is harmless history for now.

Confirmation is single-use and serialized with a row lock on the `RosterImport` record. The app
must reject confirmation if a newer `pending_confirmation` or `completed` roster import exists,
and it must re-check status, attachment presence, and supersession after locking before applying
the importer.

## UI and Reporting

### Person page — Login Account panel

For administrators with `manage_settings`, the Login Account panel shows whether sign-in is:

- **Roster-controlled** — access follows National roster status.
- **Admin override** — imports will not change this account’s sign-in state.

Admin enable/disable copy should make the exception explicit, for example:

- “Enable sign-in as an admin exception”
- “Disable sign-in as an admin exception”

When an override exists, show a “Return to roster-controlled access” action with helper copy that
explains the account will immediately follow the current roster status.

### Import result page

Completed import results continue to show created/updated/removed/problems. They should also
summarize access effects:

- sign-in enabled by roster status;
- sign-in disabled by roster status/removal;
- skipped because of admin override;
- skipped because it would disable the last administrator.

Show a quiet **Sign-in exceptions** panel when any admin overrides exist. This is the first review
surface for exceptions. It should list the person, current sign-in state, and a link to the person
page where the administrator can return the account to roster-controlled access.

For pending-confirmation imports, the Sign-in exceptions panel can be more prominent because the
administrator is deciding whether to accept a large access-affecting change.

### Member-facing privacy

Member-facing People and person views remain unchanged. Plain members must not see login state,
permissions, membership status, dues/paid-through, member number, or mailing address.

## Implementation Shape

Likely touch points:

- `User` model: override fields, roster-controlled helpers, last-admin-safe policy application.
- `RosterImports::Importer`: preflight/removal counting, pending confirmation, status-driven
  enable/disable, override skipping, summary counts.
- `Admin::RosterImportsController`: pending confirmation flow and required checkbox.
- `Admin::UserAccountsController`: admin enable/disable sets override; new revert action clears it
  and reapplies policy.
- `app/views/people/_login_account.html.erb`: override labels and revert control.
- `app/views/admin/roster_imports/show.html.erb`: pending-confirmation UI, access-effect summary,
  sign-in exceptions panel.
- Tests around importer, roster-import controller, user-account controller, and person-page views.

Keep the importer’s existing safety properties:

- no mass-removal on empty/all-problem files;
- last-admin guard;
- single-transaction application of accepted imports;
- no login account creation during import;
- structured `RosterImport#summary` for result/history display.

## Testing Plan

Importer/model tests:

- `active` and `grace` re-enable existing roster-controlled accounts.
- `expired` and `deceased` disable existing roster-controlled accounts.
- roster removal disables existing roster-controlled accounts.
- imports skip admin override accounts and report the skip.
- imports never create accounts.
- returning active/grace members are re-enabled only when roster-controlled.
- revert-to-roster-controlled reapplies the current roster policy.
- last-admin guard blocks import-controlled and revert-driven disables.
- zero-valid-row imports never mass-remove.
- imports with more than 10 removals create `pending_confirmation` and do not mutate People/User.
- confirming a pending import applies the stored import.

Controller/view tests:

- pending confirmation page shows removal count, sign-in-disable count, removed members, and the
  required checkbox.
- missing confirmation checkbox does not apply the pending import.
- confirmation is rejected when a newer `pending_confirmation` or `completed` import exists;
  confirming the older import must leave it pending and show the "can no longer be confirmed"
  alert.
- confirmation is single-use: after one successful confirm, a second POST to the same
  `confirm_admin_roster_import_path` is rejected, leaves the import completed, and shows that it
  can no longer be confirmed.
- completed import result shows access-effect counts and sign-in exceptions when present.
- person Login Account panel shows roster-controlled vs admin-override state.
- admin enable/disable sets override; revert clears it.
- member-facing People/person privacy remains intact.

Verification before completion:

```bash
bin/rails test
bin/rubocop
bin/brakeman
```
