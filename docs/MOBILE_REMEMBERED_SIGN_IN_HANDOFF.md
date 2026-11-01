# Remembered Buddy Checks sign-in: synthetic handoff

> Release procedure update (November 1, 2026): commands below describe the dated
> handoff/release. For any new release use the [current deployment playbook](DEPLOYMENT.md):
> successful isolated image build, explicitly authorized publication, and a verified
> digest inside one owned `bin/release session`. The old push-deploy/keep-master
> commands are superseded. Activation still requires its own explicit authority.


Prepared October 12, 2026. Backend implementation and isolated synthetic service
are available. This authentication change has not been committed, pushed, or
deployed. Production remains `66bb8150bb465c4a4926b5c303effc652d177730`, containing
the accepted random-choice feature. The native acceptance checkpoints and final
backend reconciliation below are complete. Andre authorized this scoped commit,
push and deployment, including the additive migration, on October 12, 2026.
This document records the verified implementation and authorized release scope;
deployment completion will be reported with the exact running revision.

## Public setup

| Setting | Value |
| --- | --- |
| Exact issuer | `https://192.168.37.41:3446` |
| Public client ID | `NXw9CxdTxKedbhp8acc1IlL1RexPu2Wm2bQCboQZFkU` |
| Exact callback | `org.wipost165.buddychecks:/oauth/callback` |
| Scope / authentication | `buddy_check`; public client, no shared secret; S256 |
| Remembered opt-in | `remember_session=180_days` in authorization URL |
| Synthetic installation | Synthetic Remembered Sign-in American Legion Post, ID `1` |
| Caller | Jamie Caller, `jamie@example.test`, user/person ID `1` |
| Draft recipient | Harper Draft, person ID `3` |
| Other recipients | Avery Neighbor `4`, Cameron Companion `5` |
| Steward | Pat Steward, user/person ID `2`; backend controls only |
| Database | `legion_buddy_remembered_test` |
| Checkout | `/tmp/legion-mobile-remembered-sessions` |
| Branch / parent | `codex/mobile-remembered-sessions` / `66bb8150bb465c4a4926b5c303effc652d177730` |
| Private synthetic inbox | `/tmp/legion-buddy-remembered/mail/1.json` |

This is a separate installation identity. Never reuse a credential/draft from
ports 3443, 3444, 3445 or production. Fixture creation left zero contacts,
operations, access tokens, or remembered families. The caller has pilot and
Contacts-export grants, but no membership-manager authority. Recipients have
synthetic phone/email data; no reviewed postal address is claimed.

TLS reuses the explicitly approved authority-test certificate and CA. Normal
hostname and certificate validation applies; there is no ATS exception or bypass.
The CA/server certificate expires October 19, 2026 at 11:42:30 UTC. Fingerprint:

```text
49:20:25:9F:8B:67:B8:E3:7A:EC:51:34:45:52:40:24:45:41:0C:58:37:44:76:7B:5F:E9:F5:E3:04:29:EC:97
```

Public CA files remain at:

```text
/home/andre/Development/LegionPostTools/tmp/buddy-authority-public/buddy-authority-test-ca.pem
/home/andre/Development/LegionPostTools/tmp/buddy-authority-public/buddy-authority-test-ca.cer
```

Trust only under the approved disposable-simulator scope and remove that trust
after the pass. No change to the Mac or physical-phone trust stores is needed.
Do not transfer the private environment, TLS key, credentials or session cookies
into shared documents. Read Jamie's newly generated email code from the private
inbox after the real browser requests it. No real email is sent.

## Token and authority contract

The complete contract is [Remembered Buddy Checks sign-in](MOBILE_REMEMBERED_SIGN_IN.md).
The agreed contract is unchanged: 900-second access, absolute 15,552,000-second
remembered lifetime from consent, rotated refresh credentials, persisted UUID
`exchange_id` for every initial/refresh request, fixed 120-second identical-request
recovery, and live account/pilot/export checks. Legacy callers remain nonrenewable.
The consent button is **Connect and remember this sign-in**.

