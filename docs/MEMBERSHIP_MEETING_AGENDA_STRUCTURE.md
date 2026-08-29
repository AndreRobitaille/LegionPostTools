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

These are real agenda sections. They are the stable first level of the meeting record;
catalog and tracked items are placed beneath them as the second level. Unfinished Business
and New Business are therefore not same-named placeholder items inside same-named
sections. A dated agenda may leave either section empty until specific business is added.

Item detail does not create a third structural level. Ordinary supporting detail—such as
balances, receipts, bills, and an attachment note beneath the Finance Officer Report—lives
in that dated item's rich-text wording. Anything needing independent order, follow-up,
tracking, or a planned vote becomes its own agenda item. Future minutes may attach typed
outcomes such as narrative, motions, decisions, and attachments to an item without turning
the agenda into a recursive outline.

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

The earlier all-in-one ceremony entries are not used as shortcuts. **Call the Meeting to
Order** holds only the initial presiding cues before the distinct opening steps, and the
redundant aggregate Closing Ceremony is omitted in favor of its distinct closing steps.

The catalog is a source library, not the meeting's section structure. Its grouping is
labeled **Usually used under** and follows the practical meeting sequence:

1. Opening Ceremony
2. Roll Call, Minutes & Guests
3. Reports
4. Sick Call & Service
5. Unfinished Business
6. New Business
7. Good of The American Legion & Announcements
8. Closing Ceremony & Adjournment
9. Special & As Needed

The grouping helps an officer find an item but never prevents placing it in a different
section. Empty groups remain visible in the catalog so a locally added item always has an
obvious destination.

## Catalog wording baseline

The production-edited Post 165 catalog is the grounding example for the reusable wording
baseline. The reusable seed keeps the Post's practical distinctions without copying local
names, dates, events, or decisions:

- **Summary or guidance** is the concise description officers scan while building an
  agenda. When an item has no document wording, it is also the short member-facing
  explanation.
- **Document wording** is reserved for text that may actually be distributed or carried
  into draft minutes. Routine instructions and report prompts do not need duplicate body
  text when the summary already says the job clearly.
- **Commander's script / cues** holds presiding directions and spoken ceremony text that
  members do not need in their copy. Opening, colors, POW/MIA, and adjournment cues belong
  here rather than in distributable wording.
- The Pledge and Chaplain's Prayer wording are omitted from the member agenda and draft
  minutes by default. The Preamble remains available on the member agenda but is not
  carried into draft minutes.
- The redundant aggregate Closing Ceremony and the Unfinished Business/New Business
  placeholders are no longer part of a fresh catalog. Distinct ceremony steps remain
  available. Existing dated-agenda snapshots are never rewritten by reseeding.

This revision changes fresh seed defaults and safe upgrades of recognizable earlier seed
wording. It does not rewrite meeting-type items or dated-agenda snapshots.

## Catalog classification

Catalog placement and item kind now have separate, limited jobs.

- Catalog placement now describes the section under which an item is usually used rather
  than mixing sequence, subject matter, and work type.
- Behavior type is presented as **Item kind**. It describes item-level workflow; it cannot
  create section hierarchy. The legacy `section_heading` value remains readable only for
  historical compatibility and is not offered for new or updated items.
- Officer roll call remains the only materially specialized behavior today. Report,
  motion/decision, ceremony, and reading kinds retain useful intent for the future minutes
  workflow without changing the two-level agenda structure.

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

Every main section remains visible in member and Commander documents even when no item has
yet been scheduled beneath it. An empty section receives one quiet, full-size line—**No
items listed in advance.** This preserves the recognizable order of business without
inventing a fake agenda item or suggesting that business cannot be raised during the
meeting.

## Verification

- Service tests assert the exact section and item order for a fresh suggestion.
- Catalog tests assert the expanded reusable baseline, safe upgrades, idempotence, and
  preservation of local edits.
- Reset tests establish that the corrected suggestion can be applied deliberately.
- The Membership Meeting editor is reviewed at desktop and narrow widths after the local
  suggestion is reset; the eight-section order must remain readable without horizontal
  overflow.
