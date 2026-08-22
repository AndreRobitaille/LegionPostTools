# People Directory and Membership API Design

**Date:** 22 AUG 2026
**Status:** Approved for implementation
**Durable policy:** `docs/ROLES.md`

## Purpose

A signed-in person, or an agent acting for that person, needs a machine-readable way to
find Post members and current officers. The Commander, Adjutant, and 1st Vice Commander
also need complete membership and renewal information in useful bulk form.

The private API must enforce the same authority as the website. An agent token is another
credential for the person, not a separate role or a weaker integration account.

## Scope

This first read-only slice includes:

- a complete signed-in-member directory with name, current Post roles, directory email,
  and directory phone;
- current-officer lookup, including exact role filtering;
- individual directory profiles;
- full membership summary, renewal worklist, individual roster record, and roster list
  for callers with full membership access;
- automatic full membership access from current assignments to configured membership
  leadership positions;
- full membership access from existing `manage_people` or `manage_settings` grants;
- the same directory/full-membership split in the People website;
- generated `/api` handbook entries for every new action; and
- explicit roster freshness and renewal-category definitions.

This slice does not add membership mutations, roster import through the API, committee
models, per-committee people scopes, or speculative granular capabilities. Other officers
and committee participants remain standard members until a concrete workflow justifies a
narrow grant.

## Authority Model

Every authenticated user receives standard directory access.

A user has full membership access when any of these is true:

- the user has `manage_people`;
- the user has `manage_settings`; or
- the user's person has a current assignment to an active `PositionTitle` configured to
  grant full membership access.

`PositionTitle` receives a `grants_full_membership_access` boolean. The American Legion
Post preset enables it for Commander, 1st Vice Commander, and Adjutant. The setting stays
attached to the position record when its display name changes, so runtime authorization
never depends on matching title text. Existing standard preset titles are backfilled once
by migration and administrators may change the setting on Post Positions.

An assignment is current when `starts_on <= Date.current` and `ends_on` is absent or on or
after `Date.current`. Ending the assignment therefore ends assignment-derived membership
access. Historical Commander assignments and Past Post Commander status grant nothing by
themselves.

Full membership access is not technical administration. Only `manage_settings` may see or
change login accounts, login state, and application permission grants on the website.

## Directory Visibility

The signed-in member directory contains current Post people. It excludes people marked
removed from the imported roster and people whose normalized roster status is `expired`
or `deceased`. People without roster status remain visible so locally created officers,
initial setup users, and future non-roster participants are not accidentally hidden.

Full membership callers may see removed, expired, and deceased records through membership
surfaces because those states are necessary for roster administration and renewal work.

Directory contact fields come from `Person`, never the associated `User` login email.
Prefer locally held directory contact fields when present, with roster contact fields as
the fallback until a later contact-preference feature provides an explicit choice.

## API

All routes require an authenticated session or active personal agent token. Session and
token callers receive identical data for identical authority. These read responses use
`Cache-Control: no-store`.

### Standard directory

- `GET /api/people`
  - Complete directory, ordered by last name then first name.
  - Optional `q` performs case-insensitive name matching only.
  - Returns `count`, `returned_count`, `offset`, `limit`, and `truncated` metadata.
- `GET /api/people/:id`
  - One directory-visible person.
- `GET /api/officers`
  - People with a current dated position assignment.
  - Optional `role` is an exact, case-insensitive position-title filter.

Directory person fields:

- `id`;
- `name`;
- `roles` (current role names);
- `email_address`; and
- `phone_number`.

No member number, roster status, paid-through year, address, login email, login state,
permission grant, or internal note appears in these payloads.

### Full membership

- `GET /api/membership/summary?membership_year=2027`
- `GET /api/membership/renewals?membership_year=2027`
  - Optional `state` filters the worklist to one returned renewal state.
- `GET /api/membership/people/:id?membership_year=2027`
- `GET /api/membership/roster?membership_year=2027`

`membership_year` is required and must be a four-digit year within a conservative valid
range. The API never guesses what a human meant by "this year."

Membership list payloads use offset/limit metadata. The default and maximum are both 500,
which gives the first installation its complete small-Post worklist in one request while
remaining explicit if a later installation exceeds the bound.

