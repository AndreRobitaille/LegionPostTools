# Commander Agenda, Document Wording, and Roll Call Design

## Purpose

An American Legion agenda serves two related audiences. Members need a concise order of
business, while the Commander needs the exact cues and spoken text required to preside
confidently. The Adjutant also needs a compact roll-call worksheet. Putting all three jobs
in the published wording makes the member document long and makes the working document
harder to use.

This feature keeps one structured agenda while producing two deliberate copies:

- the **member agenda**, containing only content intended for distribution; and
- the **Commander's copy**, containing the member agenda plus private presiding cues and
  a compact officer roll-call worksheet.

The page's single job is to let an officer decide, without ambiguity, what members will
read and what the Commander will use to lead the meeting.

## Product Decisions

Every agenda item owns four independent document controls:

- **Document wording**: the existing rich-text wording.
- **Show wording on agenda**: checked by default. When clear, the item title remains but
  document wording is omitted from member and Commander agenda bodies.
- **Carry wording into draft minutes**: checked by default. It records the officer's
  intent for the later minutes-drafting workflow; accepted minutes remain human-approved
  records and will not be mechanically rewritten.
- **Commander's script / cues**: private rich text rendered only in the Commander's copy.

Screen and print versions of a given copy have the same content. There are no independent
digital-versus-print visibility switches.

### Complete agenda-item field guide

| Field | How it is used |
|---|---|
| **Title** | Concise item heading. It remains visible when document wording is hidden. |
| **Summary or guidance** | Short officer-facing guidance in catalog, template, and agenda builders. If a dated item has no document wording, the signed-in on-screen member agenda may use the summary as a fallback. Member print and Commander copies suppress that fallback. |
| **Usually used under / category** | Catalog grouping and ordering only. It helps officers find a reusable item but does not choose the actual section on a meeting template or dated agenda. |
| **Agenda section** | The actual first-level placement for a template or dated snapshot. Moving an item places it at the end of the selected section. |
| **Item kind / behavior type** | Records item-level workflow intent, not hierarchy. Officer roll call is specialized today; report, motion/decision, ceremony, and reading kinds preserve intent for later minutes work. Legacy section headings are historical compatibility only. |
| **Active** | At catalog level, hides an item from Add-item choices without removing it. At meeting-type level, omits it from future dated agendas. Neither setting rewrites an existing dated snapshot. |
| **Document wording / `body`** | Rich member/minutes content. The API accepts `body` on writes and returns plain text as `wording` on reads. |
| **Show wording on agenda** | When clear, keeps the title but removes document wording from member and Commander screen/print agenda bodies. Commander cues remain separate. |
| **Carry wording into draft minutes** | Controls whether the document wording seeds an independent `agenda_wording` snapshot when working minutes are created. It has no approval effect. |
| **Commander's script / cues** | Private script, stage directions, and reminders for the Commander's working copy and private officer API only. |
| **Endeavor link** | Connects an independent dated snapshot to coherent continuing Post work. Linking an existing row in place does not replace its historical title, summary, wording, section, or position. |
| **Position** | Order inside the catalog category or actual agenda section. It is not a global agenda order. |
| **Lock version** | Dated-item concurrency guard. API clients send the value returned by agenda detail when editing content to avoid overwriting another officer's save. |
| **Seed/provenance fields** | Slug, source keys/labels, seeded timestamps, and catalog-removal timestamps are app-managed metadata, not agenda content. |

The values follow the established snapshot boundary:

```text
Agenda Item Catalog        Meeting Type Item        Dated Agenda Item
post-wide defaults    -->  template overrides  -->  independent meeting snapshot
```

Changing a catalog entry does not rewrite a template or dated agenda. Changing a meeting
type does not rewrite an existing dated agenda. Approval and publication continue to lock
the dated snapshot.

## Roll Call

`Roll Call and Quorum` is a dedicated behavior, not a rich-text roster. When a dated
agenda containing that behavior is created, it snapshots the Post's officer structure as
of the meeting date:

- every active position title required by default;
- every other active position title with an assignment active on the meeting date;
- active assignments ordered by the configured position-title display order;
- a visible `Vacant` row when a required office has no active assignment; and
- one row per person when an office has more than one active assignee.

Each row preserves source references where available plus the displayed office and person
names. Later roster or assignment changes cannot alter an approved or historical agenda.
While the agenda is a draft, an officer can refresh the snapshot explicitly; the action
states that it replaces the current roll-call worksheet.

The assignment snapshot is a useful starting point, not the only way to construct the
worksheet. A draft agenda also provides an agenda-local officer-list editor. This supports
reconstructing a past meeting when effective-dated assignments were not recorded in the
application, and exceptional meetings whose roll call differed from the standing officer
assignments. An editor may:

- choose any existing person for an office;
- leave an office visibly `Vacant`;
- remove a row that did not belong on that meeting's roll call; and
- add another active Post position, including a vacant position.

These edits change only the dated agenda snapshot. They never rewrite a person's Post-role
history or become defaults for a later agenda. “Reload assigned officers” remains available
as an explicit reset and warns that it discards agenda-local changes.

The member agenda shows the `Roll Call and Quorum` item like any other item but never shows
blank attendance controls. The Commander's copy renders a compact table with Present,
Absent, and Excused boxes. These boxes are a paper worksheet in this milestone. Recorded
attendance belongs to the later minutes lifecycle rather than mutating a published agenda.

## Access and Safety

- Member agenda routes never render Commander's script or roll-call rows.
- Commander's copy routes require `manage_agendas`, matching agenda editing authority.
- Private API detail exposes the script and document controls only under the existing
  `manage_agendas` gate; member-facing endpoints do not. It includes roll-call entry,
  position-title, and person ids so a delegated Bot can edit the meeting snapshot without
  matching historical officers by display text.
