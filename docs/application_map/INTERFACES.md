# Interfaces and application inventory

Baseline and evidence meanings: [Application map](../APPLICATION_MAP.md).
Behavior targets: [Workflows](WORKFLOWS.md). Exact method/path declarations:
[routes](../../config/routes.rb). This inventory groups interfaces by user job;
an entry is not a statement that a runtime request succeeded.

## Entry, identity, and personal controls

| Interface | Pages and actions | Authority/data | Workflows |
| --- | --- | --- | --- |
| First setup `/setup/new` | Post identity, time zone, default place, first person's details, optional American Legion preset; create installation and first session | Fresh install; existing records with missing setup completion require operator recovery; publisher grant excluded | SET-01 |
| Sign in `/session/new` | Email request; passkey control; generic sent notice | Anonymous, enabled existing account to consume a real challenge; throttled requests | AUTH-01–03 |
| Code `/session/code` | Enter 8-digit code, request another email; link/code error guidance | Encrypted browser challenge, unexpired unused purpose-specific challenge | AUTH-01 |
| Email link `/session/magic_link` | GET/HEAD confirmation screen then POST consumption; already signed-in users go to Dashboard | One-use challenge; GET never signs in | AUTH-02 |
| Account Menu | Identity, current role, phone navigation, Profile, Sign out | Enabled session; keyboard open/close/arrows/Escape and focus restoration | NAV-01, AUTH-04 |
| Profile `/profile` | Own identity, directory cross-link, list/rename/remove passkeys; enrollment and Agent access | Own account only; Profile is not a roster/person editor | AUTH-06–08 |
| Optional dashboard passkey invitation | Set up or dismiss for current session | Member without a stored passkey; optional | AUTH-06 |
| Email mismatch review `/roster_email_review` | Update login to roster email, keep current email, remind later | Own account; login and directory/roster email are distinct | AUTH-07 |
| Passkey endpoints `/passkeys` | Credential list, registration/authentication options/submission, rename/removal | Own credential scope; fresh identity for enrollment; user-verified WebAuthn | AUTH-03, AUTH-06 |
| Enrollment confirmation `/passkey_enrollment_reauthentication` | Email code/link, passkey confirmation, cancel pending enrollment | Current session and pending enrollment bound together | AUTH-06, AUTH-09 |
| Personal Agent access `/agent_access_tokens` | List, creation form, one-time token reveal/copy, revoke consequence screen | Own token; recent authentication for issuance; 30/90/180-day expiry | AUTH-08 |
| Token identity confirmation `/agent_access_reauthentication` | Email code/link or passkey; returns to agent/website token creation as appropriate | Current session, purpose-specific identity | AUTH-08–09, PUB-01 |
| Official identity confirmation `/official_action_reauthentication` | Consequence/identity page, email code/link or passkey; successful confirmation completes prepared act | Exact minutes/action/payload/version/digest, live authority, one-use session-bound record | AUTH-09, MIN-07–10 |

Source families: [sessions](../../app/controllers/sessions_controller.rb),
[passkeys](../../app/controllers/passkeys_controller.rb),
[Profile](../../app/views/profiles/show.html.erb), reauthentication controllers in
the [source ledger](SOURCE_INVENTORY.md).

## Member reading and everyday Post work