Recovery returns the same `created_at`, `expires_at`, access and refresh credentials
but a reduced remaining `expires_in`. Never calculate a later expiry from this
response. Recovery ends once the successor was itself renewed. A correctly bound
initial-code replay outside recovery revokes the family (`revoked_session`);
an invalid code/PKCE binding cannot revoke it. Refresh reuse outside recovery
returns `refresh_reuse_detected` and revokes the whole family.

The resource API keeps nested `error.code`; OAuth keeps string `error` plus
`error_code`. Ordinary access expiry, network failure and uncertain delivery keep
encrypted drafts. Confirmed account removal/revocation uses the existing purge
policy. Re-enabling website access never revives old families or pending codes.
Fresh explicit human sign-in is required.

## Controlled native checkpoints

The Mac session owns native execution. Use the real ephemeral authentication
browser and the normal code/consent flow. Recommended sequence:

1. Sign in as Jamie with the opt-in, verify connected Post home and stable family
   identity, then create an unsent encrypted draft for Harper.
2. Ask the backend to expire only Jamie's access tokens. Fetch again; the app
   should renew, retain the same remembered deadline and draft, and remain signed
   in. Optionally discard one committed renewal response and restart within its
   fixed recovery window using the persisted identical exchange.
3. Once renewed access is unexpired, ask the backend to disable Jamie through the
   website account-access method. The next API use/renewal must deny access and
   apply the native confirmed-removal purge policy.
4. Ask the backend to re-enable Jamie. Old credentials remain revoked. Complete
   fresh human consent, then verify app sign-out revokes the whole new family.
5. Record native evidence and final database counts; preserve any accepted records
   and append checkpoints. Never reseed this fixture to repeat a run.

Backend-only controls (no test HTTP route or privileged app credential):

```sh
cd /tmp/legion-mobile-remembered-sessions
ruby test/manual/buddy_remembered.rb status
ruby test/manual/buddy_remembered.rb advance expire_access 'Native checkpoint description'
ruby test/manual/buddy_remembered.rb advance disable 'Native checkpoint description'
ruby test/manual/buddy_remembered.rb advance reenable 'Native checkpoint description'
```

Run transitions only when the native session requests the named checkpoint.
`disable`/`reenable` call `User#set_login_access_override!`; disable therefore
exercises the real account callback and family/pending-code revocation. The
`expire_access` test control backdates only the synthetic caller's access-token
timestamps; it does not alter the fixed remembered deadline or issue credentials.
Changes append before/after metadata to private `checkpoints.jsonl`.

## Running service and verification

Detached Puma listens on `0.0.0.0:3446`, originally started as PID `1070913`.
Verify the current listener and `/tmp/legion-buddy-remembered/server.pid` before
operating it. Owner-only environment, fixture, mail, PID and server log are in
`/tmp/legion-buddy-remembered`. No boot service was installed.

Health and anonymous-session checks passed with the approved CA: `/up` HTTP 200;
`/api/mobile/v1/session` HTTP 401 / `invalid_session`, `Cache-Control: no-store`;
both TLS verification result `0`.

Restart with the existing database and registration, without running setup:

```sh
cd /tmp/legion-mobile-remembered-sessions
ruby test/manual/buddy_remembered.rb server
```

Ports 3443/3444 and their consumed databases, the stopped port-3445 rehearsal,
ordinary port 3000, and production data remain unchanged. Do not drop/reseed any
of them. Disposal of this new database also requires explicit cleanup authority.

