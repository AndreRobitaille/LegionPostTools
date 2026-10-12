# Remembered Buddy Checks sign-in

October 12, 2026. Implementation target authorized by Andre: remember sign-in for
at most 180 days, and stop app access immediately when website account access is
removed. This is separate from the random-choice release at
`66bb8150bb465c4a4926b5c303effc652d177730`. Implementation and synthetic validation
are complete. On October 12, 2026, Andre explicitly authorized the scoped commit,
push and production deployment, including the additive migration, using the
existing persistent SSH connection through final verification.

## Product and consent

The member explicitly connects Buddy Checks using the existing human browser
sign-in and S256 authorization flow. The updated app asks for a remembered
connection; the consent page explains its 180-day maximum, earlier account-access
loss, and revocation. Old apps retain their existing 15-minute flow.

Keep the existing 1919 page lead, paper panel, navy primary button, system sans
type, 16px body/controls and 14px secondary copy. For the remembered flow the
button says **Connect and remember this sign-in**. Keep the account identity and
privacy explanation above it; show the maximum duration and revocation explanation
next to the action. The legacy button remains **Connect Buddy Checks**. The Mobile
sessions page presents one remembered connection with its connection/expiry dates
and one revocation action, even when its current access token has expired. Use
existing list rows, wrapping at narrow widths. No token or implementation details
belong in the member-facing flow.

## Exact opt-in and token contract

The public client ID, exact callback, issuer and `buddy_check` scope do not change.
No client secret, browser-cookie renewal, hidden webview or privileged token is
introduced. Preserve consent CSRF/origin checks, `Referrer-Policy: strict-origin`
and no-store responses.

Add `remember_session=180_days` to `GET /oauth/authorize`, alongside the existing
`client_id`, `response_type=code`, `redirect_uri`, `scope=buddy_check`, `state`,
`code_challenge`, `code_challenge_method=S256`. Preserve the opt-in through human
sign-in and the explicit consent POST. Reject any other nonempty opt-in value.
Absence preserves legacy behavior. Token-endpoint parameters cannot opt a legacy
authorization into a remembered connection.

For an opted-in code, `POST /oauth/token` receives the existing authorization-code
exchange fields plus `exchange_id`, a canonical UUID. The client must atomically
persist that ID and the complete pending exchange before transmitting it.

For renewal, submit form-encoded fields to the same token endpoint:

```text
grant_type=refresh_token
client_id=<existing public client ID>
refresh_token=<current opaque renewal credential>
exchange_id=<new UUID for this exchange>
```

Remembered success responses contain `access_token`, `token_type=Bearer`,
`expires_in`, `scope=buddy_check`, `created_at` (integer epoch seconds), and:

```json
{
  "refresh_token": "<opaque rotated credential>",
  "issuer": "https://members.wipost165.org",
  "installation_id": 1,
  "user_id": 2,
  "session_id": 123,
  "remembered_session_id": "<stable UUID>",
  "authorized_at": "<UTC ISO-8601>",
  "remembered_until": "<UTC ISO-8601>",
  "expires_at": "<access-token UTC ISO-8601>"
}
```

Access lasts at most 900 seconds, shortened at the absolute deadline.
`remembered_until` is also the refresh credential's expiry: exactly 180 days
(15,552,000 seconds) after human consent. No renewal or recovery extends it.
`session_id` is the current access-token row ID and changes with renewal;
`remembered_session_id` is the stable UUID for the whole connection.

`GET /api/mobile/v1/session` retains `installation`, `user`, `session_id`,
`expires_at` and `capabilities`. Remembered responses add `remembered_session_id`,
`authorized_at`, `remembered_until`, and return `capabilities.refresh=true`.
Legacy responses remain unchanged, including `refresh=false` and no refresh
credential. Validate issuer, installation, user and stable connection identity
before atomically replacing the device-only Keychain bundle. Draft ownership is
bound to issuer/account; a routine token ID change does not mean account change.

## Rotation, response loss and concurrency

Each successful renewal consumes one refresh credential and creates its successor.
Store only high-entropy credential digests for lookup, retaining their relationship
to the connection for replay detection. Serialize exchanges with a database row
lock; concurrent requests cannot produce competing successors.

An identical request (same input credential, exchange ID, client and complete
request binding) can recover the same output credential pair for **120 seconds**
after its first successful commit, only while that successor remains current.
Keep the recovery response encrypted server-side. The interval is fixed and is
not extended by retries. Recovering a response does not rotate again or reset
access expiry; report the remaining access lifetime.