| Interface | Pages and actions | Authority/data | Workflows |
| --- | --- | --- | --- |
| Dashboard `/`, `/dashboard` | Next/recent member Meeting, best available document, next three eligible activities, conditional email/passkey guidance | Enabled member; draft/handed-off minutes unavailable; activity categories and cancelled entries filtered | MEM-01 |
| Meetings `/meetings`, `/:id` | Upcoming and past archive; local-year grouping; details, place and Documents section; agenda/minutes links or honest absence labels | Every Meeting HTML occurrence is member-readable; only published agenda and member-selected attested/official revision exposed | MEM-04 |
| Agenda `/dated_agendas/:id` | Read saved heading/sections/items/wording, Print PDF | Published-only member lookup; no Commander cues or working officer roll call | MEM-04, PDF-01 |
| Member minutes `/meetings/:id/minutes` | Immutable selected revision, business/outcomes/attendance, attestation, approval/correction state, expandable provenance, Print PDF | Attested or final copy, including last attested revision during reopening; no transcript or AI evidence | MEM-04, MIN-08–11, PDF-01 |
| Calendar `/calendar` | Month navigation, week-start/display controls, event-type filters, events/default view, deadlines view, public preview, Print PDF | Enabled member; public preview is still authenticated; selected projection excludes private project context | CAL-01, PDF-01 |
| Calendar event `/calendar_events/:id` | Schedule, location, attendance/visibility, description, cancellation, optional Endeavor link; manage actions when authorized | All enabled members read private event details; public-preview lookup rejects members-only event | CAL-01–03 |
| Endeavors `/endeavors`, `/:id` | Active/completed work, detail, optional due date, open/completed next steps, upcoming/past activities; history and officer updates | Member-readable; agenda priority and editing/history controls restricted | END-01–04 |
| Endeavor source `/endeavors/:id/source` | Focused cited passage reader; standalone page and modal; full-minutes navigation; unavailable page | Related current member-visible immutable units only; invalid/unrelated/foreign/draft references unavailable | END-03 |
| People `/people`, `/:id` | Search/sort, officer/member grouping, directory contact and roles, person detail; extra membership/admin controls when permitted | Directory-visible people for members; complete membership for entitled callers; login/grant administration separate | MEM-02–03, ADMIN-01–03 |

Source families: [Dashboard](../../app/controllers/dashboard_controller.rb),
[Meetings](../../app/controllers/meetings_controller.rb),
[member minutes](../../app/controllers/meeting_minutes_controller.rb),
[calendar](../../app/controllers/calendar_controller.rb),
[Endeavors](../../app/controllers/endeavors_controller.rb),
[People](../../app/controllers/people_controller.rb).

## Officer meeting workspaces

The `/admin` prefix is an interface location, not blanket administrator authority.
Scoped controllers inherit their own guards; technical screens use Admin::BaseController.

