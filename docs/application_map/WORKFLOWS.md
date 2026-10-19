# Behavioral workflow contracts

Baseline/evidence meanings: [Application map](../APPLICATION_MAP.md).
Interface entry points: [Interfaces](INTERFACES.md).
Discrepancies and unverified claims: [Evidence guide](MAINTENANCE.md).

These contracts describe observable Post work rather than particular implementation
methods. Each specifies start, trigger, resulting state, visible outcome, subsequent
behavior, and failures. Source references establish where to investigate; they do not
prove the target behavior. All entries are **source-located / runtime-unverified /
test-coverage-not-assessed**. Planned branches are explicitly identified.

Priority is validation priority, not severity of a discovered defect. Variants are
separate audit cases within an ID: a successful branch never covers its denied,
stale, invalid, or interrupted branch automatically. All synthetic evaluation uses
test data; no production actions or paid calls are implied by this document.

## Installation and authentication

Policy/source basis: [sign-in guide](../MEMBER_SIGN_IN_GUIDE.md),
[setup](../../app/controllers/setup_controller.rb),
[sessions](../../app/controllers/sessions_controller.rb),
[application/session policy](../../app/controllers/application_controller.rb),
[MagicLink](../../app/models/magic_link.rb),
[passkeys](../../app/controllers/passkeys_controller.rb),
[agent tokens](../../app/controllers/agent_access_tokens_controller.rb).

### SET-01 — Initialize an American Legion installation (P1)

- **Start:** Fresh installation; no usable configured Post/account. Existing records with incomplete setup require recovery.
- **Action:** Submit valid Post identity, time zone/place defaults and first person's account details; optionally select the Legion preset.
- **Result:** One complete installation, initial enabled administrator and selected defaults; no publisher grant.
- **Observe:** Signed-in Dashboard identifies the configured Post.
- **Then:** Setup cannot be rerun to replace the installation; first administrator can perform authorized configuration work.
- **Failures:** Invalid/duplicate email or missing fields leave no partial setup; concurrent submissions do not create competing installations; recovery requires operator help.

### AUTH-01 — Sign in using an email code (P0)

- **Start:** Anonymous person with an enabled account and usable login email.
- **Action:** Request sign-in email; enter its 8-digit code in the initiating browser.
- **Result:** An unused unexpired challenge becomes used and one authenticated session is established.
- **Observe:** Dashboard and signed-in identity appear; code entry/retry guidance is understandable.
- **Then:** Protected member pages open; replaying the code grants no new authentication.
- **Failures:** Unknown/disabled email receives generic request feedback but no usable login; wrong/expired/exhausted code, missing browser challenge, throttling or delivery failure never authenticates. Request feedback does not prove delivery.

### AUTH-02 — Sign in using an email link (P0)

- **Start:** Anonymous person with a valid unused sign-in link for an enabled account.
- **Action:** Open the link, then submit its confirmation control.
- **Result:** Only POST consumption uses the challenge and creates the session.
- **Observe:** GET/HEAD shows confirmation; successful submission opens Dashboard.
- **Then:** Private pages work; already-signed-in visits to sign-in screens return to Dashboard; a used link cannot be reused after logout.
- **Failures:** Expired, malformed, used, disabled-account or wrong-purpose links show failure without a session; email scanners merely opening a link must not sign anyone in.

### AUTH-03 — Sign in using a passkey (P0)

- **Start:** Anonymous browser on a supported origin; enabled account has a registered passkey.
- **Action:** Choose passkey sign-in and complete authenticator verification.
- **Result:** The credential is verified for its owner and a fresh session is established.
- **Observe:** Signed-in identity belongs to the credential owner; Dashboard opens.
- **Then:** Protected access works and credential last-use data updates.
- **Failures:** Cancellation, invalid/consumed challenge, foreign credential, disabled owner, unsupported browser/origin or failed user verification never authenticates; email sign-in remains discoverable.

### AUTH-04 — Sign out through the actual Menu control (P0)

- **Start:** Enabled signed-in member with an active browser session. Important variant: that session is referenced by historical official-action confirmations or reauthentication links.
- **Action:** Open Menu and click Sign out through the rendered control.
- **Result:** The current authenticated session terminates; its historical confirmation/audit evidence survives without retaining usable session authority.
- **Observe:** Sign-in page and “You are signed out” feedback; no HTTP 500.
- **Then:** Reload a protected page and follow a saved private URL: both require sign-in. Historical confirmations cannot be reused after a new sign-in. Other independent credentials/sessions follow their own lifecycle.
- **Failures:** Wrong request method, broken Turbo/control, foreign-key deletion failure, persistent authenticated cookie or still-accessible protected resource. A redirect or isolated session-method assertion alone is insufficient.

### AUTH-05 — Lose a session or current authority (P0)

- **Start:** Active session/token; account is disabled, session removed/inactive, token expired/revoked, or a dated duty/manual grant ends.
- **Action:** Request the next formerly permitted page/action using the old credential.
- **Result:** Invalid session/token no longer authenticates; loss of a particular duty removes only that authority.
- **Observe:** HTML sign-in/permission guidance or API 401/403, appropriate to the remaining identity.
- **Then:** Repeated requests and saved direct URLs remain denied; an ended officer's agent cannot preserve prior grants. Member baseline remains when the account stays enabled.
- **Failures:** Stale authorization retained in UI/API, cookie without corresponding session, disabled-user access, future/ended assignment treated as current. Source inactivity limit is 180 days, not a shorter assumed timeout.

### AUTH-06 — Manage personal passkeys (P1)

- **Start:** Signed-in member on Profile; recent identity or pending enrollment requiring confirmation.
- **Action:** Enroll a passkey, rename an owned credential, remove it, cancel enrollment, or dismiss optional invitation.
- **Result:** Only owned verified credentials change; enrollment challenge binds the current session/identity. Invitation dismissal does not create a credential.
- **Observe:** Profile shows saved nickname/list changes; fresh-auth flow returns to intended enrollment.
- **Then:** New credential signs in; removed credential fails; email login still works; cancelling leaves prior credentials intact.
- **Failures:** Another user's credential ID, old-session challenge, malformed verification, duplicate credential, authenticator cancellation, expired pending enrollment or lost fresh-auth context.

### AUTH-07 — Resolve a roster/login email difference (P1)