Backend focused regressions: **45 tests, 523 assertions, zero failures/errors/skips**,
seed `62694`. These include independent PostgreSQL connections proving concurrent
retry serialization, competing-request replay revocation and renewal waiting on
website disable. The initial new behavior test failed against the baseline because
remembered consent issued no renewal credential (1 test, 3 assertions, seed `47086`),
then passed with this implementation. Real Chromium consent and website revocation passed at desktop
and phone widths: **6 tests, 97 assertions**, zero failures/errors/skips, seed
`64160`. The website revocation uses a separate human browser session; Chromium
cannot hand the custom callback to an installed native app. This does not claim
native callback evidence. Screenshots were reviewed at 1400 and 390 pixels.
The full ordinary suite passed with **1,455 tests, 14,464 assertions**, zero
failures/errors/skips, seed `57311`. The separately run full browser suite passed
with **94 tests, 5,412 assertions**, zero failures/errors/skips, seed `50573`.
RuboCop checked 616 files with no offenses; Brakeman 8.1.0 reports zero errors
and security warnings.

### Native checkpoint: initial remembered sign-in

The Mac session reports `RememberedLiveSignIn03.xcresult` passed: real email/code,
the remembered consent button, PKCE exchange, connected Post home and process
restart using native Keychain. Its first two attempts were harness selector
failures before requesting a code. These are reported Mac results, not Xcode
execution on Linux.

Backend read-only status independently confirmed one active family, one access
token, one refresh credential and one exchange, with zero contacts and operations.
Consent was October 12, 2026 at 19:07:08 UTC; the fixed deadline is April 10, 2027
at 19:07:08 UTC. No expiry or account-disable transition had run at this checkpoint.
The native draft, renewal/recovery and authority-removal checkpoints follow below.

### Native checkpoint: encrypted draft and controlled access expiry

The Mac session reports `RememberedLiveDraft01.xcresult` passed: Harper's unsent
synthetic note was saved without an outcome, the app terminated, and the encrypted
journal SHA-256 was captured before renewal. No server record write was submitted.

At its explicit checkpoint request, the backend ran the guarded `expire_access`
action. Only Jamie's access-token timestamp changed: token `1` now has creation
time October 12, 2026 at 18:54:42 UTC and its unchanged 900-second lifetime, making
it expired. Jamie remains enabled; family `1` remains unrevoked with its original
April 10, 2027 at 19:07:08 UTC deadline. Counts remain one refresh credential,
one exchange, zero contacts and zero operations. The private checkpoint journal
retains before/after metadata. No disable/re-enable action ran. The native
lost-response renewal/restart recovery pass follows below.

### Native checkpoint: accepted renewal response lost, then recovered

The Mac session reports it discarded one real accepted renewal response, observed
the connection failure, restarted within approximately nine seconds, and restored
connected Home plus the exact unsent Harper note without new consent. Its encrypted
journal SHA-256 remained unchanged. The test subsequently failed on a harness
label mismatch (`I didn’t call` versus connected `No contact attempted`); the
corrected read-only draft assertions were pending at that checkpoint. The passing
follow-up readback is recorded below; the original run is not counted as a fully
passing native test.

Backend read-only inspection confirmed exactly two exchanges: the initial code
exchange and one renewal. The renewal's exchange ID is
`b9e0952b-c2bc-4fc2-a269-ad1500239647`, producing access token ID `2` and refresh
credential ID `2`. There are two refresh credentials total, exactly one consumed
and one current, and no extra rotation. The recovery deadline remains the original
October 12 at 19:13:17 UTC. Individual recovery requests do not create new exchange
rows; the native observation supplies the restart/recovery evidence.

Family `1` remains active with its original April 10, 2027 at 19:07:08 UTC deadline,
exactly 180 elapsed days after consent. Jamie remains enabled, and contacts and
operations remain zero. No disable/re-enable action was performed.

### Native checkpoint: corrected draft readback and website disable

The Mac session reports `RememberedLiveRenewalReadback01.xcresult` passed: the
exact Harper note remained, all five connected outcomes were present and
unselected, Save to Post was disabled, and no sign-in/consent appeared. The app
then terminated. This supplies the corrected readback evidence following the
earlier response-loss recovery observation.