- Roll-call rows are organization-scoped through their dated agenda and may be regenerated
  or edited only while that agenda is a draft.
- Agenda-local roll-call editing requires `manage_agendas`; it does not grant authority to
  change officer assignments or assignment-derived membership access.
- The officer API can replace the complete list on a draft. Its separate refresh action is
  listed only when asked because it discards agenda-local edits and rebuilds from assignments
  active on the meeting date—not from today's `/api/officers` response.
- Existing records are backfilled with both document controls checked, preserving current
  output after migration.

## Editor UX

The item editor groups controls by the document they affect instead of presenting one long
undifferentiated form:

```text
+----------------------------------------------------------------+
| ITEM DETAILS                                                   |
| Agenda section / Title / Summary / Behavior                    |
+----------------------------------------------------------------+
| MEMBER AND MINUTES WORDING                                     |
| [ rich-text document wording ]                                 |
| [x] Show this wording on the agenda                            |
| [x] Carry this wording into draft minutes                      |
+----------------------------------------------------------------+
| COMMANDER'S COPY                         FOR OFFICERS ONLY      |
| [ rich-text presiding script and cues ]                        |
| This never appears on the member agenda.                       |
+----------------------------------------------------------------+
```

Agenda-builder rows use quiet status chips only when they communicate an exception:
`Agenda wording hidden`, `Minutes wording hidden`, or `Commander script`. Ordinary defaults
do not receive badges, keeping the meeting order scannable.

For a roll-call item, `Edit officer list` opens a dedicated meeting-scoped worksheet:

```text
+----------------------------------------------------------------+
| OFFICERS FOR JULY 7, 2026                                      |
| This list belongs only to this agenda.                         |
+----------------------------------------------------------------+
| Office                  Officer                                |
| Commander               [ Pat Commander                    v ] |
| Adjutant                [ Vacant                          v ]   |
| Historian               [ Alex Member                     v ]  |
|                          [ ] Remove this row                    |
+----------------------------------------------------------------+
| ADD AN OFFICE                                                   |
| [ Service Officer v ]   [ Jordan Member v ]                    |
+----------------------------------------------------------------+
| [Save officer list]          [Reload assigned officers]         |
+----------------------------------------------------------------+
```

The page distinguishes `Vacant` from removal: vacant preserves the office on the worksheet,
while removal omits the row from this meeting. Existing people are chosen by name so the
saved row continues to preserve both its reference and displayed snapshot name.

The agenda lifecycle actions distinguish **Print member agenda** from **Commander's copy**.
The latter is visually an internal working document and must never be described as the
published agenda.

## Visual Direction

This follows the established “The 1919” document system rather than introducing a second
design language.

### Tokens and type

- Authority navy `#0A2240`
- Working navy `#0D2C54`
- Legion gold `#C6A15B`
- Document ivory `#FCFAF1`
- Officer blue `#2F5F87`
- Graphite `#303740`

Georgia remains the document and spoken-text face. The application system sans remains the
control and utility face. Small status labels use uppercase sans with deliberate tracking;
they never replace plain-language labels.

### Signature

The one new visual signature is the **blue officer cue**: a left-ruled, pale-blue script
panel that resembles a careful annotation on a formal order of business without imitating
handwriting. It is visibly separate from distributable wording and remains legible in
grayscale. The existing gold order rail remains the dominant agenda structure.

The roll call uses a compact ruled table based on an Adjutant's paper worksheet. It avoids
cards, oversized checkboxes, decorative icons, and repeated officer labels that would waste
paper.

The editor extends that worksheet metaphor with quiet horizontal rules and a narrow gold
meeting-date rail. The established application sans remains the form typeface; office names
use navy weight rather than introducing a decorative face. This is intentionally a working
record, not another dashboard or a miniature version of the ceremonial print document.

### Commander document

```text
               COMMANDER'S WORKING COPY
                  Meeting title / date
                        ◆
 [1] Opening Ceremony
     Colors & Hand Salute
     Member wording, when enabled
     | COMMANDER'S CUE
     | Three raps. All rise. "Hand salute." ...

 [2] Roll Call, Minutes & Guests
     +------------------+----------------+---+---+---+
     | Office           | Officer        | P | A | E |
     +------------------+----------------+---+---+---+
```

At narrow widths, document controls stack, the script panel remains inside the content
column, and the roll-call worksheet changes from a wide table to compact officer rows with
three labeled boxes. No horizontal overflow is permitted at 390px. Print keeps the table,
prevents individual officer rows from splitting, and uses white paper with print-safe rules.

## Design Critique

An initial direction used three large colored cards for wording, minutes, and Commander
notes. That made a frequently used officer form feel like a generic configuration
dashboard and gave defaults as much visual weight as exceptions. The revised form uses
document-purpose fieldsets and spends color only on the private Commander boundary.

A handwritten-note treatment was also rejected. Script text can be long and must remain
comfortable for older readers; handwriting would reduce legibility and make an official
working document feel theatrical. The blue rule provides the intended annotation cue
without sacrificing clarity.

## Verification

- Model and controller coverage confirms defaults, three-level copying, locks, private
  visibility, roll-call snapshot date rules, vacancies, agenda-local edits, refresh behavior,
  and API payloads.
- System coverage confirms the editor vocabulary and both print actions.
- Browser critique covers the dated-agenda editor, officer-list editor, member agenda, and
  Commander's copy at desktop and 390px widths, including keyboard focus and horizontal
  overflow.
- Printed output is inspected for hidden member content, visible Commander cues, compact
  roll call, grayscale legibility, and reasonable page-break behavior.