- **Start:** Signed-in member's roster email differs from login email and requires review.
- **Action:** Update login email, keep current, or remind later.
- **Result:** Selected decision/address is recorded; only Update changes login email.
- **Observe:** Dashboard guidance acknowledges choice; Remind later suppresses the current reminder.
- **Then:** Future email login uses the saved login address; a new roster address can require a new review; remind-later returns on later sign-in.
- **Failures:** Duplicate/invalid email rejects update visibly; no silent replacement of directory or roster contact information; unsupported decision does not change account.

### AUTH-08 — Issue or revoke personal delegated access (P0)

- **Start:** Enabled member managing own Agent access, or technical administrator reviewing installation tokens.
- **Action:** Confirm recent identity, choose token name/expiry, create and copy its one-time secret; later open revoke confirmation and submit revoke.
- **Result:** Expiring token represents current owner authority; revocation retains audit and disables use.
- **Observe:** Secret appears once on no-store creation response; list shows status/last use and appropriate ownership.
- **Then:** Token opens allowed `/api`; saved/revisited screens do not reveal secret; revoked/expired/disabled-owner token returns 401; later permission changes apply immediately.
- **Failures:** Invalid expiry/name, wrong-owner token, stale identity, browser back/snapshot secret retention, API token issuance shortcut. An administrator may revoke another user's token but cannot redisplay its secret.

### AUTH-09 — Confirm an exact privileged action (P0)

- **Start:** Current browser session with a prepared purpose-specific enrollment/token/official action.
- **Action:** Verify identity by email code/link or owned passkey; cancel or abandon as a separate variant.
- **Result:** Confirmation applies only to its purpose and session. For a prepared official act, successful verification completes that exact action.
- **Observe:** The intended screen/action status returns; no extra approval click after successful official confirmation.
- **Then:** Reuse, GET-only requests and a new session cannot execute the confirmation again.
- **Failures:** Expiry, logout during confirmation, changed text/version/payload, lost capability, wrong owner/purpose or double submit prevents the act without altering historical evidence. Ordinary drafting does not require repeated confirmation.

## Navigation and member reading

Policy/source basis: [member experience](../STANDARD_MEMBER_EXPERIENCE.md),
[navigation](../../app/helpers/navigation_helper.rb),
[Dashboard](../../app/controllers/dashboard_controller.rb),
[People](../../app/controllers/people_controller.rb),
[membership reports](../../app/services/membership_report.rb),
[member Meetings](../../app/controllers/meetings_controller.rb),
[member minutes](../../app/controllers/meeting_minutes_controller.rb).

### NAV-01 — Find a destination and return (P2)

- **Start:** Enabled member, scoped officer, administrator or publisher at desktop or narrow width.
- **Action:** Use tabs/phone Menu, keyboard navigation, Profile/back links and a permitted hub tile.
- **Result:** Navigation reflects current area/authority; destination performs its own authorization.
- **Observe:** Same primary destinations at both widths; Profile does not highlight Dashboard; Admin/Officer tools wording matches duty.
- **Then:** Saved direct links obey the same policy after authority changes; Escape closes Menu and restores focus.
- **Failures:** Hidden destination still reachable without authority, inaccessible keyboard controls, contradictory mobile links, wrong back target, overflow/clipped focus.

### MEM-01 — Find current Post business on Dashboard (P2)

- **Start:** Enabled member; variants with no Meetings, unpublished agenda, recent attested/final minutes, cancelled activities, multiple event types.
- **Action:** Open Dashboard and follow a document/activity action.
- **Result:** Next/recent member Meetings and next three eligible activities selected in installation time.
- **Observe:** Honest available/unavailable document labels; optional account guidance is subordinate to Post business.
- **Then:** Document link opens the member-visible record; cancelled and honor-guard/officer/member-meeting entries do not enter activity list.
- **Failures:** Draft content exposed, duplicate/dates confused, no-data states imply a nonexistent record, UTC rollover chooses wrong meeting, activity filtering differs from documented rules.

### MEM-02 — Find and contact another member (P1)

- **Start:** Ordinary member with directory-visible People; variants include removed/deceased/expired person and no search results.
- **Action:** Search/sort People and open a person; use displayed contact link.
- **Result:** Directory contains permitted people/contact/roles and ordinary service labels, not full roster/account data.
- **Observe:** Clear detail action, meaningful missing-data/empty results, readable desktop/phone rows.
- **Then:** Direct URL/API lookup respects visibility; contact comes from directory fields with documented fallback.
- **Failures:** Member number/renewal/address/login/grant leakage, hidden person's direct detail access, unsupported membership filters changing member baseline, capped list mistaken for complete Post population.

### MEM-03 — Work with membership information (P0)

- **Start:** Current full-membership officer or scoped full-membership grant; baseline member as denied variant.
- **Action:** Filter/read membership details or request API summary/renewals/roster for an explicit year.
- **Result:** Authorized complete membership information with defined population, paid-through/PUFL/renewal semantics and source freshness.
- **Observe:** Counts/worklists identify year/meaning; technical account controls remain separate.
- **Then:** Ending the assignment removes full-roster access in HTML and API while retaining directory baseline.
- **Failures:** Ambiguous “this year,” stored-person count called current membership, stale roster presented as current, historical/honorary office granting access, account-management powers inferred from roster visibility. CSV export remains planned.

### MEM-04 — Read the Meeting archive and its documents (P0)

- **Start:** Member with upcoming/past Meetings and each agenda/minutes lifecycle state.
- **Action:** Open archive/detail, read available agenda or minutes, optionally open PDF.
- **Result:** Occurrence remains readable without a published document; member receives only published agenda and selected immutable attested/final minutes.
- **Observe:** Minutes promoted when available; awaiting approval versus official/locked labels truthful; correction notice retains previous attested copy.
- **Then:** Draft direct URL unavailable; reopening agenda removes it until republished; corrected attestation replaces member revision without altering prior revisions.
- **Failures:** Working rows or transcripts leak; missing document shown as a broken action; title/date/place follows today's template; accepted copy silently changes. The baseline Standard-member `/api/meetings` discrepancy (G-01) and restricted summary disclosure were reproduced; [#77 contract/evidence](../MEMBER_MEETING_API_READS.md) records the scoped repair and verification.

## Accounts, roster, and officer turnover

Policy/source basis: [roles](../ROLES.md), [account guide](../USER_MANAGEMENT_GUIDE.md),
[User](../../app/models/user.rb), administrative account/grant/position controllers,
[roster import](../../app/controllers/admin/roster_imports_controller.rb),
[importer](../../app/services/roster_imports/importer.rb),
[Loops sync](../../app/controllers/admin/loops_roster_syncs_controller.rb).

