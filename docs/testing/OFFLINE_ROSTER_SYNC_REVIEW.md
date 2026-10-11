# Offline roster source refusal and contact continuation

Design for #109 under #84, source `283911d`, October 11, 2026. Governing
`docs/LOOPS_ROSTER_SYNC.md` requires a reviewed current roster source and upsert payloads
that preserve provider opt-out controls. Existing source returns before opening a client
for superseded input and records rejected contacts while iterating later contacts. No
application defect or live provider behavior is established; missing evidence is actual
client-call absence on refusal and a real later contact after rejection.

Retain every existing audience, fake-HTTP client, sync and admin request assertion. The
single-rejection sync case has one contact, so name it according to the behavior it
actually proves and keep its completed/progress/member/message assertions. Add an open
counter to the offline fake and strengthen stale-source refusal with zero opens/payloads,
unchanged person/requester/source-import identity and no recorded start before the existing
failed/error assertions. This must detect an accidental provider call even if the final
status remains failed.

Add one bounded two-contact case ordered by independent synthetic names/IDs. Reject the
first through the existing fake, allow the second, and inspect both actual payloads with
fixed expected member identities and name/email fields. Verify current saved source/
requester identity, one synced/one failed, exact first failure provenance, terminal timestamps
and the intervening sleeper call. Never infer continuation from a completed status or a
single rejected contact. Provider opt-out keys must remain omitted; no external credentials
or network calls.

Faults are offline and narrowly reversible: before start!, dispatch one actual audience
payload through the supplied fake, retaining original final stale status; new call-absence
assertions must fail. Separately break after the first RequestError, retaining original
single-contact results; the two-contact test must fail on the missing later payload.
Restore exact service bytes in finally after each, then prove clean focused audience/client/
sync/admin behavior. Existing component scopes stay separate; no test deletion/consolidation,
provider implementation/lifecycle/policy change or dependency upgrade.

Before commit: focused clean/fault evidence, restored source, lint and full intended diff
review. Before merge: final committed ordinary/full system suites serially, applicable
security, real existing administrative preview/results browser evidence where practical,
exact-SHA and actual-main CI. This is request/service execution with offline HTTP seams,
not actual Solid Queue dispatch or provider opt-out verification. Synthetic disposable test
records only; no production, member-data copy, paid AI or deployment.


For rendered evidence, add a separate real magic-link browser journey over a completed
partial run produced by the actual synchronizer with an offline supplied client. Inspect
fixed source/failure identity and independently expected summary values at1400/390px,
follow the ordinary review-another-sync navigation and its latest-result link, then
remove the current settings grant and prove the result is denied. The 1919 paper/navy
panels and readable existing failure text remain unchanged. This is actual saved service
output plus HTML navigation, not job dispatch, an external provider or browser submission
of the sync operation. No real key is supplied and no sync button is clicked.


## Focused and restored fault evidence

On integrated877c18e, combined sync/audience/client/admin/email/User focus54 /260 /0
(seed9071,1.81s) passes. Initial isolated Loops focus19 /100 /0 (seed56919,2.51s).
Stale-source client-call fault fails1 /1 /1 at the zero-open assertion despite retaining
its final failed status (seed21710,.54s). Break after first rejection fails1 /1 /1 on
the independently expected missing second payload (seed46517,.57s). Each finally restores
service SHA256 `c339c849811b2e085df5f1685d6c4d0674b4e47db8a6a5125b0c86394254365b`.
No real provider request, credential or experimental application edit remains.

New actual saved partial-result plus email-review browser pair passes2 /98 /0
(seed32111,9.63s). Desktop and390px partial-summary plus email-refusal screenshots were
inspected: existing clear source/error hierarchy, legible text and wrapping, no horizontal
overflow. Narrow failure-detail scroll capture and final saved-state reread are a later
refinement requiring fresh focused execution; full committed checks/CI remain pending.
No actual Loops opt-out preservation or Solid Queue execution is inferred from the prose.

## Whole retained component scopes

| Exact file | Reviewed distinct assertions and limits |
| --- | --- |
| `test/services/loops/roster_audience_test.rb` (3) | Active/Grace present selection versus expired/removed/local, blank/invalid/case-shared exclusion counts, stable National ID/name split/fixed email and omitted subscription/group/list keys. Retained unchanged; provider opt-out state is external. |
| `test/services/loops/client_test.rb` (3) | Actual client-generated authenticated JSON PUT against supplied fake HTTP, Retry-After pacing/two requests, exact rejected message/status. Retained unchanged; no actual TLS/server/network delivery proof. |
| `test/services/loops/roster_synchronizer_test.rb` (6) | Old success/single-rejection/stale/terminal-network/missing-job-configuration assertions remain; strengthened source zero-client/unchanged graph and new later real payload after rejection. Fake sleeper avoids waiting while independently checking positive inter-contact interval. |
| `test/controllers/admin/loops_roster_syncs_controller_test.rb` (7) | Member preview denial, actual selected count and opt-out explanation/form,31-day warning, saved/enqueued source/requester, missing-key refusal, existing-active/no enqueue, partial-result rendering. Retained unchanged; queued execution and exact30-day staleness boundary are not established here. |
| `test/system/loops_roster_syncs_test.rb` (new1) | Actual offline synchronizer output, real magic-link sign-in,1400/390 result/preview/later-result reading, unchanged source identity and actual settings-grant removal denial with continued own Profile access. No sync-button submission/live dispatch. |

`LoopsRosterSync` validations/active/recent state and `LoopsRosterSyncJob` delegation were
read. No dedicated model/job test file was located, and the one-active schema constraint
is source evidence only here. No test removal/consolidation is justified.


Fresh main55e091f integration: complete focus54 /260 /0 (seed55531,1.81s), then
real browser pair2 /105 /0 (seed15602,9.63s), all restored. Final narrow partial-failure
detail and remind-refusal captures inspected; clear wrapping/source identity and usable
follow-up controls without overflow. Focused Ruby lint5 files and diff checks pass.
All final committed full suites/security/exact candidate/main CI remain subsequent gates.
