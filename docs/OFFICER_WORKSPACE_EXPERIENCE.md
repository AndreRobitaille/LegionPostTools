# Officer Workspace Experience

**Status:** Accepted for implementation on September 1, 2026.

## Product boundary

An American Legion office and technical application administration are different kinds
of authority. A current Adjutant may need complete roster visibility, meeting scheduling,
agenda preparation, minutes drafting, and personal attestation authority without being
able to manage accounts, permissions, installation settings, or other administrators.

The interface must make that distinction visible. Scoped officers should not appear to be
ordinary members after receiving meeting duties, and they should not be told they are
administrators when they are not.

## Access model

- A configured current Post assignment may supply membership-information access. Post 165
  configures Commander, 1st Vice Commander, and Adjutant this way.
- A position may also supply narrowly configured application capabilities while its dated
  assignment is current. The standard American Legion Post policy is:

  | Position | Membership access | Position-provided capabilities |
  | --- | --- | --- |
  | Commander | Full membership and renewal information | `manage_agendas`, `manage_minutes`, `approve_minutes`, `record_minutes_approval` |
  | Adjutant | Full membership and renewal information | `manage_agendas`, `manage_minutes`, `attest_minutes`, `record_minutes_approval` |
  | 1st Vice Commander | Full membership and renewal information | None |
  | Every other standard position | Member directory | None |

- Position-provided authority begins on the assignment's start date, remains through its
  inclusive end date, and ends automatically when the assignment expires, the position is
  deactivated, or the assignment is removed. No copied per-user grant is created.
- Explicit application grants remain available for duties that do not arise from a current
  Post office. They are independent exceptions and do not expire with an assignment.
- `manage_settings` remains technical-administrator authority. It is not required for
  ordinary Adjutant work and does not imply personal official-record acts.
- The interface identifies whether authority comes from a current office or a manual grant.
  It never infers authority from title wording; position capability records survive harmless
  renaming and remain configurable for other installations.
- The private agenda copy containing Commander cues and the working officer roll call is
  limited to current Commander and Adjutant assignments. Other officers use the same
  member-safe agenda and published/attested minutes documents as standard members.
- Full-roster CSV export is not currently implemented. If added, it will use the same full
  membership-access boundary, so a current 1st Vice Commander can export without receiving
  meeting or technical-administrator powers.

## Interface direction

Continue the established “The 1919” navy, gold, cream, and paper system. The officer
workspace is distinguished by language and one compact duty placard, not a second visual
brand.

```text
OFFICER TOOLS
Choose the work you need to do for your Post.

+------------------------------------------------------+
| SCOPED OFFICER ACCESS · ADJUTANT · FINANCE OFFICER  |
| Account and system settings remain with            |
| application administrators.                        |
+------------------------------------------------------+

MEETING WORK
Meetings
Manage Endeavors

AGENDA SETUP
Agenda catalog
Meeting types

OPERATIONS
Background Jobs
```

The October 12 navigation change gives **Officer tools** its own `/officer-tools`
hub. Open **Menu → Post duties → Officer tools**. Membership leadership, including
the current 1st Vice Commander, can reach Membership here without agenda or settings
permissions. Scoped agenda/minutes managers, publishers, record viewers, and people
with personal minutes-action grants see only the work their authority permits.

**Menu → Application settings → Administration** opens `/admin` for settings
administrators. A person with both kinds of authority sees both hubs. Old `/admin`
bookmarks redirect scoped officers to Officer tools. Account management, roster
imports, Post-position configuration, website connections, agent access, and technical
maintenance remain in Administration. Publishing remains an officer task with its
existing `publish_public_content` guard.

Both hubs retain the October 11 redesign's readable whole-row destinations, semantic
headings, and visible keyboard focus. Officer tools groups Meeting work, Membership, Buddy Checks,
Agenda setup, Public website, and Processing as permitted. Actual current role names
appear in its compact Post duties placard; manual grants do not invent officer titles.
A single destination column uses a narrower measure, and phone layouts stack in task
order. Missing and overdue rosters keep one attention area beside the import actions
in Administration. Empty and unauthorized groups are omitted.

Back links from operational meeting pages, meeting templates, the agenda catalog,
and Endeavor management return to Officer tools. Settings pages return to
Administration. Background Jobs retains its existing settings/agenda/minutes guard;
its return destination follows the viewer's workspace. A record viewer gets Meetings
without Jobs. Personal approval/attestation authority links to shared Meeting records
without granting access to internal meeting management.

Desktop navigation keeps Dashboard, Calendar, Meetings, Endeavors, and People.
On phones the same destinations appear under **Menu → Member site**. **Your work**
contains Buddy Checks (calling or coordination) and assigned calls when permitted;
Profile and Sign out stay under **Your account**. Menu scrolls within a short viewport,
with 16-pixel interactive text, 44-pixel targets, and keyboard navigation that skips
hidden desktop duplicates. See [the current menu design](MENU_AND_WORKSPACE_DESIGN.md)
and [the earlier hub design](ADMIN_WORKSPACE_DESIGN.md).

The current [minutes policy](MINUTES_APPROVAL_AND_ATTESTATION.md) allows either officer
to prepare/edit minutes and record the real later-Meeting approval. Commander handoff
preserves a drafting milestone; Adjutant attestation shares the reviewed copy with members.
The policy and [turnover verification](OFFICER_AUTHORITY_VERIFICATION.md) supersede the
older table's omission of Commander drafting and both officers' approval recording.

## Original Clarice Hagen correction

The original installation correction recorded that Clarice's then-current Adjutant
assignment supplied full membership access, `manage_agendas`, `manage_minutes`, and
`attest_minutes`. Those capabilities end with the Adjutant assignment; her account does
not retain duplicate manual grants and does not receive `manage_settings` or
`manage_people`. This is historical installation context, not verification of current
production assignments. The standard policy now also includes `record_minutes_approval`.

## Manage Endeavors

Users with `manage_agendas` can open **Manage Endeavors** from **Officer tools** or the Endeavors list. The overview shows active and completed Endeavors, each
history's processing state and last publication time, and attention/status filters.
**Manage history** opens the existing per-Endeavor controls for refresh, guidance,
withdrawal/resume, and run inspection. Ordinary members cannot see these links or open
this overview. Viewing/filtering starts no AI calls. See
[management overview design](ENDEAVOR_MANAGEMENT_OVERVIEW.md).


## Calendar and next-step management

Calendar managers use the central Manage calendar page or add/edit events from an
Endeavor. The policy is administrative settings access or current Commander/Adjutant
position-derived authority; a manual manage_agendas grant alone does not qualify. Events
can be members-only or public and can be cancelled/restored, including past events.
Existing Meeting edits retain their own agenda and official-record safeguards.

Endeavor editors with manage_agendas can add/edit next steps, set optional due dates,
complete/reopen steps, and edit the optional overall project deadline. These actions do
not complete/cancel other records or rewrite meeting history. The matching private API
uses the same policies and optimistic lock protection; see `CALENDAR_API.md`.
