# National roster email reconciliation

## Product decision (November 8, 2026)

National's imported email is authoritative for a member's Loops contact and website
login. Match people by Member ID, keep the existing account and its permissions,
and replace its login email during import when National supplies a valid, unique
address not used by another account. Reimporting an unchanged roster must also
repair existing mismatches. A prior choice to keep another login address does not
override a later import. Manual sign-in disables remain in force.

Blank, invalid, shared, or occupied addresses leave the existing login email in
place and produce a named import problem. Never assign another person's account
to a member. Reset email verification and invalidate outstanding emailed sign-in
and reauthentication challenges when changing the login email. Existing sessions,
passkeys, permissions and user identity continue to belong to the same member.
No email is sent by importing.

Loops synchronization remains an explicit step after import. Move the existing
contact by its stable National member identity, so the old address disappears and
subscriptions and opt-outs follow the new address. Retire the old local enrollment
only after confirming the same contact at its new address. Recover interrupted
moves on retry. Two different contacts or another member's identity still require
review; National's authoritative address alone does not prove those contacts can
be merged. Keep independently managed office records and saved minutes deliveries.

Departed members (missing from the latest roster) and Deceased members lose website
sign-in and are globally unsubscribed in Loops when the sync runs, even if their
contact predates roster-sync provenance. Remove their Post members enrollment but
retain the contact, other list assignments and email history. Minutes delivery must
honor the global opt-out before sending. Match stable identity first; a legacy
contact can be matched by a unique National email with no conflicting member ID.
Ambiguous identities remain visible for review. Expired and unsupported statuses
retain the existing Post members removal policy; they are not departures by
themselves. A returning member stays globally opted out until independently
resubscribed. The last-administrator sign-in safeguard remains in effect.

This supersedes older guidance that imports preserve existing login emails.
Deployment and live reconciliation are separate operations.

## Visual direction

Reuse The 1919 import guidance and Sign-in access panel: navy #0A2240, cream
#F4EEDD, paper #FBF7EC, gold #C6A15B and muted #6b7684. Keep system sans working
text and uppercase section labels. Add one plain statement beside the upload
action and counts for updated or unresolved login addresses in the existing
results panel. Retain current type sizes, bounded columns and stacked phone
layout. Verify desktop and 390px wrapping without adding controls or density.

## Verification

Use synthetic imports and offline Loops contacts. Exercise address changes,
unchanged-source reimports, opt-outs, same-contact provenance, interruption/retry,
later roster removal, manual disables, blank/invalid/shared/occupied addresses,
old emailed challenges and subsequent sign-in at the new address. Assert saved
identity and permissions, import results and the later sign-in request. Do not
import the attached real-member file into a test or development database.
