# Membership Meeting Agenda Structure Design

## Summary

The suggested Membership Meeting agenda should resemble the practical order used by an
American Legion Post, not a flattened list copied from every heading in the Officer's
Guide. The supplied Post 165 agenda is the grounding example, while the reusable
suggestion remains configurable for any American Legion Post.

## Product decisions

The suggestion uses these stable, ordered sections:

1. Opening Ceremony
2. Roll Call, Minutes & Guests
3. Reports
4. Sick Call / Service Officer
5. Unfinished Business
6. New Business
7. Good of The American Legion & Announcements
8. Closing Ceremony & Adjournment

The catalog and template classify items by their function in the meeting:

- Opening and closing ritual remain distinct from the order of business.
- Roll call, approval of minutes, and introductions share one short procedural section.
- Common officer reports and a broad Programs & Activities report slot share Reports.
- Sick Call and the Service Officer report remain together.
- Unfinished Business is limited to unresolved decisions from an earlier meeting. The
  term "Old Business" is not used.
- New Business is for matters that need a new decision or authorization. Correspondence
  is not automatically classified as New Business.
- Good of The American Legion remains member-oriented; announcements hold dates,
  reminders, locations, deadlines, and other information that requires no decision.

Recurring local work such as Buddy Checks, a car show, brat fry, newsletter, raffle,
scholarships, or memorial activities is not hard-coded into the reusable suggestion.
Officers can put that meeting's details into Programs & Activities, add appropriate
catalog or tracked items, and split a requested decision into New Business.

## Catalog changes

The regular-meeting catalog gains reusable items for the opening and closing transitions,
common officer reports, Programs & Activities, and Announcements. Existing items with
broader or outdated officer-facing names are clarified when their seeded wording is still
untouched. Re-seeding must preserve fields an officer has edited locally.

The aggregate Opening Ceremony and Closing Ceremony catalog entries remain available for
Posts that prefer a compact agenda, but the suggested Membership Meeting uses the more
useful ordered component items and does not duplicate the aggregate entries.

## Existing data and authenticity

- A new or explicitly reset suggested Membership Meeting receives the corrected structure.
- Re-seeding remains additive and does not silently delete local template changes.
- Existing dated agendas are snapshots and are never rewritten.
- Ceremony text supplied as established Legion wording is preserved. Post name,
  Department, roster, dates, places, URLs, programs, and decisions are not hard-coded.

## Visual direction

This follows the established "The 1919" agenda system rather than introducing a new UI.
The structural numbering is meaningful: the existing navy-and-gold numbered chapter cards
in the editor and order rail in the published agenda should now expose the actual eight-part
meeting sequence. The visual palette, typography, controls, and responsive behavior remain
unchanged.

The signature is the order itself: a member can scan from ceremony, through reports and
decisions, to adjournment without learning a new interface. Additional decoration or
subsection styling would imply hierarchy the current two-level data model does not store,
so it is intentionally omitted.

## Verification

- Service tests assert the exact section and item order for a fresh suggestion.
- Catalog tests assert the expanded reusable baseline, safe upgrades, idempotence, and
  preservation of local edits.
- Reset tests establish that the corrected suggestion can be applied deliberately.
- The Membership Meeting editor is reviewed at desktop and narrow widths after the local
  suggestion is reset; the eight-section order must remain readable without horizontal
  overflow.