| Interface | Pages and actions | Authority/data | Workflows |
| --- | --- | --- | --- |
| Officer tools / Administration `/admin` | Grouped destination rows, roster attention/status, and scoped-duty explanation; links to record work, roster, roles/admins/connections/agent tokens, publishing | Hub capability list in User; each target retains its own guard; Jobs link requires settings, minutes, or agenda management | NAV-01 |
| Meetings `/admin/meetings` | List, create/edit, occurrence workspace, create agenda, start minutes, transcript and documents, remove empty occurrence | Read: agenda/minutes/internal-record capability; scheduling mutations: `manage_agendas` | MTG-01–02, AGN-01, MIN-01 |
| Dated agenda `/admin/dated_agendas/:id/edit` | Ordered sections/items, add catalog item, add discussion, add Endeavor, edit/move/reorder/remove, approve/publish/reopen/delete, member PDF/private notes PDF | `manage_agendas`; drafting only for structure edits; private notes PDF additionally needs current position authority | AGN-01–07, PDF-01 |
| Dated sections | New/edit, create/update/delete/move/reorder | Agenda-local records; locked-parent and populated-section restrictions | AGN-02 |
| Dated items | Catalog selector, new discussion, edit rich wording/summary/private cues/wording flags/behavior/section, remove/reorder | Copies independent of catalog/template; same-organization/parent checks | AGN-02–04 |
| Officer roll call | Edit dated office/person snapshots and ordering, refresh from assignments for meeting date | `manage_agendas`, draft agenda, roll-call item; member rendering excludes working notes fields | AGN-05 |
| Minutes workspace `/admin/meetings/:id/minutes` | Heading edit; sections/items/outcomes/attendance forms; move/remove; transcript, draft runs, PDFs, lifecycle actions/history | Read: minutes/handoff/attestation/internal capability; edit: `manage_minutes` and editable state | MIN-01–03, MIN-07–11 |
| Restricted transcript | New pasted/plain-text source, retention selection, restricted detail | Write: `manage_minutes`; read: that capability or `view_internal_records`; one source per Meeting | MIN-04 |
| AI draft run | Request form, progress/status polling, successful review page, error category, source lines, suggestions and attendance sheet | `manage_minutes`, editable minutes, available source; paid request distinct from viewing | MIN-05–06 |
| Suggestion review | Use, edit-and-use, discard; attendance choices, counters; explicit Endeavor confirm/create/reuse | Human review; creating Endeavor additionally needs `manage_agendas`; no automatic official-record action | MIN-06, AGN-04 |
| Commander handoff | Consequence/confirmation pages; Send to Adjutant | `approve_minutes`; editable handoff copy remains private and editable | MIN-07, AUTH-09 |
| Adjutant attestation | Consequence/confirmation pages; Attest and share / Confirm corrections and lock | `attest_minutes`, resolved attendance/latest AI review, exact text binding | MIN-08, MIN-10 |
| Reopening | Reason form, identity confirmation, return to editable copy | `manage_minutes`; handoff/attested only; final official minutes never reopen | MIN-10–11 |
| Meeting approval | Later same-body Meeting selector, actual disposition/note, corrections pending flag, identity confirmation | `record_minutes_approval`; attested copy; eligible meeting already occurred and later than recorded occurrence | MIN-09–11 |
| Jobs `/admin/jobs` | Queue/worker heartbeat, ledger, attention/discarded filters; linked run/sync/history; minutes retry/discard/restore | Minutes runs: `manage_minutes`; history: `manage_agendas`; Loops: `manage_settings`; actions retain separate guards | MIN-12, ADMIN-06, END-04 |

Sources: corresponding [controller ledger](SOURCE_INVENTORY.md),
[minutes policy](../MINUTES_APPROVAL_AND_ATTESTATION.md),
[discussion behavior](../AGENDA_DISCUSSION_TOPICS.md).

## Reusable content, continuing work, and administration

| Interface | Pages and actions | Authority/data | Workflows |
| --- | --- | --- | --- |
| Agenda Catalog `/admin/agenda_item_catalog_entries` | Category list, new/edit wording/flags/cues/behavior, deactivate/remove, move/reorder | `manage_agendas`; reusable source, historical copies independent | TPL-01 |
| Meeting Types `/admin/meeting_types` | New/edit/deactivate/delete/reorder; seed/reset suggestions; template sections/items new/edit/move/remove/reorder/reset | `manage_agendas`; type deletion restricted by occurrence/doc references; source-item deletion nullifies dated lineage | TPL-02–03 |
| Endeavor editing `/endeavors/new`, `/:id/edit` | Title/summary/rich details/usual meeting body/importance/overall due date, complete/reopen | `manage_agendas`; no destroy route; identity decision human-owned | END-01 |
| Next-step forms `/endeavors/:id/tasks` | New/edit title/due date, complete/reopen | `manage_agendas`; independent task actor/completion state | END-02 |
| Officer update form | Append dated update on Endeavor detail | `manage_agendas`; append-only, no edit/delete route | END-01 |
| Manage Endeavors `/admin/endeavors` | Active/completed overview, attention/status filters, last history publication; Manage history link | `manage_agendas`; viewing/filtering makes no paid calls | END-04 |
| Manage history `/admin/endeavors/:id/history` | Sources, run/result/edition/reuse evidence, guidance, refresh scope, withdraw/resume | `manage_agendas`; paid refresh/resume separate from reading; versioned guidance not factual evidence | END-04 |
| Manage calendar `/calendar/manage` | Existing entries, event create/edit/delete/cancel/restore; meetings link to separate workspace | `can_manage_calendar?`; not automatically granted by `manage_agendas` | CAL-02–03 |
| Person administration in People detail | Create/change login email, disable/enable, return to roster control; dated position assignment; permission form | `manage_settings`; roster eligibility, manual override, unique email and last-admin protections | ADMIN-01–03 |
| Post Positions `/admin/position_titles` | Add/rename/reorder/deactivate title, membership-access setting | `manage_settings`; no routed general position-capability editor; assignments live on People | ADMIN-03 |
| Administrators `/admin/administrators` | List enabled technical administrators and links to person records | `manage_settings`; not an official minutes role | ADMIN-02 |
| Roster imports `/admin/roster_imports` | New CSV upload, history/result/problem/access notices, large-removal confirm, discard pending import | `manage_settings`; confirmed import affects People/accounts; upload is not a generic attachment | ADMIN-04–05 |
| Email audience `/admin/loops_roster_syncs` | Preview roster freshness/audience/skips/configuration, start sync, progress/result | `manage_settings`, successful roster, configured Loops, unique eligible emails; one active sync | ADMIN-06 |
| Installation agent access `/admin/agent_access_tokens` | All-user token audit list and revoke confirmation/action | `manage_settings`; revocation retains record, no secret redisplay | AUTH-08 |