Reusing a consumed refresh credential with a different exchange ID, after the
window, or after the successor has already been renewed revokes the whole family.
The client must serialize renewal and reuse its persisted exchange ID after an
interruption. If it cannot establish that recovery is still within the window,
it must require human reauthorization instead of replaying the old credential.
Uncertain delivery and ordinary expiry do not themselves justify deleting drafts.

The initial authorization-code exchange has the same fixed recovery window and
request binding, including the original PKCE verifier. A correctly bound replay
that can no longer recover revokes its existing family and returns
`revoked_session`. An invalid code or incorrect PKCE verifier returns
`invalid_authorization_code` and cannot revoke someone else's family. The native
client should stop retrying an uncertain initial exchange outside the window and
start fresh human sign-in while retaining drafts.

The bounded identical-request recovery is a deliberate availability tradeoff: a
party holding the complete original request can obtain the same result during
that interval. It cannot extend the interval or create another successor. Other
reuse is detected and revokes the family, following the rotation/replay approach
in [RFC 9700 section 4.14](https://www.rfc-editor.org/rfc/rfc9700.html#section-4.14).

Normal renewal does not revoke earlier access tokens before their individual
expiry. All tokens check the same live family/account authority on every request.

## Account authority and revocation

The website account's `disabled_at` policy governs app access too, including
manual disable and roster-derived disable/removal. Every API use and renewal
checks current account existence/enabled state and the current pilot capability.
Persist connection revocation when account access is disabled, so re-enabling an
account does not revive old credentials. Global temporary feature unavailability
is distinct from account revocation. Current export permission remains separate.

`POST /oauth/revoke` uses the current client ID and `token` (access or refresh;
`token_type_hint` optional). Any credential from a remembered family, including a
consumed refresh credential, revokes the whole family and its access tokens.
Unknown/already-revoked credentials return 200 without disclosing existence.
The website's Mobile sessions revocation does the same with CSRF protection and
ownership checks. Browser sign-out alone is not account disable or mobile revoke.

## Error contract

Token failures retain OAuth's string `error` and add the machine-readable string
`error_code`. Invalid credentials normally use HTTP 400 / `invalid_grant`;
malformed exchange IDs use HTTP 400 / `invalid_request`; invalid clients use 401 /
`invalid_client`; temporary unavailability uses 503 / `temporarily_unavailable`.

| `error_code` | Meaning / client action |
| --- | --- |
| `invalid_authorization_code` | Invalid, expired or unrecoverable code exchange; human sign-in, retain drafts. |
| `invalid_refresh_token` | Unknown/malformed renewal credential; human sign-in, retain drafts. |
| `invalid_exchange_id` | Missing/malformed exchange UUID; do not rotate with a newly invented retry ID. |
| `invalid_client` | Client/installation setup mismatch; do not treat as account revocation. |
| `remembered_session_expired` | Absolute 180-day limit reached; human sign-in, retain drafts. |
| `revoked_session` | Confirmed family revocation; apply existing purge policy. |
| `refresh_reuse_detected` | Reuse revoked the family; apply existing purge policy. |
| `account_unavailable` | Confirmed underlying account or pilot access loss; apply existing purge policy. |
| `unavailable` | Temporary installation unavailability; preserve account and drafts. |

Resource API errors keep `{ "error": { "code": "..." } }` and the existing
status conventions. `expired_session` means access-token expiry and allows
renewal. `remembered_session_expired` requires human sign-in but is not revocation.
`account_unavailable` (401/403), `revoked_session` and `refresh_reuse_detected`
are terminal authority/revocation outcomes. Ordinary `not_permitted`, network
errors and temporary unavailability do not revoke the account. Never infer
revocation solely from a missing response or access-token expiry.

## Verification plan and release boundary

Use the ordinary synthetic test database, preserving both consumed LAN fixtures.
Cover the actual initial opt-in/consent/code exchange and legacy compatibility;
access expiry; the absolute deadline (including shortened final access); repeated
rotation; same-request recovery and cache expiry; competing/concurrent renewals;
wrong-client and altered-request denial; account disable/removal and re-enable;
current pilot/export changes; website and app revocation; and secret filtering.
Check subsequent protected reads with unexpired old and new credentials. Exercise
consent and session revocation in a real browser at desktop and narrow widths.
Tests must demonstrate the missing behavior before implementation, then pass with
the implementation. No production member writes or credential disclosure.

Completed acceptance and the authorized release scope are recorded in
[the release handoff](MOBILE_REMEMBERED_SIGN_IN_HANDOFF.md).
