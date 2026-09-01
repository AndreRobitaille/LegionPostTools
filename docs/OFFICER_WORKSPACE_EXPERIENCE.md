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
  | Commander | Full membership and renewal information | `manage_agendas`, `approve_minutes` |
  | Adjutant | Full membership and renewal information | `manage_agendas`, `manage_minutes`, `attest_minutes` |
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
- Full-roster CSV export is not currently implemented. If added, it will use the same full
  membership-access boundary, so a current 1st Vice Commander can export without receiving
  meeting or technical-administrator powers.

## Interface direction

Continue the established “The 1919” navy, gold, cream, and paper system. The officer
workspace is distinguished by language and one compact duty placard, not a second visual
brand.

```text
OFFICER TOOLS
Meeting preparation and records for your Post duties.

+------------------------------------------------------+
| SCOPED OFFICER ACCESS · ADJUTANT · FINANCE OFFICER  |
| Meeting and records tools are available. Account    |
| and system settings remain with administrators.     |
+------------------------------------------------------+

MEETING WORK
[Background Jobs] [Agenda Catalog] [Meeting Types] [Meetings]
```

- Navigation says **Officer tools** for a person with scoped operational capabilities and
  **Admin** for a person with `manage_settings`.
- The page title says **Officer tools** or **Administration** using the same boundary.
- Scoped officers see a plain explanation of what is available and what remains outside
  their authority.
- Back links from meeting templates and the agenda catalog return scoped officers to
  **Officer tools**, not the member Dashboard.
- Mobile and desktop layouts retain 16-pixel interactive text, 44-pixel targets, visible
  focus, and no horizontal overflow.

## Clarice Hagen correction

Clarice's current Adjutant assignment already supplies full membership access. Her
current assignment also supplies `manage_agendas`, `manage_minutes`, and
`attest_minutes`. Those capabilities end with the Adjutant assignment; her account does
not retain duplicate manual grants and does not receive `manage_settings` or
`manage_people`.
