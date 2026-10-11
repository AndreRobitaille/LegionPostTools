# Template and dated-agenda component assertion review

Bounded #84 review at b965cf76, October 11, 2026. Governing Commander agenda/roll-call
policy preserves independent catalog -> template -> dated agenda -> minutes copies,
separates member wording/private cues and permits deliberate roll-call changes only
while an agenda is a draft. Roll call uses the meeting date, not today's officer list.
Current calendar policy uses the Post timezone for entry/display; the historical
UTC-wall migration has a separate reversible representation contract and is not a
new policy decision or permission to run production data changes.

Read six complete files /39 cases, fixtures/helpers/assertions. Exact names/lines and
blobs are pinned in [DATED_AGENDA_COMPONENT_SOURCE_CASES.md](DATED_AGENDA_COMPONENT_SOURCE_CASES.md).
Recorded b965cf76 actual-main all-four CI38122975568 passes ordinary1297/11980 then
system74/1598 without failures/errors/skips. Source reading is separate from execution
and fault proof. No test/app edits or new execution belong to this source-only review.

| Exact file / cases | Starting state, action, outcome and limits |
| --- | --- |
| `test/controllers/admin/meeting_type_agenda_items_controller_test.rb` /19 | Picker grant/active selection; real rich catalog copy and append; duplicate validation versus other invalid/SQL-constraint message classification with ensure-restored injected methods; saved local rich/private/document-flag updates preserve catalog title; seeded and local item removal remain distinct provenance fixtures. Real draft/approved/published dated copies keep every saved attribute and rich/public/private body except intentional nullified source FK/lock increment, and later agenda excludes removed item. Actual order/section move, Lexxy officer-facing fields, foreign/inactive refusal, existing inactive-source copy and drag/trash controls. Complete catalog body preservation and all foreign mutation graphs are not asserted by every narrower case; statuses are enumerated from the app constant, not a separate policy list. |
| `test/controllers/admin/meeting_type_agenda_sections_controller_test.rb` /6 | Grant refusal; actual nonempty section creation/next position/rename; recoverable blank-title form; foreign reorder refusal keeps one own position; move exact saved order/notice; nonempty and sole-section removal produce distinct alerts, later empty section count drops. Refusal alert assertions alone do not compare every saved row; meaningful model/dated-snapshot components remain independent. |
| `test/models/dated_agenda_section_test.rb` /4 | Fixed default title, foreign-template provenance invalid, actual approved agenda denies section creation/update/destruction, exact saved reorder. Unsaved validation and error detectors differ from routed/SQL protections; refusal cases do not independently snapshot every rich child row. |
| `test/models/dated_agenda_roll_call_entry_test.rb` /5 | Nonempty required/assigned/optional offices and exact fixed meeting-date snapshot; a later-starting Adjutant remains vacant; actual person/title rename cannot rewrite old saved names; deliberate draft refresh includes new assigned person; real approved agenda refresh raises and reports draft requirement. Configured dates are independent of today's authority; this does not resolve #93 or prove every DST/assignment-boundary variant. |
| `test/services/minutes_agenda_wording_backfill_test.rb` /3 | Actual draft source copy with destroyed legacy agenda-body field; exact nested legacy snapshot separates from two fixed human paragraphs, agenda-only copy leaves narrative blank, human-edited nonexact wording raises and preserves saved content. Source service inspection limits eligibility to drafts with provenance and preserves already separated copies. Cases do not directly test multiple-record transaction rollback, each eligibility exclusion or immutable official records; no production backfill was run. |
| `test/migrations/reinterpret_legacy_dated_agenda_times_test.rb` /2 | Actual synthetic published July Chicago agenda with fixed UTC components/update metadata/lock7; migration up produces independently fixed18:30CDT/23:30UTC and preserves status/time/version, down restores original UTC-wall components/time/version. Actual implementation uses per-Post zone and preserves fractional seconds. Tests do not independently exercise multiple Posts, invalid zones, DST transitions, fractional seconds or every saved field; no current deployment/data claim follows. |

Keep seeded/local removal, three specific error classifiers, historical snapshot, model
lock, roll-call date/refresh and backfill/migration components: their failure conditions
are distinct. No safe deletion/consolidation is demonstrated, and no source discrepancy
is promoted to a runtime incident. Existing historical/official-record regression evidence
remains separate in the workflow matrix. #79/#93 policy decisions remain open.
