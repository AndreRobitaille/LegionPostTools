# Buddy Checks production connection handoff

> Release procedure update (November 1, 2026): commands below describe the dated
> handoff/release. For any new release use the [current deployment playbook](DEPLOYMENT.md):
> successful isolated image build, explicitly authorized publication, and a verified
> digest inside one owned `bin/release session`. The old push-deploy/keep-master
> commands are superseded. Activation still requires its own explicit authority.


Deployed and activated October 12, 2026. **The backend is ready for the mobile agent
to configure the iPhone and sign in as `commander@wipost165.org`.** Real email/code
sign-in returned to the production consent screen. Andre must approve that consent
in the phone app; native installation and final device verification remain Apple work.

## Confirmed connection settings

| Setting | Production value |
| --- | --- |
| HTTPS origin / exact issuer | `https://members.wipost165.org` |
| Public OAuth client ID / bundle ID | `org.wipost165.buddychecks` |
| Exact callback | `org.wipost165.buddychecks:/oauth/callback` |
| Scope | `buddy_check` |
| Client / flow | Public, no secret; authorization code with S256 PKCE and explicit human consent |
| Access / refresh | 900 seconds; `capabilities.refresh=false`; no refresh token |
| Installation | ID `1`, Robert E. Burns Post 165 |
| Time zone | `America/Chicago` |
| First human | Account ID `2`, `commander@wipost165.org` |
| Contacts company | `American Legion Post 165` |
| Deployed revision | `54eb03d7f963ac1ec4a250ebbe390303dda77d70` |

Normal certificate validation passes. No temporary certificate, LAN test server or
Mac SSH tunnel is involved. Configure the existing Swift app with this origin and
public client ID; reauthorize for this installation and keep synthetic records separate.

**Apple contract differences:** no route, JSON schema, token lifetime or refresh
change is required. The existing 403 `account_unavailable` authority error also
applies when pilot access is removed. `contacts_export` now reflects the current
human's explicit grant. The configured pilot account has both grants. See the
[complete API contract](MOBILE_BUDDY_CHECK_API_HANDOFF.md).

## Pilot and website access

Only account ID `2` has `use_mobile_buddy_checks`. No office-level pilot grant exists.
OAuth consent, code exchange, every mobile request and the phone-related website
controls require that current capability. Commander status, other offices and
administration do not imply it. The existing role system can deliberately delegate
it later; dated role authority expires with the assignment.

Other users see no Mobile sessions, general-member attendance or address-review
links, and direct URLs are denied. Evidence editing additionally requires current
full membership access. Existing membership drives, imports, renewal and financial
workflows retain their existing permissions.

`export_buddy_contacts` was granted only to the pilot account. Assignment access
alone does not authorize export. Current membership authority additionally controls
reviewed address fields. Export includes only permitted structured components with
current source provenance; unreviewed/stale addresses remain unknown. Real attendance
and mailing sources still require an officer's review; activation guesses neither.

Staff controls: Membership → General-member attendance; Membership → a person →
Review mailing address; Your profile → Mobile sessions; and People → Login Account
→ Permissions → Buddy Checks. The two grants can be removed independently.

## Feature verification

| Feature | Verified evidence |
| --- | --- |
| Authentication | Synthetic S256/code replay/expiry/CSRF/origin tests and real browser consent submission pass. Production email arrived; its code signed in and returned to consent with 200, `strict-origin`, `no-store` and a CSRF token. Consent was left unsubmitted. |
| Session and authority | Stable identities/time zone confirmed by production probe. Synthetic checks distinguish expiry, revocation, disabled accounts and removed pilot authority; current dated grants apply to existing credentials. |
| People and privacy | Synthetic bounded search, fresh cards, assignments, hidden-recipient denial and separation from other callers' notes/renewal/financial fields pass. |
| Suggestions | Synthetic exclusions, unknown history, explicit complete attendance and revised/incomplete attendance pass. Reads create no check, assignment or reminder. No history was backfilled in production. |
| Checks, corrections and receipts | Synthetic exact/lost-response retries, changed-payload conflicts, immutable originals, stable logical IDs, later history/revisions and database rollback checks pass. |
| Follow-ups and snoozes | Synthetic linked/independent creation, reschedule, completion/cancellation, stale-revision denial, receipt recovery, closed-status pagination and snooze recovery pass without inventing a conversation. |
| Contacts export | Synthetic current-grant enforcement, assignment-only denial, field tiers and changed/restored source invalidation pass. Production company, grant and existing reviewed-address authority confirmed. |
| Website and database | Desktop/390px rendered controls and nonpilot hiding/denial pass. Three production migrations applied; all 12 protected-table counts/fingerprints remained unchanged. |