### ADMIN-01 — Manage login access without destroying a person (P0)

- **Start:** Technical administrator on a Person; account absent/enabled/disabled, local or roster-managed.
- **Action:** Save login email, enable/disable sign-in, or return to roster control.
- **Result:** One account per person; roster eligibility/manual overrides applied; person and historical records retained.
- **Observe:** Clear enabled/off/roster-controlled status and unique-email/last-admin errors.
- **Then:** Disabled existing sessions/tokens stop working; eligible roster-controlled account follows later imports; manual disable stays off until explicit change.
- **Failures:** Disable presented as person deletion, bypass of last enabled administrator protection, ineligible roster member silently enabled, authorized roster reader acquiring technical administration.

### ADMIN-02 — Change explicit application duties (P0)

- **Start:** Technical administrator editing user's manual grants; assignment-derived authority may coexist.
- **Action:** Save selected capabilities or inspect administrator list.
- **Result:** Manual grants change; position-provided grants remain dated policy rather than permanent duplicates.
- **Observe:** Sources/effective duties are distinguishable; at least one enabled technical administrator retained.
- **Then:** User and existing agent gain/lose scoped actions on next request; neither technical administration nor publishing implies a personal official act.
- **Failures:** Revoked duty cached, last administrator removed, manual exception lost during office turnover, publisher/attester grant inferred from generic admin role.

### ADMIN-03 — Assign and end Post office (P0)

- **Start:** Technical administrator with configured positions and Person records.
- **Action:** Add/rename/reorder/deactivate position, choose membership access, assign dated term or change its dates.
- **Result:** Organizational history remains; authority supplied only by active policy/current inclusive term.
- **Observe:** Current/past roles and their derived capabilities distinguished.
- **Then:** At start/end boundary, HTML/API/private notes/calendar/full roster update appropriately; renamed title retains semantics; manual grants survive independently.
- **Failures:** Future/ended/honorary office grants operational authority, display name used as permission, missing/vacant office invented, membership-access setting silently grants administration. Position-capability editing is not an exposed form.

### ADMIN-04 — Import a National roster (P1)

- **Start:** Technical administrator with an approved synthetic/authorized roster CSV; existing People/accounts and import history.
- **Action:** Upload CSV and inspect results/problems/access notices.
- **Result:** Valid import records reconcile roster fields/accounts and retain detailed changes; local contact/login distinctions and manual exceptions respected.
- **Observe:** Created/updated/unchanged/removed/returned/problem counts, freshness and access effects visible.
- **Then:** Directory/membership/renewal results reflect successful import; unrelated local people and Post records persist.
- **Failures:** Malformed CSV, duplicate identities/emails, unsupported status, deceased-status reversal, bad upload or import failure must be explicit; generic success notice is insufficient evidence of reconciliation.

### ADMIN-05 — Confirm or discard a large-removal import (P0)

- **Start:** Import awaits large-removal confirmation with retained CSV; variants include a newer pending/completed import.
- **Action:** Inspect removals and explicitly confirm, or discard.
- **Result:** Only current confirmed pending import applies changes; discard leaves roster unchanged and retires pending source.
- **Observe:** Consequence and final import status/counts visible; superseded import cannot be confirmed.
- **Then:** Repeat confirmation cannot reapply stale roster; later directory/login changes match the completed import.
- **Failures:** Missing confirmation checkbox, superseded/missing pending file, double submission or old import replay must not remove people/access silently.

### ADMIN-06 — Synchronize the Post email audience (P1)

- **Start:** Technical administrator; completed roster, configured Loops and usable unique eligible emails.
- **Action:** Inspect audience/skips/freshness, request sync, leave and return to status.
- **Result:** One durable queued/running sync; contacts processed with recorded success/failure/skips.
- **Observe:** Queued/running/completed/failed state and actual counts; missing/shared/invalid emails explained.
- **Then:** Jobs/result pages retain outcome and source import; repeat request while active points to existing work.
- **Failures:** Missing roster/configuration, zero eligible contacts, provider outage, partial failure or absent worker cannot be reported as successful full delivery. This operation does not send a meeting notice.

## Reusable agendas and Meeting occurrences

Policy/source basis: [agenda/roll-call](../COMMANDER_AGENDA_AND_ROLL_CALL.md),
[Meeting foundation](../MEETING_FOUNDATION_AND_MEMBER_ARCHIVE.md),
[catalog](../../app/controllers/admin/agenda_item_catalog_entries_controller.rb),
[templates](../../app/controllers/admin/meeting_types_controller.rb),
[Meeting](../../app/models/meeting.rb), [DatedAgenda](../../app/models/dated_agenda.rb),
[template item](../../app/models/meeting_type_agenda_item.rb).

### TPL-01 — Maintain reusable catalog wording (P1)

- **Start:** Agenda manager, reusable catalog entries and already-created template/dated/minutes copies.
- **Action:** Create/edit/category-order/deactivate/remove catalog entry, wording flags or private cues.
- **Result:** Reusable source changes for later deliberate copies; historical saved content remains independent.
- **Observe:** Catalog order/availability and edited wording persist after reload.
- **Then:** New selection reflects current source; old agendas/minutes/PDFs retain saved wording/title/flags.
- **Failures:** Duplicate/foreign IDs, malformed reorder, invalid form, removed entry selectable again or source change propagating into historical records.

### TPL-02 — Build a Meeting Type template (P1)

- **Start:** Agenda manager with configured Meeting Bodies/catalog and a Meeting Type.
- **Action:** Create/edit/reorder/deactivate type; create/edit/move/remove sections/items copied from catalog.
- **Result:** Ordered reusable template saved; one coherent structure and no duplicate catalog placement per type.
- **Observe:** Reload preserves wording/order and section assignments.
- **Then:** Later dated agenda copies the chosen template; existing dated records stay independent.
- **Failures:** Populated section deletion, duplicate/foreign item, invalid reorder/name, moving into another type or treating catalog category as a meeting section. Meeting Body CRUD is not an exposed current screen.

### TPL-03 — Seed/reset/remove a template without rewriting history (P0)

