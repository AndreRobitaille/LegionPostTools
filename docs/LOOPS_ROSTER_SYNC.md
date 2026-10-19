# Loops Roster Sync Design

## Purpose

Give an administrator a safe, guided way to copy the current American Legion
membership roster into the Post's Loops audience after a successful National
roster import. This replaces a manual CSV handoff while preserving each
contact's email choices in Loops.

## Product Decision

Use Loops' update-contact endpoint as an upsert, with roster email, parsed first and
last name, and the stable `american-legion-member:<member_number>` identity. Resolve
both email and stable identity before writing: reused mailboxes, conflicting identities
and address moves that could move other subscriptions require review.

The request must never include global `subscribed` or `userGroup`. It now patches exactly
one mailing-list key: the configured private **Post members** list. It must not send a
replacement map of all lists. The separate private **Minutes recipients** list belongs
to [minutes distribution](MINUTES_EMAIL_DISTRIBUTION.md), and roster sync never changes
it. Distinct valid list IDs are required; there is no All audience fallback.

Existing global and list opt-outs remain in effect. Read back effective enrollment and
report retained opt-outs truthfully. Keep unsubscribed contacts in Loops; never delete,
recreate or unsuppress them. New contacts use Loops' normal subscription default.

The integration records provenance for its new Post members enrollments. On later runs,
previously managed addresses that are no longer eligible are checked for removal from
**Post members only**. Retain their contact and all other memberships. Missing or changed
identity requires review. Pre-existing list assignments without integration provenance
are not silently claimed or removed. An address move for a still-eligible member also
requires review rather than automatically moving independent minutes subscriptions.

## Membership Selection

Use the application's existing definition of a current member:

- backed by a National member ID;
- present in the latest roster (`roster_removed_at` is blank); and
- roster status is Active or Grace.

Only current members with one usable, unambiguous roster email are eligible.
The preview separately counts members skipped because the email is blank,
invalid, or shared by more than one current member. A shared address is skipped
for every person using it because Loops has one contact per email and choosing
one member's name would be misleading.

## Workflow

1. From the Roster tile or a completed roster-import result, choose
   **Sync email audience**.
2. Review the source import date and four counts: ready, no email, invalid
   email, and shared email. Review the count of previously managed addresses that need
   removal checks, and the statement that only Post members is updated.
3. Start the sync. The work runs in Solid Queue so an officer does not need to
   keep the browser request open.
4. The result page refreshes while work is active, then reports synced and
   failed contacts plus additions, removals, unchanged contacts, retained opt-outs and
   identity/removal review results. Provider errors identify the affected member without
   exposing the API key.

Only `manage_settings` users may preview, start, or view a sync. Only one sync
may be queued or running at a time. A job refuses to use its preview if a newer
roster import has completed in the meantime.

## Failure and Rate-Limit Behavior

- Reuse one HTTPS connection for the run.
- Pace requests below Loops' documented baseline limit of ten requests per
  second.
- Retry an individual HTTP 429 response after the provider's `Retry-After`
  value (or a short default delay), with a bounded retry count.
- Continue after a contact-level rejection and show it in the final result.
- Mark the whole run failed if configuration is missing, the source roster is
  superseded, or an unexpected system/network error prevents the run from
  continuing.

Upserts make a rerun safe: successful contacts may be updated again without
creating duplicates, and the subscription property is still absent.

## Visual Direction

This is an operations checklist for an American Legion officer, not a marketing
dashboard. Compose it from the existing warm-paper card, navy working type,
gold rules, and calm green completion banner. The page's signature is a plain
"Existing email choices stay in Loops" assurance panel placed immediately beside the
start action; it makes the safety invariant visible where the consequential
choice is made.

Use the established sans-serif working UI, bounded form width, four stat tiles,
and navy primary action. At narrow width, stat tiles collapse to two columns,
actions remain easy to tap, and no email address or provider error may force
horizontal scrolling. Red appears only for actual failures; skipped records are
neutral because the tool has intentionally left them unchanged.

This direction deliberately avoids inventing an email-themed palette or a new
dashboard card. The existing roster-result vocabulary better communicates that
the sync is an accountable administrative operation tied to a dated source.

## Verification

- Audience selection tests cover current status, removed records, blank,
  malformed, and shared emails.
- Client tests cover provider errors and rate limiting. The base roster payload omits
  subscription fields; the synchronizer adds only the owned Post members list key.
- Offline sync-to-email tests sync twice, preserve outside minutes recipients and unrelated
  lists, retain opt-outs, flag identity conflicts, and remove former members from only
  Post members before exercising attestation and corrected-copy delivery.
- Job/service tests cover success, partial failure, superseded rosters, and
  terminal failure state.
- Controller tests cover authorization, preview copy, configuration, duplicate
  active-run protection, and enqueue behavior.
- Browser review covers the preview and result pages at desktop and phone
  widths.
