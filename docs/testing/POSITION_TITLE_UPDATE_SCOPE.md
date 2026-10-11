# Configured Post position update boundary

Design/investigation for #107 under #84/#78, source `b852211`, October 10, 2026.
Current architecture leaves future Legion Family organization configuration open; it
does not authorize new multi-tenant policy. Existing position index/create/reorder use
the installation's configured first Organization, and reorder model/request tests
explicitly reject foreign identities. Assignment creation also restricts title lookup
to that Organization. HTML title update instead uses an unscoped ID lookup.

Reproduce the apparent inconsistency with an administrator already authorized to manage
settings, an in-scope title and a separate synthetic Post's title, dated assignment and
capability rows. Submit the real title-update route with name, active and membership
access edits. Compare all foreign and own saved attributes before asserting 404; later
index must exclude foreign titles, and an ordinary legitimate own-title update must
still save. Keep all existing own create/active/membership/order assertions. This is
the same configured-Post scope as the existing adjacent operations, not an assumption
that every future affiliated unit is forbidden forever.

Only after reproduction, replace global lookup with the configured Organization's
position-title association. Use ordinary Rails RecordNotFound handling; no new endpoint,
role grant, UI/layout or new error design. The existing readable position administration
screen and forms remain. Preserve foreign authority/assignment rows; a successful redirect
must not conceal their mutation. Record original failure and restored clean results.

Before committing, focused controller/model/assignment/officer checks, diff review and
lint are required. Any merge needs final committed full ordinary/system suites serially,
security, neighboring browser evidence, fresh challenge of scope assumptions and exact-
SHA/actual-main CI. Source evidence is not a live production claim. Synthetic test records
only; no production operations, member-data copies or paid AI.


## Original and corrected request evidence

On original unscoped source `b852211`, the new request fails on actual saved foreign
name/active/membership-access mutation before 404: 1 / 1 / one failure (seed22537,
2.08s). Original capability and dated assignment remain; the unauthorized title edits
are the reproduced defect. Scope update lookup to `Organization.first!.position_titles`,
matching adjacent configured-Post operations. Corrected controller cases pass 8 / 53 / 0
(seed10714, 1.11s), including later legitimate configured-title save. No other role or
organization policy changes.

Integrate #106 main `8a603bb`. Add one real browser journey at 1400/390px: submit a
foreign identity through an existing title form/control, verify visible ordinary 404
and unchanged authority/assignment graph, then revisit and use the legitimate deactivate,
activate, grant/remove membership controls. Inspect restored-screen captures and overflow.
The visual direction preserves the existing 1919 positions screen and standard error
page; no UI markup/style change is proposed. Browser/final checks are pending.


Initial browser assumptions are recorded rather than changing application behavior to
fit them. A tampered Turbo form returned a real 404 (test request log) while retaining
the existing positions page: 1 / 3 / one failure on the assumed static-page text.
The native variant then exposed Rails' configured detailed test exception page, also
1 / 3 / one failure. For the public-page boundary, only this system test disables
exception details and restores the original env_config value in teardown; the existing
:rescuable exception policy remains. Only the foreign tampered form uses native submission;
all subsequent legitimate controls use their existing Turbo behavior.

Corrected public-error/native refusal and legitimate recovery journey: 1 / 31 / 0
(seed51262, 4.54s), with foreign capability/assignment/title and configured title unchanged
at refusal, then real own deactivate/activate/grant/remove saves. Restored positions
screens inspected at 1400/390px: readable controls and no horizontal overflow. This is
not a claim of a new Turbo inline error message or actual production rendering.


## Neighboring officer and account source review

Whole files/assertions below were read at `b852211` and are unchanged through integrated
main `66e8c8a`, except the strengthened title request. Governing roles and user-management
policy separates a current Post duty, membership information, manual app grants and
technical account administration. All table paths are relative to `test/`. All cases stay; no redundancy is demonstrated.

| File | Retained distinction and limit |
| --- | --- |
| `controllers/admin/position_titles_controller_test.rb` (8 now) | Index and settings denial, ignored create order, saved active/membership flags, saved reorder and foreign reorder refusal; new foreign update graph/404/later legitimate name save. Current configured first Organization matches adjacent operations; no future multi-tenant policy. |
| `models/position_title_test.rb` (3) | Actual 1-based saved reordering, foreign IDs with unchanged original orders, and duplicate-ID refusal. These model variants remain beside request routing; duplicate refusal alone does not assert a full saved graph. |
| `controllers/admin/position_assignments_controller_test.rb` (8) | Saved dated creation/end/formatted dates, foreign nested person, invalid-date preservation, inactive/foreign title creation refusal. Historical assignments stay rather than overwrite a term. |
| `models/position_assignment_test.rb` (3) | Independent no-end-date, after-end and reversed-date cases. Inclusive end-date authority is separately asserted in User/#78; this file alone does not prove that boundary. |
| `models/position_capability_grant_test.rb` (2) | Explicit allowed minutes duty, denied technical manage_settings capability and no duplicate capability per title; retain beside effective-permission tests. |
| `controllers/admin/administrators_controller_test.rb` (2) | Enabled manual settings administrators and plain-member denial. Technical helpers may administer without holding Commander/Adjutant office. |
| `controllers/admin/user_accounts_controller_test.rb` (12) | Actual account identity/email/default roster access/re-enable/override disable and last-admin preservation; distinct roster/unsupported/no-account/blank-email paths. Authority fixture is technical settings, not every configured officer. |
| `controllers/api/user_accounts_api_test.rb` (4) | Actual enable/disable/roster-control and current manual/position/effective JSON fields, last-admin refusal and member denial. API projections remain beside HTML controls; not a universal HTTP status proof. |
| `controllers/admin/permission_grants_controller_test.rb` (5) | Exact saved replacement/invalid capability filtering, last-admin preserve/other-admin removal, current role duties excluded from manual copies. Serial last-admin cases do not establish simultaneous-request safety. |
| `models/permission_grant_test.rb` (2) | Explicit granted/missing capability and complete unique grouping; grouping is a component inventory, not independent privilege policy. |

Date choice remains #93. No separate officer-label or account policy change is implied.
The remaining source-only review boundaries are not converted into runtime/production
claims by executing neighboring tests.


Integrated-main neighboring controller/model/current-duty checks:
87 / 626 / 0 (seed9012, 4.71s). Three changed Ruby files lint clean and diff checks pass.
All original assertions remain. Final committed serial ordinary/system suites, security,
fresh review and exact-SHA/actual-main CI still gate merge; no production claim.