- **Start:** Agenda manager; seeded/custom templates and dated documents may reference source items/type.
- **Action:** Seed missing suggestions, reset defaults/one suggested agenda, remove source item or attempt type deletion.
- **Result:** Future template content changes; dated copied content survives, optional item lineage may detach; referenced type cannot be deleted.
- **Observe:** Updated template and truthful restriction/error feedback.
- **Then:** Existing agenda/minutes and PDFs still render saved titles/text; custom/removed source handling follows documented seeder policy.
- **Failures:** Foreign-key 500, cascading dated deletion, silent rewrite after reset/rename, protected type deletion claiming success. Type-deletion failure handling is a candidate discrepancy (G-06).

### MTG-01 — Schedule or reschedule a Meeting (P1)

- **Start:** Agenda manager; active body/type and installation-local date/time/place defaults.
- **Action:** Create occurrence; later edit allowed heading/schedule/place or website notice fields.
- **Result:** One Meeting with saved place/time; only draft agenda heading syncs atomically. Body/type fixed after agenda creation; official context must remain protected.
- **Observe:** Member/archive/calendar and officer workspace show correct local date/time and agenda availability.
- **Then:** Midnight/DST and renamed default place do not shift old documents; approved/published agenda must reopen before heading change.
- **Failures:** Missing/invalid time/place, stale edit, mismatched organization, protected heading rewrite. Accepted-minutes Meeting heading protection needs investigation (G-04); immutable member revision remains separate evidence.

### MTG-02 — Remove an empty occurrence (P1)

- **Start:** Agenda manager; empty Meeting versus one with agenda/minutes/transcript or approval reference.
- **Action:** Submit delete through occurrence management/API.
- **Result:** Only legitimately empty/unreferenced occurrence removed; durable meeting record retained otherwise.
- **Observe:** Deleted occurrence absent, or plain restriction feedback with surviving documents.
- **Then:** Direct lookup unavailable for removed occurrence; existing document/approval links remain usable for protected occurrence.
- **Failures:** Stale/foreign lookup, deletion of historical approval source, orphan agenda/minutes/transcript or calendar treating formal Meeting as ordinary event.

## Dated agenda preparation

Policy/source basis: [discussion topics](../AGENDA_DISCUSSION_TOPICS.md),
[agenda/roll-call](../COMMANDER_AGENDA_AND_ROLL_CALL.md),
dated agenda controllers/models in [inventory](SOURCE_INVENTORY.md),
[Endeavor confirmation](../MINUTES_ENDEAVOR_CONFIRMATION.md).

### AGN-01 — Prepare one agenda for a Meeting (P1)

- **Start:** Agenda manager; Meeting with chosen type, no agenda.
- **Action:** Create agenda from the occurrence's template.
- **Result:** One draft with copied heading/place/sections/active items and source lineage.
- **Observe:** Officer workspace opens; member sees occurrence but “Agenda not published yet.”
- **Then:** Template edits do not change copy; repeat/concurrent create cannot make a second agenda; minutes later copy dated wording.
- **Failures:** Missing type, duplicate agenda, cross-organization source, incomplete template copy or free-standing agenda without Meeting.

### AGN-02 — Edit dated structure and wording (P1)

- **Start:** Agenda manager with draft agenda.
- **Action:** Add catalog item; edit title/summary/rich wording/private cues/flags; add/edit/move/reorder/remove sections/items.
- **Result:** Changes saved to this agenda only, in chosen order/section; populated/locked parent restrictions respected.
- **Observe:** Reload/editor/PDF reflect appropriate member wording and private separation.
- **Then:** Later template/catalog changes leave copy untouched; approval/publish prevents further structural edits until reopening.
- **Failures:** Stale item, malformed/partial foreign reorder, duplicate item, validation failure, lock acquired between page load/save, private cues appearing in member document.

### AGN-03 — Add a one-meeting discussion topic (P1)

- **Start:** Agenda manager; draft with an agenda-local section.
- **Action:** Add discussion title/wording and optional private cues/wording visibility.
- **Result:** Ordinary active business item in this agenda; no new catalog, template or Endeavor identity.
- **Observe:** Topic appears in ordered working agenda and permitted document variants.
- **Then:** Starting minutes copies topic; deleting/editing the meeting topic leaves reusable sources untouched.
- **Failures:** Missing title, foreign section, locked agenda or implicit continuing-work creation. API item fields follow its own explicit contract.

### AGN-04 — Deliberately create or link continuing work (P0)

- **Start:** Agenda placement requires `manage_agendas`/draft agenda; minutes confirmation requires `manage_minutes`/editable item, plus `manage_agendas` for new Endeavor creation.
- **Action:** Human chooses existing identity or confirms new specific Endeavor, optionally reviewing source-cited AI proposal.
- **Result:** Scoped identity link and human-confirmed record created atomically; copied meeting text remains independent.
- **Observe:** Chosen title/link visible; duplicate/missing-fact/stale errors understandable.
- **Then:** Later Endeavor changes do not rewrite meeting text; repeated confirmation cannot duplicate work; dismissing proposal creates nothing.
- **Failures:** Ambiguous generic identity, duplicate scoped title, stale item/proposal, foreign Endeavor, automatic AI identity decision or accepted-minutes link mutation.

### AGN-05 — Prepare a dated officer roll call (P1)

- **Start:** Agenda manager; draft roll-call item and dated assignments.
- **Action:** Inspect/edit snapshotted office/person rows or explicitly refresh for Meeting date.
- **Result:** Required vacancies and valid current-on-meeting-date officeholders represented; snapshot changes only through deliberate refresh/edit.
- **Observe:** Officer worksheet retains names/order and vacant labels; member agenda omits working attendance/private cues.
- **Then:** Officer turnover does not retroactively change saved roll call; minutes seeds factual attendance rows for human review.
- **Failures:** Today's officers substituted for historical term, optional vacant office manufactured, locked-parent refresh, incorrect duplicate/foreign row or unintended member publication.

### AGN-06 — Approve, publish, reopen, and republish an agenda (P0)

- **Start:** Agenda manager; draft/approved/published variants.
- **Action:** Approve draft, publish approved copy, or reopen locked copy to correct then approve/publish again.
- **Result:** Ordered lifecycle and actor/time fields; structure locks after approval; reopening returns draft and removes member publication.
- **Observe:** Accurate state and available controls; member direct/PDF access starts only at published state.
- **Then:** Saved member URL fails while reopened and works after republish; starting minutes does not itself publish agenda.
- **Failures:** Publishing draft, editing locked content, repeated/invalid transition, stale/concurrent action or treating agenda approval as official minutes approval.

