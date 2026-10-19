# Contact the Post

## Member job and scope

An enabled signed-in member can find the Post's general email and contact its current
officers without searching the full People directory. The combined **Contact the Post**
page helps members choose whom to contact, with the Commander for Post matters and the
Service Officer for veterans' and families' needs. It is a primary destination on desktop
and in the phone Menu. People remains a separate
directory, linked from the contact page. Shared contact links return here after sign-in.

Use the organization's existing `public_email` and optional `mailing_address`. Do not
invent a Post phone number, mailbox recipient, or response-time promise. Andre selected
`wipost165@gmail.com` for Post 165 on October 18, 2026; save it in the organization's
existing email setting rather than hard-coding it into application behavior.
Show email addresses as ordinary `mailto:` links and phone numbers as ordinary `tel:`
links, with the actual address/number as link text. Do not repeat them as Call or Email
buttons. There is no message form, delivery queue, or automatic sending.

Current officers come from active Post positions with assignments covering the Post's
local date (inclusive start/end). Lead with Commander and Service Officer, then list
other officers in configured position order. Exclude future/ended
assignments, inactive positions, other organizations' positions, and people hidden from
the member directory. Show each distinct person/position once, retaining multiple current
offices held by the same person. This uses the existing Post-position model; it does not
infer officer/committee/honorary categories from display names, which have no separate
classification in that model. Historical titles never imply a current assignment.
The two standard office names select presentation guidance only; they never confer
authority. Unrecognized/custom positions retain their ordinary contact listing rather
than receiving guessed responsibilities.

Each primary contact has a one-sentence responsibility and two short examples under
“Contact them when:”. Write these as situations an ordinary member might face, using
“You…” rather than listing officer tasks or broad topics. Commander: concerns about
Post decisions or treatment, and raising an issue at a meeting. Service Officer:
connecting veterans and families with benefits guidance and local support. Do not claim
the Post Service Officer is an accredited representative, provides legal/medical advice,
or can promise benefits. If either current officeholder or their direct contact details
are missing, provide a clearly labelled route through the Post email instead.

Other standard Post offices also receive a short responsibility sentence and two examples.
Assistant roles receive only “Assists the [primary role].” with no examples or extra duties,
as Andre requested in the design revision. Their officer names and contact details remain.

Display officer names in first-name then last-name order. Prefer the current
`roster_name`, as the member directory does, and reorder a `Last, First` label.
Existing people's split fields can predate a later roster import; use `first_name`
and `last_name` only when the roster name is blank. Preserve roster labels already
in first-name-first order, including `First Last, Sr.`. Move a trailing suffix (`Sr`, `Jr`,
with or without a period, or II, III or IV) from either name part to the end of the
display name. Put a comma before Sr/Jr and a space before Roman numerals. Preserve
recorded capitalization and optional periods, middle names, initials and compound
surnames; show a suffix once if both fields repeat it. Only recognize
complete trailing suffix tokens, not ordinary initials or parts of a name.
Use `Person#first_last_display_name` on both this page and the public officers API.
Keep the existing row layout, 17px name links and wrapping. Format names at display
time without rewriting roster fields or changing other name/official-record workflows.