## Website editorial workspace and consumer feed

| Interface | Pages and actions | Authority/data | Workflows |
| --- | --- | --- | --- |
| Website connections `/admin/website_access_tokens` | List, create, one-time reveal/copy, revoke consequence/action | `manage_settings` plus recent browser identity on issuance; Post-owned persistent token, no editorial authority | PUB-01 |
| Public website `/admin/website_publications` | Introductions/event publications, draft review beside published copy; homepage selection, calendar defaults link | `publish_public_content`; introductions independent of Person, opaque public IDs | PUB-02–05 |
| Introduction review `/admin/website_publications/:id/edit` | Draft wording, portrait upload/output previews, consent note, publish/withdraw; feature up to three | Exact draft/portrait consent and reviewed version; no auto-publication on Save | PUB-02–03 |
| Legacy event review | Calendar source selector, public wording, eligibility/title flags/reason, mark internal, publish/withdraw | Only while automatic calendar policy inactive; source-owned schedule/location and reviewed source version | PUB-04 |
| Calendar defaults `/admin/website_calendar` | Stored-type choices, actual notice preview, signed reviewed activation/update | `publish_public_content`; one-way activation; no title-inferred publication authority | PUB-05 |
| Automatic listing controls on Meeting/event forms | Type default / Show / Hide, dedicated website title/description, attendance, cancellation | Existing meeting/calendar manager authority; private descriptions/documents never become website copy | MTG-01, CAL-02–03, PUB-05 |
| `/public/v1/featured_members` | GET/HEAD featured introductions | Post website bearer token; approved publication/consent state | PUB-06 |
| `/public/v1/member_stories/:id` and portrait revision/size | GET/HEAD story detail and private stored WebP renditions | Same token including images and conditional requests; withdrawal/revocation rechecked | PUB-03, PUB-06 |
| `/public/v1/events` and `/:id` | GET/HEAD date-overlap notices (1–93-day interval); legacy or automatic branch | Same token; dedicated public projection, cancellation notices; no private project or official documents | PUB-04–06 |

The “public” path describes intended website content. It does not allow anonymous
fetches, browser-session authentication, personal-token substitution, or arbitrary
writes. The separate website serves its own public presentation; its pages are outside
this repository map. Sources: [feed controller](../../app/controllers/public/v1/publications_controller.rb),
[publishing](../PUBLIC_PUBLISHING.md), [connections](../WEBSITE_CONNECTIONS.md).

## Private API families

Read the signed-in permission-filtered `GET /api` handbook when operating the API.
Repository discovery uses source without creating credentials or signing into production.
Bearer writes need Idempotency-Key; session writes need CSRF protection. Current guards,
not endpoint naming, determine access. An API collection may be paginated or capped;
clients must inspect truncation/offset metadata where supplied.