### AGN-07 — Delete an agenda while retaining its Meeting/history (P1)

- **Start:** Agenda manager; removable dated agenda, with minutes-referenced agenda as protected variant.
- **Action:** Confirm removal through real UI/action or explicitly scoped API instruction.
- **Result:** Removable agenda deleted while Meeting remains; historical minutes and their required lineage survive. Source associations currently restrict deletion when minutes reference the agenda.
- **Observe:** Missing agenda after successful removal, or clear historical-reference restriction. Restriction error handling is source-unverified (G-07).
- **Then:** Successful deletion makes member agenda URL unavailable; protected minutes/agenda still render saved content. Body/type correction follows remaining historical protections.
- **Failures:** Silent deletion without intended consequence, unhandled delete restriction/foreign-key 500, Meeting/copy deletion or historical wording changes. Source action has no draft-only deletion guard; references may still prevent removal. API does not add a second destructive-authorization system.

## Minutes, restricted evidence, and official authority

Policy/source basis: [current minutes rules](../MINUTES_APPROVAL_AND_ATTESTATION.md),
[lifecycle](../MINUTES_LIFECYCLE.md), [MeetingMinutes](../../app/models/meeting_minutes.rb),
[confirmation](../../app/models/official_action_confirmation.rb),
[transcript](../../app/models/meeting_transcript.rb),
[generation job](../../app/jobs/minutes_draft_generation_job.rb),
[review service](../../app/services/minutes_drafting/review_suggestion.rb),
minutes controllers in [inventory](SOURCE_INVENTORY.md).

### MIN-01 — Start a structured minutes workspace (P1)

- **Start:** Minutes drafter; Meeting without minutes, with or without agenda.
- **Action:** Start minutes.
- **Result:** One working record with snapshotted heading/place, ordered agenda-derived structure/wording/Endeavor links and roll-call attendance where present.
- **Observe:** Private workspace distinguishes recorded narrative from agenda wording.
- **Then:** Edit working minutes independently; old agenda/template updates never rewrite copy; member publication waits for attestation.
- **Failures:** Duplicate/concurrent start, incomplete copy, missing/foreign parent, private Commander notes copied into member-bound text or one unstructured document replacing records.

### MIN-02 — Record and organize actual business (P1)

- **Start:** `manage_minutes`; draft or handed-off editable minutes.
- **Action:** Edit heading; add/edit/move/reorder/remove sections/items and rich recorded text.
- **Result:** This working copy persists in order, retaining historical source identities and record keys.
- **Observe:** Reload shows exact text/format; draft PDF matches current working rows even after handoff edits.
- **Then:** Attested copy requires audited reopening; final official copy never edits; member still sees prior attested copy during correction.
- **Failures:** Invalid/foreign move, stale heading/item, lost rich paragraphs/lists, validation errors, unauthorized mutation or a draft API bypassing locked state.

### MIN-03 — Record attendance, motions, and decisions (P0)

- **Start:** Minutes drafter; dated attendance and business item; unresolved facts explicitly marked.
- **Action:** Enter attendance, outcome kind/text/disposition/vote summary; confirm mover/seconder or mark unidentified.
- **Result:** Actual known facts saved with stable attribution; no invented names, counts, votes or procedures.
- **Observe:** Workspace/document uses plain Passed/Did not pass/Needs review language and correct order.
- **Then:** Unresolved attendance/latest AI review prevents readiness; corrected factual choices persist into immutable revision.
- **Failures:** Missing/wrong participant, inappropriate roster identity, unknown outcome presented as passed, unsupported enum, partial bulk attendance save, foreign item or stale row.

### MIN-04 — Add and read a restricted transcript (P0)

- **Start:** `manage_minutes` writer, or `manage_minutes`/`view_internal_records` reader; Meeting has at most one source.
- **Action:** Paste text or upload valid UTF-8 `.txt` up to 5 MB; select retention; later inspect source.
- **Result:** Restricted source, kind/digest/metadata/retention stored; never automatically official text.
- **Observe:** Authorized source page/API displays evidence; member document and general handbook omit transcript.
- **Then:** Duplicate source rejected; purged/unavailable source cannot generate draft. Automatic purge scheduling and deliberate purge interface are planned/unmapped (G-03).
- **Failures:** Empty/binary/oversized/bad encoding, paste/upload conflict, cross-Meeting evidence, attachment/direct-upload bypass or leaking source through PDF/history.

### MIN-05 — Request an AI draft without replacing the record (P1)

- **Start:** Minutes drafter; editable minutes, available restricted source, configured provider and worker; synthetic provider for offline verification.
- **Action:** Explicitly request drafting and leave/reopen progress page.
- **Result:** Durable pending/running attempt with source/config fingerprints/provider identity; completed suggestions or recorded safe failure.
- **Observe:** Progress polling, terminal state, evidence/review actions or safe error; manual minutes remain intact.
- **Then:** Worker polling resumes background provider request; successful suggestions still need human review; failure supports explicit linked retry.
- **Failures:** Missing worker/source/configuration, enqueue error, timeout/interruption/provider/validation failure or lost response identity; no automatic suggestion application, attestation or paid retry from merely viewing.

### MIN-06 — Review AI evidence and suggestions (P0)

- **Start:** Minutes drafter; succeeded run, unreviewed item/outcome/additional-item/attendance/Endeavor proposals with evidence ranges.
- **Action:** Inspect cited transcript; use, edit-and-use or discard; review complete attendance sheet; explicitly confirm proposed Endeavor when warranted.
- **Result:** Selected changes only, reviewed actor/time/applied-record provenance; discard alters review status without adding business.
- **Observe:** Counters and saved attendance/text update, via Turbo or HTML fallback.
- **Then:** Reload preserves review; second use cannot duplicate outcome/text; readiness clears only after required factual review. AI proposal needs human identity decision.
- **Failures:** Stale rows, unresolved mover/seconder/disposition, source unavailable, forged foreign suggestion, partial sheet save, duplicate use or discarded suggestion silently applied.

### MIN-07 — Send a Commander draft to the Adjutant (P0)