Membership serializers include imported roster fields and the derived `renewal_state`,
but exclude login/account state, permission grants, and internal notes.

## Renewal Categories

Categories are disjoint and evaluated in this order for roster-backed people:

1. `removed` — `roster_removed_at` is present.
2. `deceased` — normalized member status is `deceased`.
3. `lapsed` — normalized member status is `expired`.
4. `unknown` — normalized member status is neither `active` nor `grace`.
5. `paid_up_for_life` — active/grace and membership type identifies PUFL.
6. `unknown` — active/grace but paid-through year is missing.
7. `paid_ahead` — paid-through year is later than the requested year.
8. `paid_for_year` — paid-through year equals the requested year.
9. `needs_renewal` — paid-through year is earlier than the requested year.

The API says `paid_ahead`, not `multiyear`, because a future paid-through year does not
prove how the membership was purchased.

Summary counts include:

- total roster records;
- present roster records;
- current members (normalized `active` or `grace`, excluding removed);
- one count for each renewal state; and
- the requested membership year.

Every membership response includes the latest completed roster import time and whether it
is more than 30 days old. An absent import time is explicitly reported as unavailable and
stale.

## Website Behavior

The People list and person page use the same full-membership predicate as the API.

- Standard members see only directory-visible people and directory-safe person details.
- Full membership callers see expired, deceased, and removed records plus National roster
  details, filters, and paid-through information.
- Login Account and permission controls render only for `manage_settings`, even when the
  viewer otherwise has full membership access.

Internal code and copy should describe "full membership access," not generic "officer
access." Past Post Commanders and other officers must not be uplifted merely because they
hold an officer-like title.

## Post Positions UI Direction

**Subject:** the Post Positions settings screen used by the installation administrator.
**Single job:** make it unmistakable which current offices carry complete membership
visibility while preserving the existing quick reorder and activation workflow.

The screen stays within the established 1919 system rather than becoming a generic roles
matrix:

- **Color:** Navy `#0A2240`, gold `#C6A15B`, paper `#FBF7EC`, warm rule `#E6DCBE`, muted
  slate `#6B7684`, and Legion red `#8C1622` only for errors.
- **Type:** Georgia for the restrained page/section identity already established by the
  app; system sans for body, controls, and data labels; tracked uppercase utility labels
  only where the existing system uses them.
- **Layout:** each draggable position row keeps its name as the anchor, adds a quiet
  second line reading `Full membership access` when enabled, and keeps activation and
  access actions adjacent on the right. At narrow widths the row wraps into a readable
  action group rather than squeezing controls.
- **Signature:** a small gold key marker beside `Full membership access`, tying authority
  to a specific Post office without adding decorative cards or a generic permission-grid
  aesthetic.

The page introduction explains the consequence in plain language: anyone currently
assigned to a marked position can see complete membership and renewal information. The
action says `Grant membership access` or `Remove membership access`; it does not expose a
database field name.

This addition deliberately avoids a new dashboard, animation, or color system. The unique
Post-specific decision is that authority is visibly attached to the office row and follows
the dated assignment.

## Error and Privacy Behavior

- Unauthenticated calls return the existing private-app 401 response.
- Standard members receive 403 for every membership endpoint.
- A directory-hidden person returns 404 to a standard caller.
- Invalid membership years, offsets, limits, or renewal states return structured 422 JSON.
- Search is parameterized and does not include hidden member numbers.
- Serializers enumerate allowed fields; they never call broad model serialization.
- No directory or membership response is cached by a browser or intermediary.

## Verification

- Model tests for directory visibility, directory contact fallback, and current
  assignment-derived access, including ended and inactive positions.
- Preset and position-title tests for membership-access defaults and configuration.
- HTML controller tests proving standard, full-membership, Past Post Commander, and
  `manage_settings` boundaries.
- API tests for directory bulk/search/show, officer filtering, complete membership
  authorization, field exclusions, renewal categories, freshness, pagination metadata,
  and immediate bearer-token authority changes after an assignment ends.
- Handbook tests proving all catalog actions are routed and only authorized actions appear.
- Desktop and narrow-width browser review of People and Post Positions.
- `bin/rails test`, `bin/rubocop`, `bin/brakeman`, and `bin/bundler-audit` before completion.
