# Foundation and Meeting Workflow Design

## Summary

LegionPostTools will start as a private internal operating tool for a local American Legion post or Legion-family installation. The first useful product is a structured meeting workflow for agendas, transcripts, AI-assisted minutes, review, attestation, acceptance, and archival.

The application should solve Robert E. Burns Post 165's immediate agenda and minutes problem while remaining configurable enough for another post or local Legion family to run its own copy from git or Docker without encountering hard-coded Post 165 assumptions.

## Product Philosophy

- Meeting records are the first-class workflow.
- Authenticity matters more than convenience once records become official.
- People and roles change over time, so role assignments must be historical.
- Post name, unit name, location, meeting bodies, officer titles, agenda templates, and provider settings must be configurable.
- Distribution is considered from the beginning, but v1 is not a SaaS platform or polished packaged product.
- AI drafts minutes; humans approve, attest, and accept them.
- The interface should guide low-computer-skill users through workflows instead of exposing raw database-style screens.

## V1 Scope

V1 includes:

- Browser setup wizard for first installation.
- Configurable organization/unit basics.
- People, users, historical position assignments, and permission capabilities.
- Passwordless authentication: passkeys first, magic-link email fallback.
- Meeting bodies, initially Post Executive Committee and Membership.
- Preset-assisted officer title setup for American Legion posts.
- Structured agenda templates and agenda creation.
- Structured agenda items with optional rich notes and tracked-item links.
- Transcript paste/upload.
- AI-generated minutes drafts.
- Adjutant review and editing.
- Commander approval.
- Adjutant attestation/signing.
- Distribution/export support for agendas and minutes.
- Acceptance of prior minutes by motion at the next same-body meeting.
- Immutable official minutes after acceptance.

Out of v1:

- Public website or public API.
- Full finance/accounting system.
- Full document archive beyond meeting artifacts.
- Broad committee/project management.
- Multi-tenant SaaS.
- Deep legal or organizational modeling of Auxiliary, Sons, Riders, or other Legion-family relationships.

## Organization Structure

The deployed app is a single installation with one database. It is not multi-tenant in v1.

An installation contains one or more organizations/units over time. V1 only needs one organization, but the model should not assume only one forever. Examples include an American Legion post, Auxiliary unit, Sons squadron, or Riders chapter.

A meeting body is a recurring group that holds meetings inside an organization/unit. Examples include Post Executive Committee, Membership Meeting, Finance Committee, or a special committee. A meeting body owns default agenda templates, default location, and default distribution behavior.

This keeps room for a local Legion family to share one deployment later without forcing v1 to understand every relationship between posts, Auxiliary units, Sons squadrons, and Riders chapters.

## People, Users, Positions, and Permissions

The app separates real-world identity, login identity, official roles, and application capabilities.

- A `Person` is a real human being with name and contact information.
- A `User` is a login account mapped to one person.
- A `PositionAssignment` records that a person held a title or role for a date range.
- A permission capability controls what a user can do in the app.

People can hold multiple positions at the same time. Positions are historical so old minutes still show who was Commander, Adjutant, Finance Officer, or committee chair at the time.

Official roles should not be confused with system administration. Commander or Adjutant users may receive admin-like capabilities during their term. A technical helper may have administrative capabilities without holding a Legion office.

Initial permission capabilities:

- Manage organization/settings.
- Manage people/users.
- Manage meeting bodies/templates.
- Create and edit agendas.
- Generate and edit minutes drafts.
- Approve minutes as Commander or equivalent authority.
- Attest minutes as Adjutant or equivalent secretary role.
- Record acceptance motions.
- View internal records.

## Passwordless Authentication

V1 should not use passwords.

- Primary login method: passkey.
- Fallback login method: magic link by email.
- No password reset flow.
- No OTP codes unless magic links prove insufficient later.

Every login-capable user needs a verified email address. Magic links must be short-lived and single-use. Passkeys must be revocable per user. Sessions should be revocable by a user with the appropriate management capability.

The first setup flow must safely create the first person/user with management permissions. After the first magic-link login, the app should guide the user to register a passkey.