On the next explicit checkpoint request, a backend read confirmed access token
`2` was both unexpired and unrevoked. The guarded `disable` action then disabled
Jamie's website access at October 12, 2026, 19:13:07 UTC. Family `1` was revoked
with reason `account_unavailable`, and both access tokens `1` and `2` were revoked.
The original remembered deadline remains unchanged. There are still two refresh
credential rows and two exchanges; contacts and operations remain zero.
At this checkpoint Jamie had not been re-enabled. The next native checkpoint
checked immediate access denial and the confirmed-removal purge policy.

### Native checkpoint: access ended, purge, then re-enable

The Mac session reports `RememberedLiveAccessEnded01.xcresult` passed. The next
launch showed Access ended with no connected work or draft, restart remained
signed out, and a separate app-container check found zero encrypted `.sealed`
journal files after purge.

At its explicit next checkpoint, the backend ran only `reenable`. Jamie is enabled
again, but family `1` and access tokens `1`/`2` retain their original 19:13:07 UTC
revocation. There are still two refresh credentials, two exchanges, zero contacts
and zero operations. The next native pass must establish a fresh family through
human consent and verify app sign-out revokes that whole new family.

### Final native checkpoint: fresh consent and explicit sign-out

The Mac session reports `RememberedLiveSignIn04.xcresult` passed after re-enable:
fresh email/code, remembered consent, connected Home and Keychain-backed restart.
`RememberedLiveSignOut01.xcresult` then passed: explicit sign-out confirmation,
Signed out, no remaining Sign out control, and restart staying signed out. The
production-preset mobile Release build and signature also passed on the Mac; this
does not claim that build has been installed on Andre's phone or that auth is live
in production. The Mac session reports it removed only its owned disposable
simulator and CA, preserving the original workflow simulator. The backend
database/process and evidence are preserved.

Final backend read-only reconciliation:

| Record | Final state |
| --- | --- |
| Jamie | Enabled after the requested restoration |
| Original family `1` | Revoked `account_unavailable` at `2026-10-12T19:13:07Z`; original deadline retained |
| New family `2` | Fresh consent `2026-10-12T19:15:52Z`; fixed deadline `2027-04-10T19:15:52Z`; revoked `user_revoked` at `2026-10-12T19:16:28Z` |
| Access credentials | Three total, all three revoked |
| Refresh credentials | Three retained digest rows; zero belonging to an unrevoked family |
| Exchanges | Three total: two initial exchanges and one renewal |
| Cached credential responses | Zero remaining ciphertext responses |
| Buddy Check contacts / operations | Zero / zero |

The refresh rows remain for replay detection; revocation is enforced through their
family. They are not usable renewal credentials. The fixture was never reset, and
the recovery observation produced no extra rotation or Post record write.

## Changed paths and deployment boundary

Runtime changes are in `app/controllers/mobile/{authorizations,tokens,sessions}_controller.rb`,
`app/controllers/api/mobile/v1/{base,buddy_checks}_controller.rb`, `app/models/user.rb`,
`app/models/mobile.rb`, `app/models/mobile/{remembered_session,refresh_credential,token_exchange}.rb`,
`app/services/mobile/remembered_tokens.rb`, `app/jobs/expire_mobile_token_responses_job.rb`,
the two mobile ERB views, `config/routes.rb`, Doorkeeper and parameter-filter
initializers, and `config/recurring.yml`.

Migration `20261012190000_add_mobile_remembered_sessions.rb` adds three tables and
nullable family references on existing OAuth tables. `db/structure.sql` reflects
it. Existing users/credentials need no data conversion. Tests are in the two new
remembered-auth/concurrency controller files and `test/system/buddy_checks_test.rb`.
The new `test/manual/buddy_remembered*.rb` helpers and one synthetic-database
allowlist entry support this isolated acceptance service.