Final full ordinary suite on current GitHub master plus the pilot patch:
**1,425 tests, 14,096 assertions, zero failures/errors/skips**. Focused mobile/pilot
checks: **42 tests, 362 assertions**, all passing. Final full browser suite after
the timing correction: **93 tests, 5,387 assertions, zero failures/errors/skips**.
This includes consent, code sign-in, pilot visibility, permissions, attendance and
address review. Screenshots were inspected at desktop and 390px; readable controls
and no horizontal overflow.

The export regression first failed against the old implementation (ungranted
export returned 200), then passed with current-grant enforcement. A separate real
PostgreSQL writer race returned identical receipts with one contact/operation;
changed-payload reuse conflicted without mutation. Activation and readiness CLI
checks passed on a separate synthetic database without creating contacts or tokens.

RuboCop: **603 files, no offenses**. Brakeman: **zero errors/warnings**. Bundler audit:
**no vulnerabilities**, advisory revision `a6847b0651a702488f5844081e848dd1ec9dbf1d`.
Zeitwerk, shell syntax, JSON examples, document references and diff checks passed.
Tests and fault checks used synthetic data; no real outreach was fabricated.

The initial release CI browser job exposed a timing race in the second attendance
save assertion: its identical previous success notice remained visible before the
new write completed. An isolated 500ms pre-write delay reproduced that failure and
the same premature assertion after export-grant removal. The tests now wait for
the server-rendered attendance revision and permission checkbox attribute, then
retain their database counts, effective state and subsequent API denial assertions.
Both delayed cases passed: **2 tests, 35 assertions**. The delays were removed and
are not repository or production behavior. This follow-up changes tests only;
the deployed application revision remains `54eb03d`.

[GitHub CI for `46080f6`](https://github.com/AndreRobitaille/LegionPostTools/actions/runs/38284968113)
passed all jobs: ordinary tests, full browser workflows, lint, Ruby security/dependency
scans and JavaScript dependency audit. Application code matches deployed `54eb03d`;
the later commits contain this handoff and the browser-test wait correction.

## Release evidence

`BUDDY_CHECK_ACTIVATE_EMAIL=commander@wipost165.org bin/release push-deploy`
pushed/verified the exact revision, deployed it, registered the client and granted
only that account pilot/export access. Preflight, activation and read-only probes
shared one persistent SSH connection, closed by the wrapper at completion.
A clean release copy preserved the unrelated local handoff file.

Applied migrations:

- `20261011210000_add_mobile_buddy_checks`
- `20261011211000_preserve_buddy_evidence`
- `20261012120000_add_buddy_contact_export_permission`

Enabled settings: `MOBILE_BUDDY_CHECK_ENABLED=true`,
`MOBILE_CONTACT_EXPORT_ENABLED=true`, and the exact issuer/client/callback/company
above. Existing `MAIL_PROVIDER=loops` and its configured credentials/template remain
in use. No user, roster, renewal or official-record access was broadened.

The server-computed before/after counts and fingerprints matched for all twelve
roster/import, membership/financial and official-minutes tables. The 124 people,
five imports and existing minutes/revisions/attestations/approval were preserved.
No production member rows were copied out.

Live HTTP checks: Post health and sign-in 200; co-hosted application 200; anonymous
mobile session 401 `invalid_session`; token without a grant 400 `invalid_grant`;
revocation of an unissued token 200 `{}`. All mobile/token/revocation probes passed
TLS validation with **zero redirects**. Successful token exchange is verified by
synthetic integration tests; the first native production exchange follows Andre's
explicit phone consent.

The temporary verification browser signed out and closed. Mobile sessions showed
no active bearer session; no phone consent or mobile record was created by the check.
No backend blocker remains. Native sign-in, Contacts writes and notifications still
need the mobile agent's final iPhone verification.