Transactional email delivery is required for magic links and later document distribution. Loops.so is a preferred candidate if its API is reliable for transactional messages and group sends. Email delivery should be isolated behind a small service boundary so the provider can change later.

## First-Run Setup Wizard

If the app boots with no configured organization and no users, it should show a browser setup wizard.

The wizard creates:

- First organization/unit.
- First person/user.
- Initial management permissions.
- Initial meeting bodies if selected.
- Initial officer title catalog.

Setup should offer presets. The first preset should be `American Legion Post`. Later presets may include Auxiliary Unit, Sons Squadron, Riders Chapter, or generic nonprofit.

The American Legion Post preset should prepopulate common officer positions such as:

- Commander.
- 1st Vice Commander.
- 2nd Vice Commander.
- Adjutant.
- Finance Officer.
- Chaplain.
- Sergeant-at-Arms.
- Historian.
- Service Officer.
- Judge Advocate.
- Optional assistant roles.

The preset seeds editable configuration. The user can rename titles, remove unused titles, add local titles, reorder display order, and mark titles as required, common, or optional. Drag/drop is useful but not required in the setup wizard; agenda building is the higher-value drag/drop surface.

## Structured Agendas

Agendas should be structured records, not one large freeform document.

- Agenda templates contain recurring sections.
- Agenda sections are ordered containers.
- Agenda items are real records inside sections.
- Agenda items can be reordered or moved between sections.
- Agenda items can be plain one-off items or linked to tracked items.
- Each agenda item can have rich notes for bullets, sub-bullets, ceremony text, printable context, or pasted details.
- The printable agenda is generated from sections, items, and item notes.

Agenda items may include:

- Title.
- Rich notes.
- Importance: routine, normal, important.
- Optional linked tracked item.
- Optional owner/person.
- Expected action: discuss, report, vote, approve, assign, or informational.

Rails Action Text/Trix is the initial candidate for rich notes because it is Rails-native. If nested bullets or editing experience becomes a blocker, the editor can be revisited without changing the structured agenda model.

## Tracked Items

A tracked item is a long-lived topic, project, issue, or institutional history file. It is not required for every agenda item.

Examples:

- Buddy Checks.
- Car Show.
- Elections.
- Memorial Day Ceremony.
- Legion Riders Brat Fry.

Tracked items lean toward topic/history rather than heavy project management. They can accumulate appearances across meetings, decisions, motions, documents, notes, and follow-ups. Optional owner, status, dates, and task-like fields can be added when useful.

The app should make “track this over time” easy but deliberate. It should not automatically turn every agenda heading into a tracked item.

Old business can suggest active tracked items from prior meetings. AI may later suggest new tracked items or possible links, but humans should confirm merges, splits, or new long-lived items.

## Agenda Lifecycle

1. Create a meeting and choose the meeting body.
2. Apply the meeting body's default agenda template.
3. Edit date, time, location, sections, and items.
4. Add business items manually or from active tracked items.
5. Finalize the agenda for printing, exporting, or emailing.

Finalizing an agenda should make it clear which version was distributed. It does not need the same immutability as accepted minutes, but post-finalization edits should be visible enough to avoid confusion.

## Transcript and AI Minutes Drafting

Meeting recording happens outside the app in v1. After the meeting, a user pastes or uploads the raw transcript. The transcript may have no timestamps, no speaker labels, minimal punctuation, and speech-to-text errors.

AI minutes generation runs as a background job. OpenAI is the first intended provider. Provider credentials should come from environment variables or Rails credentials, not ordinary database settings.

AI input should include:

- Meeting body.
- Finalized agenda structure.
- Agenda item notes.
- Officer roster and historical position assignments.
- Committee assignments relevant to the meeting body.
- Full member/person name list when available.
- Known aliases or nicknames when available.
- Raw transcript.
- Active tracked items linked to the agenda.
- Optional previous accepted minutes for continuity.

The full member/person list acts as a name authority list so AI can prefer known spellings over transcript misspellings and flag uncertain matches.

AI output should include:

- Structured draft minutes aligned to agenda sections and items.
- Motions extracted when possible.
- Uncertain facts, names, or placements flagged for review.
- Suggested tracked-item updates or follow-ups.

