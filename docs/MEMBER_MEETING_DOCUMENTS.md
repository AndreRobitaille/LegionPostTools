# Member Agenda and Minutes Presentation

## Scope and decisions (October 4, 2026)

Members read the published agenda and attested minutes as a consistent family of
American Legion meeting documents. Use the existing agenda's quiet paper layout for
both. Member HTML and its PDF copy share this document; administrative workspaces,
officer previews and PDFs, record content, and approval workflows retain their
existing behavior.

An agenda retains its ordered sections, item titles, eligible wording, and summary
fallbacks. Honor each item's existing member-wording setting. Commander notes and
private roll-call working fields remain outside the member agenda.

Minutes retain every section, item, agenda wording, recorded narrative, motion,
decision, mover, seconder, result, vote note, and officer attendance entry. Read all
record content from the exact member-visible immutable revision, including its
title, meeting body, date, and location. Reopened working drafts and un-attested
Commander handoffs must never replace that member-visible revision.
When several revisions are attested, an in-progress correction displays the latest
attested revision, regardless of the chronological ordering used in record history.

## Visual direction

The audience is Post members, including older readers with limited computer confidence.
The page's job is to make the meeting's business easy to read and its authority clear.
Reuse The 1919 palette: navy #0A2240, gold #C6A15B, paper #FFFFFF, cream #F4EEDD,
officer blue #2F5F87, and completion green #3F6B3F. Georgia carries the document;
system sans carries dates, labels, status, and navigation.

Reuse the actual existing agenda document template with its spacing, title treatment,
section gutter, and item hierarchy. Do not give either member document a new card-based
look or expand the section-title scale. One bounded, centered paper holds the emblem
and configured Post identity, saved meeting location, document title and date, and
ordered business. Roman section
numbers and lettered items express parliamentary order. Avoid repeating the title,
separate revision cards, and large endorsement panels.

Minutes show one plain status near the title: awaiting meeting approval, correction
in progress, approved with corrections while the final copy is prepared, or the
recorded final approval. Explain which copy members are reading. Electronic
attestation closes the record; expandable record details retain historical Commander
handoff, revision/digest, and approval provenance.
Approval information is a quiet text block in the document, not a large colored panel.

The member minutes page offers **Open minutes PDF**, in the same action bar as the
agenda PDF. Its authenticated endpoint selects the member-visible attested revision;
the short-lived loopback rendering token fixes that revision and rejects drafts,
other records, and superseded revisions. Reopened or pending corrections still print
the last attested copy with the same truthful status shown on the member web page.
Final approved minutes print the locked approved revision. Reuse the member document
under the existing print layout and PDF resource policy; preserve the officer PDF route.

Below the Recorded minutes label, a simple 3px officer-blue line and modest left
padding distinguish the recorded narrative from agenda wording, matching the supplied
PDF example. Meeting document cards give only the Open label and arrow a subtle
blue/gold text glow on hover and keyboard focus. Keep their existing focus outline,
readable navy text, and stable layout; neither the label nor arrow is underlined.

Member reading text is at least 16px, secondary text at least 14px, and labels at
least 13px. At 390px the letterhead and outcome facts stack, attendance wraps,
controls retain usable targets, and the page does not scroll horizontally. Preserve
nested list markers, emphasis, quotations, links, and paragraph spacing. Member-only
styles must not affect administrative pages or their PDFs.

## Verification

Check attested, final-approved, reopened, and pending-correction records. Confirm
member HTML always renders the attested revision and excludes working edits and
private agenda notes. Verify full recorded outcomes and attendance, safe HTML, and
revision digest preservation. Review real browser renders at desktop and 390px,
including nested lists, long motion text, keyboard access to record details, and
print styling. Compare administrative rendering before and after the member changes.
Verify member PDF authentication, inline delivery, error recovery, revision selection
during corrections, token scope, and real Chromium output without embedded resource loads.