| Family | Capabilities and operations located | Related workflows |
| --- | --- | --- |
| `/api` | Markdown/JSON handbook, caller capabilities, field/operation guidance | API-01 |
| People/officers/position titles/membership | Directory list/detail and officers; full-membership summary/renewals/roster/person; position-title list restricted to agenda manager | MEM-02–03, API-01 |
| People account | Account state/create/change email/disable/roster-control; `manage_settings` | ADMIN-01, API-02 |
| Meeting bodies/types | Read configured bodies/types; `manage_agendas`; no general configuration mutation | TPL-02, API-01 |
| Meetings | Baseline CRUD with officer-gated reads (G-01); [#77 member/delegate read contract](../MEMBER_MEETING_API_READS.md) adds safe baseline occurrence/documents while retaining officer mutation authority | MTG-01–02, MEM-04 |
| Dated agendas/items/roll calls/catalog | CRUD within exposed family, approve/publish/reopen; item and catalog reorder; roll-call update/refresh; Endeavor placement | AGN-01–07, TPL-01 |
| Working minutes/sections/items/outcomes/attendance | Read/create/heading update/PDF, structured mutations/reorder, explicit Endeavor confirmation; restricted workflow access | MIN-01–04, MIN-06 |
| Draft runs/suggestions | List/show/create, failed retry/discard/restore, attendance review, use/edit/discard | MIN-05–06, MIN-12 |
| Minutes handoff/attestation | Bearer-only exact delegated actions with explicit capabilities and provenance; no membership approval/reopening/amendment endpoint | MIN-07–08, API-03 |
| Jobs | Scoped queue/run/sync read; retry/discard operations live on draft-run resources | MIN-12 |
| Calendar/events | Member read, manager writes, projection/filter/pagination/lock contracts | CAL-01–03 |
| Endeavors/tasks/updates/history | Member reads; agenda-manager mutations, completion/reopen, append update, history operations | END-01–04 |
| Publications/calendar defaults | Publisher-only editorial parity, consent/eligibility/internal/publish/withdraw/feature, portrait upload/read/history, policy preview/apply | PUB-02–05 |

No API creates/reveals/revokes personal or website credentials, changes personal
permissions/positions, uploads a National roster, starts Loops sync, or approves
membership minutes. Do not infer these capabilities from a broad “API parity” title.
Examples and request fields live in the existing focused API documents and handbook.

## Technical surfaces and unavailable capabilities

| Surface | Boundary |
| --- | --- |
| `/up` | Rails process health; not proof that login, records, worker, provider or consumer works |
| `/internal/dated-agenda-pdf-source`, minutes/calendar equivalents | Expiring signed organization/document/variant token and loopback-only request; renderer input, not member navigation |
| Rails Active Storage/Action Text engine paths | Framework attachment/representation/rich-text integration; direct-upload action explicitly returns 404; do not classify as an authorized generic document workflow |
| Static assets/icons/importmaps | Layout/editor/print/runtime dependencies; no independent business state |
| `/letter_opener` | Mounted only in development; local email preview, never a production member feature |
| Recurring jobs | Finished-job cleanup, agent-execution cleanup, Endeavor history recorded-request and stalled-run recovery; background operational transitions, not a nightly test-quality reviewer |
| Accepted-minutes amendments, transcript purge UI/job, full-roster CSV export | Planned/unmapped; stored policy/metadata or old design prose does not establish an available action |
| General Person creation/edit, installation settings after setup, Meeting Body CRUD, general document archive, event registration/volunteer scheduling, recurring meetings | No mapped dedicated current web workflow; do not invent screens or tests from generic examples |

See [source inventory](SOURCE_INVENTORY.md) for every current discovery file, including
templates rendered by another controller (PDF sources, fallback pages and mailers).