- **Start:** `approve_minutes`, draft ready for handoff.
- **Action:** Choose Send to Adjutant and confirm exact action/identity; explicitly instructed bearer equivalent is separate variant.
- **Result:** Immutable handoff revision and event; legacy `approved` means ready for Adjutant review.
- **Observe:** Handoff status and next actor clear; not called Meeting Body approval or member publication.
- **Then:** `manage_minutes` can edit without another Commander handoff; Adjutant may attest exact current text directly; unchanged handoff provenance stays truthful.
- **Failures:** Unresolved attendance/latest review, lost authority, changed digest/version, reused confirmation or later edits falsely attributed to Commander's original revision.

### MIN-08 — Attest and share the exact current minutes (P0)

- **Start:** `attest_minutes`; editable draft or handoff with readiness resolved; Commander handoff not mandatory.
- **Action:** Attest and complete exact identity confirmation.
- **Result:** Immutable current text, signer/time and lifecycle provenance; status attested unless finishing a pending correction decision.
- **Observe:** Members can read attested revision, awaiting real later meeting approval; officer draft edits stop until reopening.
- **Then:** Member HTML/PDF/history choose same revision; mutation of working rows cannot silently alter attested payload. Direct Adjutant draft has no invented Commander endorsement.
- **Failures:** Unreviewed facts, stale confirmation/content, wrong capability, GET execution, misleading official/final label or showing mutable rows instead of revision.

### MIN-09 — Record actual approval at a later Meeting (P0)

- **Start:** `record_minutes_approval`; attested copy and later same-body Meeting that has occurred.
- **Action:** Select actual approving Meeting/procedure/disposition; confirm identity and record approval.
- **Result:** Exact revision linked to later approval; approved-as-presented/already-incorporated-corrections becomes `membership_approved` and locked.
- **Observe:** Official approved/locked state and approving Meeting/procedure visible.
- **Then:** All editing/deletion/reopening rejected; approving Meeting cannot be removed; historical revision and actor remain available.
- **Failures:** Future/same/foreign/wrong-body Meeting, invented motion/vote, other procedure without factual note, changed revision, duplicated confirmation or administrator without explicit authority.

### MIN-10 — Correct an attested record before final lock (P0)

- **Start:** Attested copy or handed-off draft; not final official. For meeting-approved pending corrections, real decision/details already recorded.
- **Action:** Either audited reopen with reason/identity, or record Approved with corrections plus pending changes; drafter enters corrections; Adjutant confirms exact finished text.
- **Result:** Old revisions/events retained. Ordinary reopen ends in new attestation; pending meeting decision ends in corrected attestation and atomic final lock linked to original approval provenance.
- **Observe:** Members retain old attested copy with correction context while editing; finished copy/status replaces it after attestation.
- **Then:** No second vote/approval step manufactured; corrected member source invalidates stale derived history; new official copy cannot reopen.
- **Failures:** Missing reason/correction description, lost prior member copy, rewriting old attestations, unsupported second Commander approval gate, stale confirmation or detached approving decision.

### MIN-11 — Preserve official records against later mutation (P0)

- **Start:** Final membership-approved minutes and their sections/items/outcomes/attendance/revisions/events/Meeting context.
- **Action:** Attempt old edit links, API writes, deletes/reopen or related source changes.
- **Result:** Final record/payload remains unchanged, through application and database protections where implemented.
- **Observe:** Plain locked/unavailable action; official HTML/PDF consistently render approved revision.
- **Then:** Later corrections belong to a later record or future linked amendment, not silent edits. Amendment workflow remains planned and has no current route.
- **Failures:** Source rename cascades, official underlying rows modified, new working text shown as official, historical Meeting context altered (G-04), or roadmap amendment treated as available bypass.

### MIN-12 — Recover from failed background minutes work (P1)

- **Start:** Scoped Jobs viewer; minutes management for retry/discard/restore; failed run and editable source/minutes for retry.
- **Action:** Inspect worker/queue/run status; retry failed run, discard from attention, restore attention.
- **Result:** Retry creates linked new attempt while retaining original; one active retry; discard/restore changes attention only.
- **Observe:** Durable ledger/status/filter counts, failure category, enqueue error and review destination.
- **Then:** Returning after worker completion finds same run; discarded run stays auditable; agenda-only manager sees history jobs without minutes evidence, admin sees Loops separately.
- **Failures:** Retry running/succeeded run, deleted attempt, duplicate retries, absent source/worker, misleading queue health or viewing Jobs triggering paid work.

## Endeavors, activities, and derived evidence

Policy/source basis: [governance](../ENDEAVOR_GOVERNANCE.md),
[activities](../ENDEAVOR_ACTIVITIES.md), [history](../ENDEAVOR_HISTORY_AI.md),
[Endeavors](../../app/controllers/endeavors_controller.rb),
[tasks](../../app/models/endeavor_task.rb),
[source reader](../../app/controllers/endeavor_sources_controller.rb),
[history management](../../app/controllers/admin/endeavor_histories_controller.rb),
[calendar contract](../CALENDAR_API.md).

### END-01 — Maintain one durable body of Post work (P1)

- **Start:** Agenda manager deliberately identifies coherent specific work; existing identity may be active/completed.
- **Action:** Create/edit title/summary/details/usual body/importance/deadline; append update; complete or reopen.
- **Result:** Same identity and history retained; append-only update and completion provenance; no destroy operation.
- **Observe:** Saved details/completion date, appropriate member versus agenda-priority presentation.
- **Then:** Reopen continues same record; completion does not cancel events/finish tasks/rewrite meeting text; updates are later facts, not altered prior entries.
- **Failures:** Duplicate/broad taxonomy identity, stale edit, invalid/foreign body, hidden cascading completion or officer update treated as official minutes.

### END-02 — Manage next steps independently of the project (P1)

- **Start:** Agenda manager; Endeavor and optionally dated open/completed tasks.
- **Action:** Add/edit title/due date, complete or reopen task.
- **Result:** Task's own state, creator/editor/completer/time retained independently.
- **Observe:** Open/completed sections and calendar deadline projection reflect changes.
- **Then:** Parent completion/event cancellation do not change task; reopened task returns without fabricated completion; due date does not create event or agenda item.
- **Failures:** Stale/missing lock, foreign task, invalid date/title, completion actor/time mismatch, unintended cascade or deadline shown as scheduled attendance event.

### END-03 — Follow history back to the actual record (P0)

