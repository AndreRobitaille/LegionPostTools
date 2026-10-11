# Continuing Post work component assertion review

Bounded #84 source review at b965cf76, October 11, 2026. ENDEAVOR_GOVERNANCE.md and
ENDEAVOR_ACTIVITIES.md keep durable continuing American Legion work separate from
meeting-owned snapshots, append-only officer updates, optional task/deadline and actual
calendar occurrences. Humans complete/reopen the same identity. Tasks do not automatically
create meetings/events. Member agenda references exclude unpublished drafts; derived
history source reads use attested minutes. AI management remains capability-gated,
and derived history is separate from official minutes.

Read six complete files /37 cases and all fixtures/helpers/assertions. Exact names/lines
and blobs pinned in [ENDEAVOR_COMPONENT_SOURCE_CASES.md](ENDEAVOR_COMPONENT_SOURCE_CASES.md).
Recorded b965cf76 actual-main all-four CI38122975568 passes ordinary1297/11980 then
system74/1598, no failures/errors/skips. Source reading is separate from actual execution
and representative faults; no new app/test edit or paid/provider run belongs here.

| Exact file / cases | Starting state, action, saved/visible/subsequent outcome and limits |
| --- | --- |
| `test/controllers/endeavor_tasks_controller_test.rb` /7 | Nonempty member task read with no controls and actual denied new/create/update preserving title/count; manager adds fixed dated/undated steps without CalendarEvents, later optional date remainsnil. Actual completion actor/time survives repeated complete, reopening clears provenance and records updater; invalid date returns retained raw input without save; stale edited task and cross-Endeavor action keep fixed title/completion; overall due date saves fixed September20 through legacy alias, corrected label and invalid later input preserves old date. Dated-create case does not assert each saved date/title/actor, or every refused field; separate model/API/browser components remain. |
| `test/controllers/endeavor_updates_controller_test.rb` /3 | Actual rich officer update count/body/author and later detail redirect; blank update no write/plain alert; member create denied without count change. Route fixtures do not itself prove append-only edit/delete prohibition; model detector remains distinct. |
| `test/controllers/endeavors_controller_test.rb` /9 | Anonymous index/sign-in; nonempty member list/details/continuity without edit/planning jargon; completed record avoids overdue wording. Actual published agenda -> real handoff/attestation changes continuity link to immutable minutes; manager creates rich record with correct creator, ordinary member new/update denial preserves title, foreign meeting body gives recoverable errors, actual edit/complete/reopen preserves identity/actor, stale edit useful conflict. Last stale case asserts alert, not saved title/summary; negative create title does not test every denied transport. Keep these narrower limits alongside actual source and API guards. |
| `test/models/endeavor_test.rb` /4 | Fixed independent30/31-day/standard/nil urgency buckets; same-Post meeting-body validation; saved completion/reopen actor/time and invalid transitions. Unsaved classification/validation differ from current dated permission and routed task/deadline/publication behavior. |
| `test/models/endeavor_update_test.rb` /2 | Blank rich update invalid, actual nonempty append-only update and destroy fail with exact errors, saved original wording survives reload. Ordinary model mutation refusal is separate from official minutes SQL and derived-history immutable edition guards; no raw-SQL/bearer/browser claim here. |
| `test/controllers/endeavor_histories_controller_test.rb` /12 | Member can read current history but cannot manage guidance/AI API; manager saves exact guidance with stale count refusal, Jobs excludes minutes and denied retry, reused work displays separately from paid attempts. Actual draft/published/reopened agenda alternates member HTML/API metadata without starting AI; foreign Post404. Real handoff/attestation with nonempty related paragraph, motion and unrelated item permits only exact requested current unit, excludes other text, rejects foreign/unattested/revision/unit selections. Public page navigation/private controls and actual denied completion keep active state; management overview scoped/filter/no-run; synthetic saved edition/run manifests distinguish current/outdated/failure/processing/withdrawn and preserve publish date. Manifest/config/source builders are coupled internal inputs; arbitrary fixture digest/payload is not proof of provider verification or an actual generated edition. Some refusals assert status/count only; real offline pipeline and SQL/runtime guards remain. |

Retain every assertion and useful component. Priority semantics, lifecycle provenance,
append-only human continuity, actual related immutable-source reading and task/date
contracts have distinct failure conditions. No safe deletion/consolidation or universal
fault proof is established. Existing #88/#95 guard/source/current-token proof is separate
from these source-only fixtures. #79/#93 decisions remain open; no production or paid AI.
