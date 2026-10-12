# Buddy Checks private LAN integration

Updated October 11, 2026 for the native consent submission fix. Synthetic server
running; no production deployment.
Base revision remains `845d17be4d5173a5dd8e31aae085fccade4569d7`, plus the
uncommitted implementation in [the API handoff](MOBILE_BUDDY_CHECK_API_HANDOFF.md)
and the test-only integration helpers described below.

## Public connection configuration

| Setting | Value |
| --- | --- |
| HTTPS origin / issuer | `https://192.168.37.41:3443` |
| Public OAuth client ID | `lS3KMnkvx6gFBdd9Do17PWD7HnJ_afiwZGXxv9_YEHA` |
| Exact redirect URI | `org.wipost165.buddychecks:/oauth/callback` |
| Scope | `buddy_check` |
| Client authentication | Public client; no secret |
| PKCE | S256 required |
| Access lifetime | 900 seconds; no refresh token |
| Health URL | `https://192.168.37.41:3443/up` |

This is `andreG7linux`, reached on the shared `192.168.37.0/24` LAN. Hostname/IP
were checked locally, rather than inferred from older `arch-herdr` references.
Puma 8.0.2 serves Rails directly over TLS on `0.0.0.0:3443`, using only PostgreSQL
database `legion_buddy_mobile_test`. The existing service on port 3000 is untouched.
There is no public tunnel, DNS change, production transport or production data.

The server can reach this origin with certificate verification. The mobile session
reports that native run 05 on the iPhone 17 Pro simulator (iOS 27) reached it with
normal TLS validation and the matching test CA trusted only in that disposable
simulator. Physical-iPhone connectivity remains unverified.
If the machine's LAN IP changes, stop and reissue the certificate/configuration;
the certificate intentionally covers the exact current IP.

## Trust the test certificate

Only the public CA certificate is shared. Its private signing key was discarded
after issuing this server certificate. The server key and environment file stay
owner-only under `/tmp/legion-buddy-mobile/`.

Public CA files on the backend machine:

```text
/home/andre/Development/LegionPostTools/tmp/buddy-mobile-public/buddy-checks-test-ca.cer
/home/andre/Development/LegionPostTools/tmp/buddy-mobile-public/buddy-checks-test-ca.pem
```

CA SHA-256 fingerprint:

```text
6F:9C:11:BA:A4:BD:06:A5:1A:82:6F:29:F1:8F:06:48:35:E8:CF:1E:2B:EA:AF:13:13:19:E4:B1:97:93:40:01
```

CA/server certificates expire **October 18, 2026 at 22:08:59 UTC**. This is a
temporary testing identity, not a publicly trusted certificate. Transfer only the
public `.cer`/`.pem`, for example from the Mac:

```sh
scp andre@192.168.37.41:/home/andre/Development/LegionPostTools/tmp/buddy-mobile-public/buddy-checks-test-ca.cer .
scp andre@192.168.37.41:/home/andre/Development/LegionPostTools/tmp/buddy-mobile-public/buddy-checks-test-ca.pem .
openssl x509 -inform DER -in buddy-checks-test-ca.cer -noout -fingerprint -sha256
curl --cacert buddy-checks-test-ca.pem https://192.168.37.41:3443/up
```

