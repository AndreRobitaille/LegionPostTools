# Roster membership and changed email reconciliation

November 8 update: [National roster email reconciliation](NATIONAL_ROSTER_EMAIL_RECONCILIATION.md)
supersedes the independent-login-email and Post-members-only departure policy below.
National now supplies the login email on import. Departed and Deceased members
lose sign-in and are globally unsubscribed during Loops sync; existing opt-outs remain.

## Expected behavior

An officer reviewing People must be able to distinguish a current Post member from
a person retained for history after leaving the National roster. A missing member
keeps their last imported status and paid-through year as historical source data;
their displayed membership status is **Removed from roster**. This applies whether
or not they have a login account. Active/Grace filters exclude removed people, and
a Removed from roster filter finds them. A subsequent import that restores the
member restores their current status. Existing sign-in and directory rules stay in
force; removal does not delete people or their records.

When a current member's National email changes, update their existing Loops contact
using its stable National member identity. Andre confirmed that the contact's other
mailing-list subscriptions should follow that address change. Preserve the contact
ID, global subscription choice, and every mailing-list choice. Do not merge two
contacts, overwrite another member's identity, delete/recreate contacts, or change
suppression settings. If the destination email already belongs to another contact,
report an identity conflict for review.

Record the confirmed new address as the managed enrollment and retire previous
addresses for that same contact and National identity. A retry after a provider
update but before local persistence must recover this provenance. Later removal
from the roster must remove only the managed Post members enrollment at the new
address. Website login emails and independently managed minutes office records are
separate records; this change does not rewrite them or saved delivery destinations.

## Visual direction

Keep The 1919 working screens: navy #0A2240, cream #F4EEDD, paper #FBF7EC,
gold #C6A15B, and muted #6b7684. Use the established system sans for working text
and tracked uppercase section labels; serif remains reserved for documents.
Reuse the existing member rows, status dot, filters and roster panel. The distinctive
signal is a calm **Removed from roster** status beside the retained member identity,
with the removal date and **Last imported status** on the detail page. Preserve
existing type sizes and stacked narrow layouts. No new palette, controls, or warning
banner is needed for a known removal.

Update the existing Loops preview's identity explanation to make address changes
and preserved subscriptions clear beside the sync action. Show confirmed email
changes in the existing result counts. Critique desktop and 390px renderings for
wrapping, readability and horizontal overflow.

## Verification

Use synthetic roster imports to remove people with and without accounts, read
their People rows/details, filter them, and restore them through a later import.
Check that ordinary members still cannot access removed records. Exercise an
offline Loops provider with stable-ID email updates, independent subscriptions,
opt-outs, occupied destination addresses, interruption/retry, and later removal.
Provider substitutes establish request and recovery behavior, not live acceptance.