- **Start:** Member reads Endeavor with member-visible related revision/item/unit evidence.
- **Action:** Expand account/decision/evidence and follow source link in modal or standalone page; close/Escape/back.
- **Result:** Exact cited current member-visible passage and complete outcome, not working/transcript text.
- **Observe:** Attribution/revision context, full-minutes link, restored focus/scroll; plain unavailable source response when stale/unrelated.
- **Then:** Corrected attestation withholds affected stale summaries/links while unrelated valid history remains; without JavaScript source links still work.
- **Failures:** Unknown unit/revision, foreign/draft/unrelated source, modal traps, missing outcome, stale generated text presented as authoritative or blank evidence treated as proof.

### END-04 — Generate and manage derived meeting history (P1)

- **Start:** Existing human-defined Endeavor, eligible immutable member minutes, enabled configuration/worker/budgets; manager for guidance/refresh/withdraw/resume.
- **Action:** Attestation commits a request for each eligible Endeavor. After-commit jobs and the 15-minute job recover those requests and established authorized retries, including missed enqueue and active-run overlap. Manager refresh, guidance, withdraw, and resume stay explicit.
- **Result:** Source-grounded extraction and separate checks, retained verified results/reuse, immutable replacement edition only after successful validation; failure preserves still-valid prior edition.
- **Observe:** Member overview/dated accounts and coverage date; manager sees runs/cost/error/source/reuse and withdrawn state.
- **Then:** A new or corrected attested source processes incrementally and invalidates affected generated material. Creating an Endeavor does not start a paid run. Membership approval of the same revision changes labels without paid regeneration. Withdrawal and resume preserve the audit.
- **Failures:** Unsupported fact, missed/unknown citations, budget/input limit, interruption/provider failure, stale guidance, ambiguous identity; never create/merge/complete an Endeavor or alter minutes automatically. Runtime model quality remains separate evidence.

### CAL-01 — Inspect schedule, deadlines, or public preview (P1)

- **Start:** Enabled member; Meetings, ordinary/Endeavor events, deadlines, cancellations and selected month/types.
- **Action:** Change month/view/type/display/week start, open entry or Print PDF.
- **Result:** Installation-local selected schedule/deadline projection; public preview contains only its permitted event projection and remains private.
- **Observe:** All-day/multiday/time/cancellation distinctions, clear empty filters, readable narrow/list/grid presentation.
- **Then:** Entry links return to correct record; filters survive PDF/failure navigation; due dates do not imply attendance/public publication.
- **Failures:** Bad/out-of-range month, DST/UTC crossover, event overlap omitted, member/private project leakage into preview or preview mistaken for actual website feed.

### CAL-02 — Save an occurrence with the correct calendar authority (P1)

- **Start:** Calendar manager (`manage_settings` or current qualifying position); standalone/Endeavor event or new event form.
- **Action:** Save title/type/date/time/end/all-day/place/attendance/private description and dedicated website fields when applicable.
- **Result:** Valid same-organization occurrence and creator/editor; attendance separate from website listing and project context.
- **Observe:** Event detail/calendar/Endeavor activities show saved local schedule; invalid form preserves useful feedback.
- **Then:** Member read and authorized API agree; active automatic listing uses dedicated public copy; ordinary private fields never leak.
- **Failures:** Manual agenda grant mistaken for calendar management, end before start, invalid date/boolean, stale version, foreign Endeavor or source save silently restoring withdrawn legacy publication.

### CAL-03 — Cancel, restore, or remove an event safely (P1)

- **Start:** Calendar manager, past/future event or protected meeting-like entry.
- **Action:** Cancel/restore through edit, or confirm deletable event removal with current version.
- **Result:** Cancellation preserved as notice where listed; restore is deliberate; ordinary deletion removes source and public detail; meeting-like deletion rejected.
- **Observe:** Status and exact deletion restriction; no misleading control for formal/member/officer Meeting entries.
- **Then:** Private calendars and feed respect cancellation/hide/delete; task/Endeavor states unchanged; formal Meeting managed separately.
- **Failures:** Stale delete, missing version, title/category-recognized meeting bypass, cancellation republishing old snapshot, orphan publication or disappearing cancellation when a notice is expected.

## Editorial authority and website delivery

Policy/source basis: [publishing](../PUBLIC_PUBLISHING.md),
[website connections](../WEBSITE_CONNECTIONS.md),
[automatic calendar](../AUTOMATIC_WEBSITE_CALENDAR.md),
[WebsitePublication](../../app/models/website_publication.rb),
[calendar policy](../../app/services/website_publishing/calendar_policy.rb),
[feed](../../app/controllers/public/v1/publications_controller.rb).

### PUB-01 — Connect or disconnect a Post-owned website (P0)

- **Start:** Technical administrator in browser with recent identity; Post connections list.
- **Action:** Create named connection, copy secret once and configure authorized consumer; later revoke or rotate with deliberate overlap.
- **Result:** Organization-owned read-only credential, separate from personal tokens/editorial grants; audit retained.
- **Observe:** One-time no-store reveal, status/creator/revoker/last use; revoke consequence clear.
- **Then:** Disabling creating admin does not disconnect site; revoked token fails every feed/portrait/conditional request; neither token can substitute for other credential type.
- **Failures:** Secret in URL/browser JS/back snapshot, unauthorized issuance, token reveal endpoint, administrator privilege granting publishing or credential accepted at private `/api`.

### PUB-02 — Prepare an introduction and portrait (P1)

- **Start:** Publisher; new/existing introduction draft independent of private Person record.
- **Action:** Save public wording and approved bounded portrait upload; inspect small/large crop previews beside published copy.
- **Result:** Working draft/version and sanitized private WebP renditions only; no automatic publication or consent.
- **Observe:** Difference between working draft and currently published copy unmistakable.
- **Then:** Reload preserves draft; published copy remains until explicit publication/withdrawal; subsequent edits need appropriate consent/review.
- **Failures:** Invalid/oversized/undecodable image, stale version, metadata/original image retention, private member data used as default or Save changing live website content.

### PUB-03 — Consent, publish, feature, and withdraw an introduction (P0)

- **Start:** Publisher, reviewed draft/portrait with deliberate consent evidence; current versions available.
- **Action:** Record exact consent, publish, choose up to three eligible featured introductions, withdraw or revoke consent.
- **Result:** Reviewed published snapshot and append-only events; current consent matches text/portrait; removal cannot be blocked by an intervening publication.
- **Observe:** Published/draft/restriction/feature state clear; no hidden private roster relation.
- **Then:** Feed/detail/current portraits reflect publication; revoked/withdrawn or old portrait access fails; changing draft does not change published snapshot without review.
- **Failures:** Missing/outdated consent, changed portrait/text, stale feature/source, too many/ineligible IDs, concurrent publish/withdraw or stale cached removed content presented past freshness budget.

