# Roster-Managed User Access Design

**Date:** August 30, 2026

**Status:** Accepted for implementation

## Decision

Every roster-backed person whose current National roster status is `Active` or `Grace`
should have an enabled LegionPostTools login account by default. A successful roster
import creates a missing account when the member has a usable, unique roster email.

When an existing account's person becomes `Expired`, `Deceased`, or absent from the
newest roster, the import disables the account and stores the reason. A returning
`Active` or `Grace` member is enabled again automatically unless an administrator has
deliberately disabled that account.

The roster remains authoritative for membership eligibility. It does not become
authoritative for an existing account's login email: imports never silently replace that
address.

## Why

Requiring an administrator to enable every member defeats the roster's role as the
Post's membership authority and creates unnecessary work. The safer low-confidence-user
experience is that a current member can use the email already recorded with The American
Legion, while routine roster imports remove access when membership eligibility ends.

A stored disable reason prevents an officer from having to infer why an account is off.
It also distinguishes an intentional local safety decision from a National roster
change.

## Account State Model

Roster-backed accounts follow these rules:

| Roster condition | Local condition | Result |
| --- | --- | --- |
| Active or Grace | No account; usable unique roster email | Create and enable a roster-managed account. |
| Active or Grace | Enabled account | Keep enabled. |
| Active or Grace | Roster-disabled account | Re-enable and clear the reason. |
| Active or Grace | Manually disabled account | Keep disabled with the manual reason. |
| Expired or Deceased | Any non-protected account | Disable with the roster status as the reason. |
| Missing from newest roster | Any non-protected account | Disable with “removed from roster” as the reason. |
| Unsupported status | Existing account | Disable with the status as the reason and report it for review. |
| Unsupported status | No account | Do not create an account; report the status for review. |

The last enabled `Manage settings` administrator remains protected from automatic or
manual disabling. The import reports that exception.

People who are not roster-backed, including a technical helper created locally, remain
manual accounts because National membership status does not apply to them.

## Email Eligibility

Automatic account creation requires a roster email that is:

- present;
- syntactically valid;
- used by only one current member in the imported file; and
- not already assigned to another LegionPostTools account.

If any condition fails, the person record still imports. No account is created, and the
import records a plain-language problem without copying the email address into the
persisted import summary. An administrator can correct the National record or, after
verifying identity and ownership, supply a usable login email on the person's page.

## Disable Reasons

`User` stores a reason key and optional detail alongside `disabled_at`:

- `manual` — disabled deliberately by an administrator;
- `roster_status` — disabled because the imported status is not Active or Grace, with
  the normalized status stored as detail; or
- `roster_removed` — disabled because the member is absent from the newest roster.

Enabling an account clears its disable reason. A historical disabled account receives a
best-effort reason during migration so the UI does not begin with unexplained disabled
records.

## Administrator Workflow

The common workflow no longer asks an administrator to create or enable each current
member. The People page becomes a review and exception workflow:

- current members with eligible emails receive accounts during import;
- the import result reports accounts created, accounts enabled, accounts disabled, and
  active members whose email prevented account creation;
- the person's Login Account panel shows whether sign-in is available, why it is off,
  and whether the roster or an administrator controls the state; and
- **Disable sign-in** remains available as an explicit local safety override.

For an active person without an automatically created account, the existing email form
allows a verified unique address to be supplied. The resulting roster-backed account is
roster-managed immediately; it does not require a second “switch back” step.

## Visual Direction

**Subject:** an American Legion officer reviewing a member's access record.

**Single job:** answer “Can this person sign in, and if not, why?” without requiring the
officer to understand account state machinery.

The established “The 1919” system remains intact:

- **Legion navy `#0A2240`** for identity and primary action;
- **service green** and its pale field for enabled status;
- **Legion red** and a restrained pale field for disabled status;
- **paper, gold, and muted blue-gray** for provenance and supporting explanation;
- the existing display/body/utility typography roles, with no new font dependency.

The signature element is a compact access service record: email and status badge first,
then one bordered reason line immediately below it.

```text
┌─────────────────────────────────────────────────────────────┐
│ Signs in as member@example.org        [ Cannot sign in ]    │
│ ▌ National roster status is Expired.                       │
│   Sign-in will return automatically if an eligible status   │
│   appears in a later roster.                                │
│                                                             │
│ [Enable/repair controls only when the state permits them]    │
└─────────────────────────────────────────────────────────────┘
```

At narrow widths the badge wraps beneath the email, the reason remains a full-width
block, and form controls stack without horizontal scrolling. This is intentionally not a
new dashboard or a decorative card system; the record-like hierarchy is specific to an
officer resolving a membership access question.

## Passkey Explanation

The first-login invitation and member guide must say plainly:

- a passkey is **not another password** and there is nothing new to memorize;
- the person's phone, computer, browser, or password manager stores it safely;
- the person approves sign-in with the same fingerprint, face, device PIN, or password
  manager they already use;
- it is optional, and email sign-in continues to work; and
- most current phones and browsers support it, while a password manager such as
  1Password may also store it but is not required.

The product should remain vendor-neutral. It may explain that password managers can
store passkeys, but it should not imply that a paid product is necessary.

## Verification

Implementation is complete only after:

- model tests cover each roster/manual transition and stored reason;
- importer tests cover account creation plus missing, invalid, shared, and already-used
  emails without leaking the addresses into summaries;
- controller and view tests cover plain-language state and reason copy;
- the full Rails test suite and static checks pass; and
- the People account panel and first-login passkey invitation are reviewed at desktop
  and 390px widths, including focus, wrapping, and overflow.