The generated minutes should be agenda-aware but not transcript-order-bound. If officers discuss an old-business item during a report, the minutes should place the substantive content under the correct agenda item instead of preserving transcript order.

Detail level should follow item importance:

- Routine items get sparse official treatment.
- Normal items get concise summaries and decisions/actions.
- Important items get fuller context, rationale, motions, unresolved questions, and follow-ups.

AI output is never official. It is a draft for human review.

## Minutes Lifecycle

1. Meeting occurs.
2. Transcript is added.
3. AI or manual minutes draft is created.
4. Adjutant reviews and edits the draft.
5. Commander reviews and approves the draft, or returns it for revision.
6. Adjutant attests/signs the approved draft.
7. Minutes are distributed by print, export, or email according to meeting-body defaults.
8. Prior minutes appear as an approval item on the next same-body meeting agenda.
9. Acceptance motion is recorded at that later meeting.
10. Accepted minutes become official and immutable.

Suggested states:

- `agenda_draft`.
- `agenda_finalized`.
- `transcript_added`.
- `minutes_draft`.
- `adjutant_reviewed`.
- `commander_approved`.
- `attested`.
- `distributed`.
- `accepted_official`.

The exact state names can change during implementation, but the lifecycle boundaries should remain explicit.

## Official Minutes and Immutability

Accepted official minutes are append-only immutable records.

Before acceptance, drafts can be edited through the review workflow. After acceptance by motion at the next same-body meeting, official minutes cannot be edited by anyone, including administrators.

Later mistakes are handled only through later correction or amendment records linked back to the original minutes. The original accepted minutes remain unchanged.

Official records should snapshot historically important facts:

- Final rendered minutes content.
- Attesting person.
- Attesting role/title at the time.
- Attestation timestamp.
- Commander approval person and timestamp.
- Motion accepting the minutes.
- Meeting where acceptance occurred.

## Distribution, Export, and Email

Agendas and minutes must be printable and exportable. PDF generation should render structured records through a clean official template.

Meeting bodies can define default distribution behavior. For Post 165, likely defaults are:

- PEC agenda: print.
- PEC minutes: print for membership meeting context.
- Membership agenda: email before the meeting, print optional.
- Membership minutes: email after review/approval/attestation, then acceptance at the next membership meeting.

Email sends should be recorded with:

- Document sent.
- Recipient or list name.
- Sending person.
- Timestamp.
- Provider message ID if available.

The app should not become a marketing/list-management system in v1.

## Deployment Shape

Production will run on a Hetzner Cloud VPS that already hosts another Rails application. This app must be a separate Kamal service and must not assume it is the only app on the server.

Deployment should use:

- Latest stable Rails.
- PostgreSQL.
- Docker.
- Kamal.
- Active Storage for uploaded files and generated artifacts.
- Background jobs for AI, PDF, and email work.

Kamal service names, Docker image names, database names, volumes, and related infrastructure names must be unique to this app to avoid conflicts with existing services.

The app should be installable from git by another post later. V1 does not need a polished external installer, but the browser setup wizard should make a fresh deployment self-configuring after infrastructure is in place.

## Implementation Boundaries

- Use Rails conventions aggressively.
- Keep models boring and understandable.
- Do not build a generic workflow engine.
- Do not build full Legion Family relationship modeling yet.
- Do not build a public API yet.
- Do not build full project management yet.
- Do not build full finance/accounting yet.
- Treat structured agenda and minutes records as the core domain.
- Use rich text inside structured records, not as the overall structure.
- Keep AI replaceable behind a small service boundary.

## Risks and Follow-Up Decisions

- Passkeys may require more implementation effort than password auth.
- Magic-link email deliverability is critical.
- Loops.so must be validated for transactional auth email and document distribution.
- Action Text/Trix may not be ideal for nested bullets or item-level editing.
- AI minutes quality will need iteration with real transcripts.
- Too much structure could slow agenda creation if the UI is not carefully designed.
- Too little structure would undermine tracked items and long-term continuity.
- Browser setup wizard security needs careful handling so it cannot be reused after setup.