Production release is authorized after completed native acceptance and
the final backend checks. Use the repository release wrapper and the already-open
production SSH master; never open a direct or parallel fallback. The separate NTP
repair is complete: the Mac Console session allowed outbound UDP/123, and the Linux
session verified synchronization, a second-sample offset of +765 microseconds,
and healthy responses from both hosted sites at 19:15 UTC. The original master
remains open for this forthcoming work. No auth migration has run in production.

## Authorized release scope

The reviewable change is **32 paths** in `/tmp/legion-mobile-remembered-sessions`,
branch `codex/mobile-remembered-sessions`, based on deployed parent
`66bb8150bb465c4a4926b5c303effc652d177730`. This preserves the live random-choice
feature and retained-SSH support. Scope is the remembered-auth runtime, schema,
regressions, guarded synthetic helpers and their documentation, including the
deployment guide's link to the new opt-in contract. The original shared checkout's
uncommitted work is outside this release.

The resulting behavior is explicit human consent for at most 180 elapsed days,
900-second access, rotating refresh credentials with fixed 120-second identical
exchange recovery, and immediate current account/pilot/export enforcement.
Website disable permanently revokes existing families and pending codes; native
sign-out and website Mobile sessions revoke the whole family. Ordinary expiry and
uncertain delivery preserve native drafts; confirmed access removal purges them.
Legacy clients retain their existing nonrenewable contract.

Migration `20261012190000` is additive: three new tables, nullable indexed family
references on OAuth grants/tokens, foreign keys, unique current-refresh/exchange
constraints and the fixed-duration check. It does not seed, backfill, grant access,
change client registration, alter member records or convert existing credentials.
Rails' existing container entrypoint runs `db:prepare` before starting the new app.
The every-minute background job clears expired encrypted recovery responses; the
existing production worker consumes the background queue. Digest/replay evidence
remains retained.

No production setup values change: issuer `https://members.wipost165.org`, public
client ID `org.wipost165.buddychecks`, exact callback
`org.wipost165.buddychecks:/oauth/callback`, scope `buddy_check`, S256, existing
pilot/export flags and grants. The updated native app needs fresh explicit consent
to establish a remembered connection; existing legacy credentials do not silently
become renewable.

Validation: full ordinary **1,455 / 14,464**, full browser **94 / 5,412**, no
failures/errors/skips; RuboCop **616 files, zero offenses**; Brakeman **zero
warnings/errors**; native sign-in/restart, unsent draft preservation, lost-response
recovery, account-disable purge, re-enable/fresh consent and sign-out evidence above.
The lifetime limit, replay denial and concurrency variants are automated synthetic
tests, not a claim to have waited 180 days on a device. No dependency changes were
made. The existing dependency audit passed for the deployed parent.

**Release authorization:** Andre explicitly approved the narrow backend commit,
push and deployment of the 180-day remembered sign-in change, including the
additive migration, on October 12, 2026. He requested reuse of the existing
persistent SSH connection and retention through all verification. Native
acceptance and implementation checks are complete. The Mac session will install
its tested, signed update after the backend deployment is verified.

Stage only these intended paths in the isolated checkout,
commit, run `bin/release check`, then `bin/release push-deploy` with
`RELEASE_KEEP_SSH_MASTER=true` while further verification needs the retained
connection. Explicitly unset `BUDDY_CHECK_ACTIVATE_EMAIL`: this release must not
repeat activation or regrant permissions. Use the proven command-scoped GitHub
key configuration, preserve the existing production SSH master, stop on any
failure, and do not reconnect/retry automatically. Verify exact pushed/running
revision, migration completion, NTP synchronization and both sites' public health.
Any production human sign-in is a separate native acceptance action, not a reason
to mint a backend test credential or create a Buddy Check record.

If application rollback becomes necessary, preserve the additive schema and its
credential/replay evidence. A previous application version lacks renewal support,
so coordinate the resulting native reauthentication behavior. Do not run a schema
rollback or drop these tables after use; destructive credential/data cleanup needs
separate authority. Keep the working synthetic fixture for diagnosis.