Compare the fingerprint before trusting it. The current approved device scope is
the disposable simulator only. The mobile session removed its test CA after the
last pass; reinstall and trust this same public CA there before the next native
run, then remove it when testing ends. The Mac and physical phone trust stores
are unchanged. No machine-wide trust installation is needed for the
`curl --cacert` check above. See [Apple's test-CA guidance](https://developer.apple.com/library/archive/qa/qa1948/_index.html).

No ATS exception, TLS-validation bypass or client trust override was added.
Native callback registration and any local-network permission remain the mobile
project/device's responsibility. Do not substitute production if trust fails.

## Consent correction and next native pass

Native run 05 completed Jamie Caller's email/code sign-in and displayed Connect
Buddy Checks, then the real consent POST failed Rails CSRF origin verification.
The authorization response used `no-referrer`, causing a browser form navigation
to send `Origin: null`. This was a response-policy failure, not an OAuth callback
or PKCE validation failure. Earlier input-harness failures and the later refresh
experiment (which stopped at code entry) establish nothing about consent refresh.

Authorization responses now use `Referrer-Policy: strict-origin`. Unlike
`same-origin`, this omits paths and query strings even on same-origin referrers.
It allows an origin-only referrer to another HTTPS destination, suppresses it on
an HTTPS-to-HTTP downgrade, and preserves the normal Origin on the same-origin
consent POST. See [MDN's referrer policy and Origin rules](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Referrer-Policy).
`Cache-Control: no-store`, CSRF tokens, origin checks, exact issuer/callback, S256,
explicit consent, public-client authentication and 900-second access lifetime are
unchanged. No client header workaround or null-Origin exception was added.

The signed native build now has working Keychain access, declares its local-network
purpose and requests an ephemeral authentication browser, as reported by the mobile
session. **The corrected flow still needs its native integration pass.** Verify the
successful callback and connected Post home, then token exchange/restoration,
encrypted draft restoration and server record workflows. No connected Buddy Check,
correction, follow-up, snooze or Contacts write was submitted from the native app
during the reported pass. Backend/Chromium evidence below does not establish those
native outcomes.

Public setup values are unchanged: same issuer, client ID, callback, scope and CA
fingerprint. Only the dedicated synthetic server was restarted to load this fix.
Its current PID is `3544651`; the port-3000 process remains PID `3270270`.

Verification for this correction:

- Before changing the header, the new real-Chromium consent-click regression
  failed with browser-generated `Origin: null` (1 test, 5 assertions, 1 expected
  failure). It uses the actual form with both CSRF and origin protection enabled,
  without injecting request headers. The earlier browser test only rendered the
  consent page, so it could not catch this defect.
- After the correction,
  `bin/rails test test/system/buddy_checks_test.rb --seed 41450` passed **3 tests,
  41 assertions, zero failures/errors/skips**. Chromium submitted its actual
  same-origin Origin and an origin-only Referer; the server issued a 302 to the
  exact registered test callback with matching state and persisted an S256-bound
  code for the consenting user/client. This browser regression runs against
  localhost in the isolated ordinary test database; it is not an iOS HTTPS run.
  Since Chromium has no native callback handler, the test returns to a normal
  page afterwards. Without that cleanup the next test's sign-in click did not
  submit; the same ordered three-test sequence passed after adding it.
- The broader rerun, `bin/rails test:system --seed 41450`, passed **91 tests,
  5,356 assertions, zero failures/errors/skips** after that browser cleanup. The
  initial expanded run had 91 tests, 5,349 assertions and the one sign-in failure
  described above. No production code change was needed for that test isolation
  issue. The full ordinary suite was not rerun for this focused header correction.
- Focused backend command:
  `bin/rails test test/controllers/mobile_authentication_test.rb test/controllers/api/mobile test/services/buddy_checks test/controllers/buddy_evidence_review_test.rb`
  passed **31 tests, 251 assertions, zero failures/errors/skips**. Coverage checks
  the response policy/no-store and rejects missing and wrong CSRF tokens plus
  unrelated and null Origins without creating grants or access tokens.
- After restarting the dedicated HTTPS process,
  `ruby test/manual/buddy_mobile.rb verify-sign-in` passed for Jamie and Riley.
  This checks the actual consent response's `strict-origin`/`no-store`, email/code
  sign-in, secure cookies, exact callback/state, S256, rejected wrong verifier and
  rejected code replay. These are direct HTTP checks with an explicit Origin;
  they are separate from browser-generated-header evidence. Probe tokens were
  revoked afterwards. HTTPS `/up` returned 200 with TLS verification result 0.
- Before/after read-only SQL row counts and whole-row fingerprints matched for
  contacts (5), operation receipts (11), follow-ups (3), snoozes (1), address
  reviews (1), attendance registers (2), minutes (0), and OAuth applications (1).
  The database was not reset; existing evidence and client rows were unchanged.
  Sign-in probes created normal authentication sessions/codes and revoked their
  own access tokens.
- Focused RuboCop passed for all four changed Ruby files. Brakeman 8.1.0 reported
  zero warnings/errors. Its first invocation could not write the sandbox's gem
  cache; rerunning with `GEM_SPEC_CACHE=/tmp/buddy-consent-gem-spec-cache` passed.
  Whitespace and local Markdown reference checks passed.

Changed paths for this consent follow-up only:

- `app/controllers/mobile/authorizations_controller.rb`
- `test/controllers/mobile_authentication_test.rb`
- `test/system/buddy_checks_test.rb`
- `test/manual/buddy_mobile_probe.rb`
- `docs/MOBILE_BUDDY_CHECK_DESIGN.md`
- `docs/MOBILE_BUDDY_CHECK_API_HANDOFF.md`
- `docs/MOBILE_BUDDY_CHECK_LOCAL_INTEGRATION.md`

All pre-existing membership/mobile changes remain uncommitted and preserved. No
commit, push, deployment, production access or database reset was performed.

## Existing human sign-in with a private synthetic inbox

Synthetic accounts:

| Role | Email | User ID |
| --- | --- | --- |
| Ordinary caller, Jamie Caller | `jamie@example.test` | 1 |
| Full membership reviewer, Riley Reviewer | `riley@example.test` | 2 |

Preferred flow, including an ephemeral `ASWebAuthenticationSession`:

1. Start sign-in from the mobile app and enter one of these emails in the existing
   browser sign-in form.
2. The server writes that request's link and browser-bound eight-digit code to a
   private local inbox. No email is sent. Read the matching file locally or through
   your existing SSH access; do not paste its contents into a shared handoff/issue:

   ```sh
   ssh andre@192.168.37.41 'cat /tmp/legion-buddy-mobile/mail/1.json'
   # Reviewer instead:
   ssh andre@192.168.37.41 'cat /tmp/legion-buddy-mobile/mail/2.json'
   ```

3. Enter the fresh code in the **same browser session** that requested it, then
   explicitly select Connect Buddy Checks. Codes expire after 15 minutes and are
   single-use. An older inbox file can contain an already-consumed code: request
   sign-in first, then read the latest file.

For a direct synthetic browser sign-in link, run on the backend:

```sh
cd /home/andre/Development/LegionPostTools
ruby test/manual/buddy_mobile.rb sign-in
```

It refreshes `/tmp/legion-buddy-mobile/sign-in.json` (mode 0600). Open the appropriate
private link on your device. A standalone Safari link does not establish a session
inside an ephemeral app browser; use the code flow above in that case. Sign out of
the existing browser account before testing the other identity.

## Current fixture and observed backend evidence

The probe deliberately left its accepted work in place. No accepted evidence was
reset to make verification pass.

| Person | ID | Current synthetic state |
| --- | --- | --- |
| Alex Example | 3 | Old reached contact; eligible after the higher-ranked absence candidate. |
| Blair Example | 4 | Backend probe created logical check 4, then correction row 5. Original `no_answer` remains; effective outcome is `wrong_number`. Recent attempt excludes outreach. Reviewed street available only to the reviewer. |
| Casey Example | 5 | Recent reached contact excludes outreach. |
| Dana Example | 6 | Purpose paused; private officer note excluded from mobile responses. |
| Evan Example | 7 | Directory-hidden expired member, permitted only through Jamie's active assignment. No assignment-only Contacts export. |
| Frankie Example | 8 | Existing future open follow-up. |
| Morgan Example | 9 | Two complete explicit general-member absences; first suggestion. |
| Harper Example | 10 | Untouched person for mobile unknown-history and write tests. Added after these registers; attendance is unknown. |

For `insufficient_history`, exclude the other IDs while leaving Harper; missing
history must not become “never contacted.” Harper is included in the repeatable
fixture script too; a freshly generated fixture will include Harper in its named
attendance coverage, whereas this running fixture has no Harper attendance rows.

Observed against the actual HTTPS process, with peer/hostname verification:

- TLS health returned HTTP 200 with verification result 0. TLS 1.2 negotiated
  `ECDHE-RSA-AES256-GCM-SHA384`; certificate/IP verification succeeded.
- Both synthetic accounts completed direct HTTP sign-in/consent/PKCE. These
  protocol probes explicitly supplied Origin; they did not establish browser
  header behavior. Both the
  magic-link and normal email-form/eight-digit-code paths were exercised. Missing
  CSRF was rejected; browser cookies were Secure; callback and state matched;
  wrong verifier and authorization-code replay failed.
- Search returned bounded identity-only pages without overlap. Fresh eligibility,
  insufficient history, explicit absences and ordinary/officer export tiers matched
  the API contract.
- One actual contact submission with follow-up was accepted. Its response was
  deliberately ignored, then recovered through its operation receipt and retried.
  SQL confirmed one original contact and one receipt for that operation. Changed
  payload reuse returned conflict; correction appended one new row and preserved
  the original and original receipt.
- The linked follow-up was rescheduled and completed. A separate follow-up was
  created and cancelled. Stale revision was rejected; none of those actions added
  a contact. A personal snooze was created and undone.
- The probe made its own token's persisted creation time older to exercise actual
  HTTP expiry rejection; this was controlled expiry, not a 15-minute wall-clock
  device test. Explicit OAuth revocation returned `revoked_session` on the next
  request. Normal access lifetime remained 900 seconds.
- Final SQL: five contact rows (three fixture rows plus original/correction),
  eleven operation receipts with eleven distinct scoped operation IDs, one open
  fixture follow-up, one completed follow-up, one cancelled follow-up, and one
  undone snooze. There are zero minutes records.

The first protocol probe selected the wrong form's CSRF token, then used a cached
runner count after a separate server process committed. Those were probe errors:
the correct per-form token and uncached database reads resolved them. Direct SQL
showed no duplicate. The probe resumed the same accepted operation instead of
resetting it. The full intended protocol sequence subsequently passed.

The earlier integration-setup regression pass was **18 tests, 170 assertions, no failures/errors**.
Focused lint passed for all nine changed/new Ruby files; `git diff --check` passed.
The startup guard was also exercised and rejected the ordinary test database
before initialization.
That earlier pass supplemented the full suites in the API handoff; its changes
were test infrastructure and fixtures. The subsequent consent-policy correction
above changes the authorization response. Native Contacts, call return,
device-journal acceptance and the corrected native authorization flow remain
unverified.

## Running, stopping and cleanup

The current server is intentionally left running for integration. It is a foreground
process owned by this backend session, not a boot service; it may stop when the host
or session ends. Current host PID at handoff: `3544651`. Private configuration,
TLS key, PID file and login material are under `/tmp/legion-buddy-mobile/`.

From a terminal **on the backend host**, verify the listener/PID before stopping:

```sh
ss -ltnp 'sport = :3443'
cat /tmp/legion-buddy-mobile/server.pid
kill -TERM 3544651
```

That PID is specific to this run; use the current confirmed PID after a restart.
Restart while the private files and certificate remain valid:

```sh
cd /home/andre/Development/LegionPostTools
ruby test/manual/buddy_mobile.rb server
```

Leave that terminal open; Ctrl-C stops it. The wrapper loads feature flags, issuer,
client ID, secret key and database URL from the owner-only environment file. It
does not configure the normal app process. Test-only configuration enables CSRF,
host checking and secure cookies, keeps external jobs disabled and replaces only
sign-in delivery with the private synthetic inbox. There is no mail/provider call.

Repeat the non-contact-mutating email-code protocol check while the server runs:

```sh
ruby test/manual/buddy_mobile.rb verify-sign-in
```

`ruby test/manual/buddy_mobile.rb verify` is the complete contact probe. It expects
an untouched Blair fixture and refuses this already-used fixture; it never resets
accepted work. Keep the current database for mobile integration and backend SQL
reconciliation. Its narrow interrupted-first-submission resume option is documented
in the script, not an automatic retry/reset loop.

When Andre is finished testing: stop the confirmed synthetic server, remove this
test CA from the disposable simulator if reinstalled, and explicitly dispose of only
`legion_buddy_mobile_test`, `/tmp/legion-buddy-mobile/` and the public certificate
copies under `tmp/buddy-mobile-public/`. Do not touch development/production databases
or the existing port-3000 service. No cleanup is performed merely by closing a mobile
session.

Files added/changed for this integration setup: the opt-in hook in
`config/environments/test.rb`; `test/manual/buddy_mobile*.rb`,
`refresh_buddy_mobile_sign_in.rb`, `verify_buddy_mobile*.rb`; fixture callback/output
configuration and Harper in `setup_buddy_mobile.rb`; and this documentation. No
commits, pushes, production releases, device trust changes or Apple source edits
were performed.
