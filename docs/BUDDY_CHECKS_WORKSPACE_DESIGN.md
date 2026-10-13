# Buddy Checks and Membership workspace

The later [coordination and county reporting design](BUDDY_CHECK_COORDINATION_DESIGN.md)
supersedes any placement of Post Buddy Check history under Membership. Check-ins and
county reporting have a separate Buddy Check workspace; renewal/dues remain Membership.

October 12, 2026. Requested by Andre after the mobile Buddy Checks launch exposed
missing website workflows and loosely placed controls. This is implementation design,
not authority to publish or deploy.

## User jobs

An American Legion member making a welfare call needs to choose someone, understand
whether contact is appropriate, prepare the call, record what actually happened, and
keep an agreed callback. A membership leader needs separate renewal work, caller
assignments, payment verification, and meeting reports. Welfare outreach must not be
presented as a dues campaign.

The website and iPhone app use the same saved checks, follow-ups, and deferrals.
Browser operations reuse the existing BuddyChecks services, with normal session
authentication and CSRF protection. No new grants, OAuth behavior, export policy,
official-minute edits, or production data operations are part of this change.

## Information architecture

- **Buddy Checks** becomes a primary destination for the existing pilot capability.
  Its home prioritizes due callbacks and choosing someone to contact. Whole-row
  destinations lead to finding a member, your check history, callbacks, and deferred
  suggestions. Managers also see caller coordination and attendance evidence.
- Preparation shows current eligibility, a member's permitted contact information,
  and your previous checks. A physical call/email link does not record a check.
  Recording, corrections, scheduling, rescheduling, completion, cancellation, and
  deferral changes retain the existing service's ownership, audit, and concurrency rules.
- **Membership** becomes a task directory using the admin hub's layout. Renewal
  follow-up moves to a named destination. Assigned callers see only their tasks.
  Manager destinations group member work, caller coordination, and Post accounting.
- Member detail leads with standing, contact details, next step, and readable history.
  Contact entry is a separate focused page. Payment entry is a named disclosure beside
  its history. Reviewed address controls belong beside contact information.
- Drive pages put caller work first, keep printing with assignments, and group
  assignment administration and closure separately. Purpose-specific explanations
  avoid renewal language on welfare drives.
- Attendance has a clear return route, a meeting context link, readable member rows,
  search, coverage counts, and a save area beside completeness. Missing evidence stays
  unknown. Saving preserves register revisions and never changes minutes.
- Profile groups **Connected apps** with **How you sign in** and **Agent access**.
  The app connection page says what disconnecting does and returns to Profile;
  connection management is not a floating button or the home for outreach.

## Visual direction

Use the frontend-design skill and The 1919 system. The admin redesign is the standard:
bounded 940px workspaces inside the existing shell, whole destination rows, clear
section headings, quiet supporting text, and status next to its action. Navy #0A2240,
gold #C6A15B, cream #F4EEDD, paper #FBF7EC, and ink #1B222B remain the palette.
System sans serves all working screens; no new font or visual brand is introduced.

Two destination columns at desktop collapse in task order at 900px. Focused forms use
the existing form measure. The signature gold edge marks the next outreach task;
routine settings and navigation remain quiet. Body/interactive text is at least 16px,
secondary text 14px, labels 13px, and targets at least 44px. Phone controls stack
without losing their associated status or requiring horizontal scrolling.

## Authority and recovery

Keep the existing enabled pilot gate for browser Buddy Checks and evidence forms.
Membership managers retain their existing broader Membership contact history; the
personal Buddy Checks workspace shows caller-owned facts only. A pilot member without
membership leadership or drive assignments can use their own workspace without gaining
renewal, payment, other callers' notes, or evidence-editing access. Disabled accounts,
revoked pilot grants, expired assignments, paused contact, and stale form submissions
are rechecked on the next action. Failed forms preserve entered values and give a
plain recovery instruction. Unknown historical coverage is never called “never checked.”

## Verification

Use synthetic test data. Exercise a member and membership manager through preparation,
recording, later history, shared mobile reads, scheduling, rescheduling, deferral undo,
and stale/revoked/other-caller boundaries. Preserve renewal, returned-paper, payments,
reports, and consent/revocation regressions. Inspect desktop, tablet, and 390px browser
captures, including empty states, long names, validation errors, and profile connections.
Record actual visual critique and test results separately from this intended design.
