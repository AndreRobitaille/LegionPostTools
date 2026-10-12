# Buddy Checks production connection handoff

Prepared October 12, 2026. Release verification is pending until the release record
below is filled in; local tests alone do not establish readiness.

## iPhone configuration

| Setting | Value |
| --- | --- |
| HTTPS origin and exact issuer | `https://members.wipost165.org` |
| Public OAuth client ID / bundle ID | `org.wipost165.buddychecks` |
| Exact callback | `org.wipost165.buddychecks:/oauth/callback` |
| Scope | `buddy_check` |
| Client authentication | Public; no secret |
| Flow | Authorization code, S256 PKCE, human browser sign-in and explicit consent |
| Access lifetime | 900 seconds; `capabilities.refresh=false`; no refresh token |
| Post / time zone | Robert E. Burns Post 165 / `America/Chicago`; installation ID verified during release |
| Contacts company | `American Legion Post 165` |

Configure the existing Swift app with this origin and client ID. Normal TLS
validation applies. The API and token endpoints require the exact origin and do
not depend on a temporary certificate, LAN server or SSH tunnel on the Mac.
The browser consent response retains `Referrer-Policy: strict-origin` and normal
CSRF/origin verification. API reads return 200, mutations and accepted retries 201,
exchange and revocation 200. See the [complete contract](MOBILE_BUDDY_CHECK_API_HANDOFF.md).

No Apple source change is required. The new explicit Contacts export permission
uses the existing `contacts_export` capability and `export_not_permitted` error.
Only configuration changes from the synthetic installation are needed. Reauthorize
for this installation; do not carry synthetic records or credentials into it.

## Backend and staff support

All requested routes are implemented, including receipt recovery, immutable
corrections, caller-owned history, follow-up changes and closed-status collection
pagination, and prior-suggestion snooze recovery. Browsing creates no outreach,
assignment or follow-up. Missing history remains unknown; incomplete general-member
registers cannot support an absence suggestion. Renewal, financial and accepted
minutes evidence stay separate from mobile actions.

Initial launch is restricted to Andre through the explicit `use_mobile_buddy_checks`
pilot grant. It gates human consent, token exchange, all mobile requests and the
phone-related website controls. Neither Commander status, other offices nor
administration implies pilot access; the role system can deliberately grant it later.
Other users see no Mobile sessions, general-member attendance or address-review links,
and direct URLs are denied. Removing pilot access returns the existing 403
`account_unavailable` authority error; no JSON schema or Swift code change is required.

Contacts export requires both the installation flag and the separate
`export_buddy_contacts` grant. Initial activation grants it to Andre only.
`manage_settings`, membership leadership and assignment access do not imply export.
Existing current membership authority additionally controls reviewed address fields.
The server exports reviewed structured components only; unreviewed or stale sources
produce unknown address coverage. Actual Post addresses/attendance must be reviewed
by the authorized officer using the new staff controls, never inferred or seeded.

Staff controls are under Membership → General-member attendance, Membership → a
person → reviewed address, and People → a login account → Permissions → Buddy Checks.
Grant revocation affects the next request made with an existing token.

## Verification

- Focused synthetic checks after pilot restriction: 42 tests, 362 assertions, zero failures/errors/skips.
  Cover human code/PKCE/consent continuation, disabled/revoked/expired sessions,
  ownership and current authority, receipt retries and conflicts, corrections,
  follow-up reschedule/complete/cancel, snooze recovery, export restrictions and
  incomplete/revised attendance. Assertions include persisted and later-read state.
- Export regression first failed against the original implementation (ungranted
  officer got 200), then passed with separate current-grant enforcement.
- Independent PostgreSQL retry race passed on a newly created synthetic database:
  a second writer waited on the real lock, both received identical receipts, one
  contact/receipt persisted, and changed-payload reuse conflicted without mutation.
- RuboCop on current master plus this patch: 603 files, no offenses. Brakeman: zero errors/warnings. Bundler audit:
  no vulnerabilities, advisory revision `a6847b0651a702488f5844081e848dd1ec9dbf1d`.
  Zeitwerk eager loading passed. Final full ordinary suite on current master plus the pilot patch: 1,425 tests,
  14,096 assertions, zero failures/errors/skips. Full browser suite before the pilot restriction: 92 tests, 5,369 assertions,
  zero failures/errors/skips. Final browser checks on current master plus the pilot
  patch: 8 tests, 123 assertions, zero failures/errors/skips, covering consent with
  browser-generated Origin/referrer, email-code sign-in, pilot visibility and grant
  changes. Desktop and 390px screenshots were inspected; controls stayed readable
  and pages had no horizontal overflow.

## Release record

Activation is blocked pending explicit commit/push/deploy authorization required by
automatic approval review. No commit, push, deployment or production grant/migration
was performed. The production mobile session route currently returns HTTP 404;
the permanent origin passes normal TLS validation with no redirect.

After release, record the deployment revision, production installation/user IDs,
applied migrations, enabled settings, preserved-table fingerprint comparison and
public endpoint checks here. The intended public configuration above is prepared,
not a registered production-client claim.

Required migrations:

- `20261011210000_add_mobile_buddy_checks`
- `20261011211000_preserve_buddy_evidence`
- `20261012120000_add_buddy_contact_export_permission`

The readiness probe additionally verifies that only Andre has the pilot grant and
that no office-level pilot grant exists. The normal release wrapper performs transport
preflight, deployment, narrow activation and read-only probes within its persistent SSH session. No production
contacts, conversations, follow-ups, address reviews or attendance are fabricated.

Real email inbox delivery/browser sign-in still requires Andre's participation.
Automatic approval review rejected sending the sign-in email without separate
explicit authorization. No email was sent by that blocked action. Native
ASWebAuthenticationSession, iPhone installation and device verification belong to
the mobile agent.