These are member-facing summaries informed by the [2026 American Legion Officer's Guide](https://www.legion.org/getmedia/9886852f-7570-4d04-85e8-2832116fdb63/27ia0226-post-officers-guide.pdf),
printed pages 19–20 and 26–29. The guide supplies general role context; Andre's instructions
establish the two main contacts and the 2nd Vice Commander's focus on fundraising and
events. The Chaplain's description also draws on The American Legion's
[Chaplain's Handbook](https://www.illegion.org/wp-content/uploads/2016/01/Chaplains-Handbook-WEB_0.pdf),
printed pages 3–4 and 10: spiritual guidance, visits, cards and calls, alongside support
during illness and bereavement. These outreach details are explicit in that handbook;
the 2026 Officer's Guide's short Chaplain section emphasizes ceremonies and bereaved
families. Frame outreach as a reason to contact the Chaplain, without promising a visit.

Use `directory_email_address` and `directory_phone_number`, including their existing
roster fallback, without revealing login email, private membership fields, or account
state. An officer does not need a login account to be listed. All readers, including
administrators, see this same member contact projection. Changes appear on the next
request, and private contact pages are not cached by HTTP or Turbo snapshots.

When Post email is missing, direct members to officers below. When an officer has no
contact details, explain that directly and refer to the Post contact above. When no
current assignments are recorded, explain the absence without implying offices are vacant.

## Visual direction — revised October 18, 2026

Follow The 1919: authority navy `#0A2240`, service gold `#C6A15B`, cream `#F4EEDD`,
paper `#FBF7EC`, and ink `#1B222B`. Keep system sans for this working page: 24px page
title, 20px office headings, 17px names, 16px body and links, and 14px secondary notes.

The earlier boxed choices gave repeated headings and actions more prominence than the
officers themselves. The revised direction is a compact directory built from the shared
section headers and `.mrow-list` / `.mrow` vocabulary. The Post email sits directly under
the introduction. Commander and Service Officer lead one list under “Start here”; other
officers follow in the same row format. Use a subtle gold left edge for the two main roles.

Each desktop row aligns the office, officer name and linked contact details on the left,
with the responsibility and short examples on the right. This repeated alignment is the
page's signature: members can scan either whom to reach or what they handle. Below 900px,
each row stacks in that same reading order. Use one heading per office, ordinary underlined
links, short examples, and no boxed contact controls. Put the optional mailing address and
member-directory link in a quiet footer. Keep the existing 940px main measure.

The member-audience wording revision keeps this visual structure. Allow the concrete
“You…” examples to wrap naturally at the existing 16px size; do not compress the type
or turn the examples into another set of controls.

Preserve comfortable line spacing, wrapping for long addresses, visible keyboard focus,
and at least 24px text-link targets with space between adjacent links. The deliberate
design choice is to give the same simple directory structure to all officers while using
placement and the shared gold edge to identify the two starting contacts.

```text
Contact the Post
Find the right person for your question.
Not sure whom to contact? Email the Post: post@example.test

◆ Start here ─────────────────────────────────────────────
Commander                    Responsibility sentence
Officer name                 Contact them when:
email@example.test           • You have a concern about a Post decision or how you were treated.
(920) 555-0101                • You want to raise an issue at a Post meeting.
─────────────────────────────────────────────────────────
Service Officer              Responsibility sentence
Officer name                 Two short examples
email@example.test
(920) 555-0102

◆ Other current officers ─────────────────────────────────
Office and contact details   Responsibility and examples
Assistant role and contacts  Assists the primary role.

View member directory        Mailing address, when recorded
```

## Stored guidance and public officers API — October 18, 2026

Store the approved responsibility sentence and ordered examples on each `PositionTitle`
as `contact_description` (plain text) and `contact_examples` (a JSON array of plain-text
strings). The member page reads those saved values; code defaults are only initial data
for newly created standard positions. A reversible migration backfills existing standard
roles without creating assignments or changing authority. Renaming a position preserves
its saved guidance. Custom roles start blank. Assistants always store only “Assists the
[primary role].” and an empty examples array, including after a rename. Preset reuse
never replaces an administrator's saved guidance or public-listing choice.

An administrator with existing `manage_settings` authority opens **Administration →
Post Positions → Edit contact guidance**. Use The 1919's ordinary single-column form:
role heading, responsibility textarea, examples textarea (one per line, at most two),
a public-officer-listing checkbox, and Save/Cancel. Explain that the text appears on the
member page and accompanies an officer's name on the public website when listed.
Show errors with retained input. Assistants have fixed text and only the listing control.
At desktop and phone widths retain the shared form measure, 16px controls and comfortable
spacing. No second website editing/account system or new permission grant is introduced.

Andre explicitly requested a public page showing who the current officers are, alongside
the approved role explanations. The existing member directory alone does not authorize
publication of every Post position. Add a dedicated `website_officer_listing` flag to
positions: initially enable the standard officer roles (including Assistant Chaplain)
in the migration and on new-installation preset creation; other custom positions start
private until an administrator selects them. Turning the flag off removes that office
from the public feed, while preserving its member contact listing. Active status,
current assignment dates and directory exclusions continue to apply independently.

Add `GET/HEAD /public/v1/officers` to the existing website-token-authenticated,
read-only publishing controller. Return `schema_version: 1`, `complete: true`,
`as_of` (the Post's local date), `timezone`, `post: {name, email}` (general Post email),
and `officers`, ordered by configured office order/name and officer name. Each officer
has only `name`, `office`, `responsibility`, `examples`, `primary_contact`, and
`display_order`. A responsibility may be null when its saved text is blank. Use the
same saved name display as the member directory. Include current assignments for active,
publicly listed offices and directory-visible people. Dates are inclusive at both ends.
Deduplicate person/office assignments, retaining multiple offices for the same person.
Unassigned offices do not appear; absence is not a declaration of vacancy.

This is an explicit public-name projection, not a serialization of roster records.
Personal email addresses, phone numbers, home addresses, membership data, internal ids,
assignment dates, account state, portraits and directory links are excluded. Contact
routes use only the Post's general email. Introductions/portraits keep their separate
consent and publication workflow. This public-officer policy does not authorize images.

Reuse website-token Post scoping, authentication before conditional reads, ETags,
five-minute private caching, method restrictions and errors. Saved name/assignment edits,
turnover, roster exclusions and listing changes appear on subsequent origin reads;
downstream caches retain only the remaining 300-second freshness budget. Document the
exact contract and a server-side consumer handoff for `wipost165`. Companion-repo
implementation and deployment are separate from delivering this backend contract.

## Verification

Exercise member navigation, signed-out return after sign-in, account disabling,
directory privacy, inclusive local-date boundaries, officer turnover on later requests,
multiple offices, inactive/foreign positions, and missing contact data with synthetic
records. Check actual mailto/tel destinations without sending mail or placing calls.
Render desktop, tablet, 390px and 320px layouts; inspect screenshots, focus, readability,
and horizontal overflow. Use only the test database for browser fixtures.

### Initial implementation verification — October 18, 2026

- `bin/rails test`: 1,518 tests, 15,774 assertions, zero failures/errors/skips.
- `bin/rails test test/system/post_contacts_test.rb test/system/workspace_navigation_test.rb`:
  7 browser tests, 164 assertions, zero failures/errors/skips. After final page spacing
  refinement, the two contact browser tests passed again with 59 assertions.
- Focused RuboCop: all 11 changed Ruby files passed. Brakeman: zero errors or security
  warnings. `git diff --check` passed.
- Inspected synthetic screenshots at desktop and phone widths, including long contact
  details and keyboard focus. Browser assertions checked 1400px, 900px, 390px, and 320px
  layouts, 44px contact buttons, text sizing, and no horizontal overflow. Captures are
  under `tmp/contact-the-post/screenshots/`.

These checks exercise the Rails page and rendered link destinations. They do not send
email, place calls, verify an external email/phone application, or establish production
deployment. No real member records were used for the preview.

### Member guidance revision — October 18, 2026

- Saved `wipost165@gmail.com` in the local development organization's `public_email`
  setting and verified the persisted value. No production connection was used.
- Contact, primary navigation, and shared-link sign-in tests: 30 tests, 333 assertions,
  zero failures/errors/skips. They include primary-contact guidance and ordering,
  missing-officer/contact fallback, and preserving the configured order for other uses.
- The two contact browser workflows passed with 84 assertions after the layout and
  wording changes, including desktop, tablet, 390px, and 320px layouts. Refreshed synthetic
  screenshots show the two main contacts and the chosen Post email.
- Focused RuboCop passed for the four changed Ruby files; `git diff --check` passed.
  The earlier full-suite and Brakeman results above describe the initial implementation,
  not a repeat of those checks after this revision.

### Release verification — October 18, 2026

- Final application suite: 1,520 tests, 15,811 assertions, zero failures/errors/skips.
- Full browser suite: 110 tests, 5,904 assertions, zero failures/errors/skips.
- RuboCop: 648 files, no offenses. Brakeman: zero errors or security warnings.
- Bundler Audit and Importmap Audit found no vulnerable dependencies.
- Release transport preflight passed using one retained SSH control master. The live
  revision was confirmed to be an ancestor of the release base before deployment.

These are local checks and transport evidence; production deployment and the saved
production email require separate verification after the release.

### Directory redesign verification — October 18, 2026

- Rechecked the role summaries against the 2026 Officer's Guide, printed pages 19–20
  and 26–29. Assistant descriptions follow Andre's separate instruction to state only
  whom they assist, without examples. Vice commanders retain their distinct duties.
- Contact, navigation and shared-link sign-in tests: 31 tests, 354 assertions,
  zero failures/errors/skips. Assistant Chaplain and Assistant Adjutant cases verify
  the short explanation, absence of examples, and preserved contact links.
- Contact browser workflows: 2 tests, 107 assertions, zero failures/errors/skips.
  Checked desktop, 900px, 390px and 320px layouts, plain underlined contact links,
  no contact buttons, keyboard focus, long addresses, missing contacts and turnover.
  An initial browser check detected a fallback email link below the 24px target;
  the corrected link passed the clean rerun.
- Reviewed desktop and phone captures, including the assistant row and empty states.
  Screenshots use synthetic officers and are under `tmp/contact-the-post/redesign/`.
- Focused RuboCop: 3 files, no offenses. `git diff --check` passed.

This revision is local; these results do not establish a new production deployment.

### Member-audience wording verification — October 18, 2026

- Replaced topic fragments with concrete member situations under “Contact them when:”.
  Updated the 2nd Vice Commander to fundraising and events per Andre, and expanded the
  Chaplain's description using the Chaplain's Handbook references above.
- Existing contact controller tests: 10 tests, 147 assertions, zero failures/errors/skips.
- Existing contact browser workflows: 2 tests, 107 assertions, zero failures/errors/skips.
  Reviewed the longer copy at desktop and 320px; text wraps without horizontal overflow
  and retains the existing readable type. Captures use synthetic records and are under
  `tmp/contact-the-post/member-guidance/`.
- Focused RuboCop: 3 files, no offenses. `git diff --check` passed.

These wording changes are local and have not been deployed.

### Stored guidance and public officers verification — October 18, 2026

- Focused model, member page, admin, public feed, website-token and handbook checks:
  54 tests, 1,386 assertions, zero failures/errors/skips. These exercise saved edits
  appearing on later member/API reads, invalid-input recovery, revoked/foreign authority,
  Post scoping, explicit public listing, names without personal contacts, assignment
  deduplication, multiple offices, hidden/removed people and inclusive local-date turnover.
- `APP_TIME_ZONE=America/Chicago bin/rails test`: 1,530 tests, 16,041 assertions,
  zero failures/errors/skips. Two existing handbook fixtures now use the Post-local
  date for assignments instead of UTC `Date.current`, matching the governing role policy.
- Contact and Post Positions browser workflows: 5 tests, 187 assertions, zero
  failures/errors/skips. The editor's desktop/phone save and invalid-input recovery
  workflow passed again with 34 assertions after moving captures to the saved form.
  An initial harness failure compared an expected nil with `assert_equal`; comparing
  the saved guidance/listing attributes corrected the assertion without changing behavior.
- Reviewed desktop and phone editor/member captures under
  `tmp/contact-the-post/persisted/`: 16px controls, wrapping without horizontal overflow,
  retained errors/input, saved public-listing choice and plain member contact links.
- A synthetic PostgreSQL temporary-table migration check verified exact approved
  backfill, assistant/custom defaults, standard public-listing choices, unchanged
  authority/order, and both schema rollbacks. No real member records were used.
  Both migrations also completed in the local development database without resetting it.
- Focused RuboCop and `git diff --check` passed. Brakeman reported zero errors and
  zero security warnings. Public API examples and local documentation links were checked.

The checks above preceded production release and do not establish deployment. The
companion website still needs the consumer/page work described in
[PUBLIC_OFFICERS_WEBSITE_HANDOFF.md](PUBLIC_OFFICERS_WEBSITE_HANDOFF.md).

### Final local release checks — October 18, 2026

- `bin/rails test` with the default UTC application timezone: 1,530 tests,
  16,041 assertions, zero failures/errors/skips. The first UTC run exposed 18 older
  tests whose assignment fixtures used UTC dates while policy uses the Post's local
  date. Corrected those role fixture dates and the related dated-agenda browser fixtures;
  application permission and date-selection behavior was not changed.
- Full RuboCop: 651 files, no offenses. Bundler Audit and Importmap Audit reported
  no vulnerable dependencies. The earlier Brakeman check had zero errors/warnings.
- Revalidated OpenAPI and documentation examples against nine synthetic API responses;
  all passed, including authentication, cache headers and malformed-field rejection.

CI and production verification are separate from these local results.