### PUB-04 — Review a legacy event snapshot (P0)

- **Start:** Publisher while automatic website calendar policy inactive; source CalendarEvent and reviewed source version.
- **Action:** Prepare public copy, review eligibility/reason/title flags, publish; mark internal/withdraw or source restriction/cancellation/delete.
- **Result:** Explicit reviewed snapshot, source-owned schedule/place; restrictions/cancellation sticky; ordinary edits do not publish changed copy.
- **Observe:** Draft versus published source changes visible; eligibility is distinct from Publish.
- **Then:** Feed uses approved snapshot; restricted/deleted source removes access; activation switches event management to live-calendar workflow.
- **Failures:** Unreviewed/internal/private event publication, ambiguous title inferred as eligibility, stale source, restored withdrawn content or legacy editorial writes accepted after activation.

### PUB-05 — Activate and maintain automatic website notices (P0)

- **Start:** Publisher, explicit stored types and candidate Meetings/events; inactive or current policy revision.
- **Action:** Preview actual proposed Shown/Hidden notices; apply unexpired signed review. Thereafter managers edit own source listings using Type default/Show/Hide.
- **Result:** Reviewed one-way activation/update; notices generated live from dedicated schedule/place/title/website description/attendance/cancellation fields.
- **Observe:** Actual preview and current policy, clear source controls; unspecified types have no inferred default.
- **Then:** Source updates immediately affect listed notice; Hide/delete removes collection/detail; cancelled listed event remains cancellation notice; introductions retain separate consent workflow.
- **Failures:** Stale source/policy preview, expired token, title-derived publication, attendance confused with website visibility, private description/documents copied, reverting to legacy snapshots reviving withdrawal. Live activation not checked here.

### PUB-06 — Consume only current approved website output (P0)

- **Start:** Server-side website client with valid Post token; variants anonymous/session/personal/revoked token, conditional ETag and old portrait revision.
- **Action:** GET/HEAD featured/story/portrait/event collection/detail with valid date interval.
- **Result:** Current permitted projection or controlled 400/401/404/405/429/503; no private fields; authentication/state checked before 304.
- **Observe:** Compatible payload/opaque IDs, WebP, private max-age=300/must-revalidate/Vary Authorization, no-store errors.
- **Then:** Withdrawal/revocation/hide changes future reads even with old ETag; consumer never serves expired/unauthorized cached content or exposes credential to browser.
- **Failures:** Wrong interval, missing origin/configuration, unsupported method, provider/feed outage, foreign identity or shared cache leakage. Separate companion rendering/cache delivery needs its own evidence.

## Delegated API and document delivery

Policy/source basis: [roles](../ROLES.md), focused API documents,
[API base](../../app/controllers/api/base_controller.rb),
[handbook](../../app/services/agent_handbook.rb),
[official API actions](../../app/controllers/api/minutes_attestations_controller.rb),
[PDF delivery](../PDF_DOCUMENT_DELIVERY.md).

### API-01 — Discover and read permitted operations (P0)

- **Start:** Enabled member/officer/publisher/admin browser session or active personal token; Post website token as denied variant.
- **Action:** Read Markdown/JSON `/api` handbook; follow permitted read families, pagination and scoped field contracts.
- **Result:** Caller-specific current capabilities/operations and deliberately selected fields, no secret or restricted transcript dump.
- **Observe:** Authentication failure 401, duty denial 403, unavailable record 404; permission-filtered help agrees with actual access.
- **Then:** Ended assignment/manual revocation changes reads and handbook; pagination/truncation handled explicitly; website token never enters private API.
- **Failures:** Handbook advertises unreachable action, foreign IDs, ordinary member denied supposed parity (G-01), full-record serializers, capped result mistaken for complete count.

### API-02 — Persist a delegated write exactly once (P0)

- **Start:** Authorized personal token with explicit scoped human instruction/current versions, or session with valid CSRF token.
- **Action:** Submit mutation; retry identical bearer request with same Idempotency-Key; submit different payload/same key as denied variant.
- **Result:** One scoped durable change and retained execution/provenance; matching completed response replays, conflict/missing-key/stale version fails without unintended second write.
- **Observe:** Correct body/state and 409/422 errors where contracted, not just HTTP success.
- **Then:** Fetch saved record, repeat retry, revoke credential/duty and retry; current authentication/capability gates still apply. In-progress retry cannot invent success.
- **Failures:** CSRF bypass for session, key reuse across different request, duplicate create on timeout, stale overwrite, cross-organization mutation, unauthorized replay or silent data loss.

### API-03 — Execute an explicitly requested delegated minutes act (P0)

- **Start:** Personal bearer owner with exact `approve_minutes`/`attest_minutes` authority and explicit human instruction; current ready record.
- **Action:** POST handoff or attestation with unique idempotency key.
- **Result:** Same lifecycle rules as browser, exact digest/version and token/owner execution provenance; agent never becomes independent approving authority.
- **Observe:** New truthful handoff/attestation state and recorded execution; browser session API request is redirected to human screen through explicit error guidance.
- **Then:** Same request replay does not duplicate act; record/duty change prevents unauthorized new action. No API membership approval, reopening or amendment operation is mapped.
- **Failures:** Administrator implied official power, wrong state/readiness, session call used as confirmation bypass, automatic agent approval or obsolete API documentation claiming these routes are forbidden (G-05).

### PDF-01 — Receive the right private document (P1)

- **Start:** Member with published agenda/member minutes, permitted officer with draft/working/private-notes document, or member with selected calendar view.
- **Action:** Use actual Print PDF action.
- **Result:** Complete inline PDF with saved heading/filename, correct authority and variant; signed short-lived loopback source renders only allowed resources.
- **Observe:** Readable Letter document; calendar landscape overview/portrait detail; pagination/footer consistent; explicit image omission rather than remote fetch.
- **Then:** PDF content matches selected saved/revision/filter state; unauthorized/private-source direct request fails; generation failure returns guidance and original selection.
- **Failures:** Draft called official, member gets cues/transcript/AI evidence, historical heading follows renamed template, partial bytes, Chromium timeout/resource fetch or unsigned/foreign/expired rendering token. Plain HTTP success never proves page content/authority.
