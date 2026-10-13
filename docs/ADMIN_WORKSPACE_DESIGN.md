# Administration and Officer tools

The [October 12 menu design](MENU_AND_WORKSPACE_DESIGN.md) supersedes the combined
hub and navigation naming described here. The destination-row visual system remains
current; Officer tools and Administration now have separate hubs.

Design for GitHub issue #64, October 11, 2026.

## Page job and scope

Help American Legion officers and application administrators find their authorized
work quickly. Meeting work comes first. Routine destinations stay quiet; an overdue
or missing National roster has one clear status and a nearby import action. Preserve
the distinction between Post duties and technical administration.

This change covers the hub and its existing destinations. AI accounting, new record
workflows, tenant switching, and the member dashboard belong to separate work.

## Visual direction

Use The 1919 system and the frontend-design skill. Keep navy `#0A2240`, gold `#C6A15B`,
cream `#F4EEDD`, paper `#FBF7EC`, ink `#1B222B`, and the existing warm rule tokens.
System sans serves titles, destination names, and explanatory text. The shared diamond
section heading retains tracked capitals. Serif remains reserved for documents.

The signature is a restrained gold edge on the Meeting work destination list, with
the same gold used for roster attention. Spend emphasis on the work officers do most
often rather than on decorative icons or repeated action buttons. Whole destination
rows are links, with a visible arrow, generous hit area, and an explicit focus outline.

Use the existing bounded working measure (940px inside the 1060px shell). At desktop
width, stack Meeting work, Agenda setup, and Operations in the left column; People and
roster, Public website, and Access occupy the right column. At 900px and below, show one
ordered column, with the meeting tools first. A workspace with only one column uses the
bounded 660px form measure. Rows retain title and description; phone layout must not
squeeze text to fit. Body/action text stays at least 16px, descriptions 14px, and labels 13px.
Every link has at least a 44px target. No animation or new font is needed.

```text
Administration / Officer tools
Choose the work you need to do for your Post.
[Compact explanation of scoped duties, when applicable]

[Needs attention: missing/overdue roster + Import roster]

Meeting work                 People and roster
  Meetings                     Import roster + current status
  Manage Endeavors             Import history
Agenda setup                   Sync email audience
  Agenda catalog               Post positions
  Meeting types              Public website
Operations                     Publishing
  Background Jobs              Website connections
                             Access
                               Administrators
                               Agent access
```

This is a destination directory, not a queue of speculative tasks. Omit the attention
area when the roster is current, and omit unauthorized destinations and empty groups.
Current roster information remains beside the import destination. A publisher-only
workspace can contain just Public website; it should not stretch a single group across
the entire desktop shell.

The alternative of another tile grid repeats the current equal-weight problem. A
sidebar or collapsible groups would add navigation steps for a small directory.
Readable open groups keep every available action visible without a new interaction.

## Permissions and behavior

- Meetings: `manage_agendas`, `manage_minutes`, or `view_internal_records`.
- Manage Endeavors and Agenda setup: `manage_agendas`.
- People and roster, Website connections, and Access: `manage_settings`.
- Publishing: `publish_public_content`, independently of settings access.
- Background Jobs: `manage_settings`, `manage_minutes`, or `manage_agendas`.
  A record viewer must not see a Jobs link the destination refuses. Job actions retain
  their narrower existing checks.

Keep Administration/Admin and Officer tools naming consistent with existing navigation.
Destination controllers remain the authority; no grants or controller permissions change.
Opening the hub performs only reads, with no AI dispatch or state-changing action.

## Verification and critique

Exercise administrators, agenda managers, minutes managers, publishers, record viewers,
and ordinary-member denial. Verify missing/stale/current roster states, later reads,
real destination navigation, and grant removal with the existing authenticated session.
Preserve useful integration coverage; add focused browser journeys for this directory.

Inspect screenshots at desktop, 900px, and phone widths, including a sparse scoped
workspace. Check hierarchy, heading navigation, focus, target sizes, text floors, and
horizontal overflow. Record the actual critique and exact check results after rendering.

No departure from The 1919 requirements was required. The rendered refinements below
keep its palette, measures, typography, and readability floors.

### First rendered critique

The initial row-paired grid left roughly two destination rows of unused space below
Meeting work: its neighboring People and roster group was twice as tall. Independent
column stacks keep Agenda setup beside the meeting destinations rather than pushing
it below that gap. Mobile reading and keyboard order follow the entire meeting-tool
column before administration. This refines the grouping proposal, without changing
The 1919 visual requirements or reducing text and target sizes.

The generic “Assigned Post duties” label duplicated the scoped-access heading for users
with manual grants. Show actual current role names when present and retain the plain
account/settings boundary for everyone with scoped access.

### Contrast refinement

The shared muted gray `#6b7684` measures 4.31:1 on paper and 3.98:1 on cream. Use the
existing ink token for the hub's secondary text instead: 14.97:1 on paper and 13.83:1
on cream. Smaller type and normal weight retain hierarchy without making descriptions
harder for older members to read. This uses the established palette and does not lower
any text-size floor. Browser checks verify at least 4.5:1 on the rendered text and its
actual background, including hover and focus states, following
[WCAG contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

### Final rendered critique

Reviewed the administrator workspace at 1400px, 900px, 390px, and 320px in missing,
overdue, and current roster states. The independent desktop columns remove the initial
gap below Meeting work. Phone rows wrap descriptions and roster status without reducing
type, clipping content, or introducing horizontal overflow. The attention panel points
to the same import destination as its roster row and disappears for a current roster.

Reviewed agenda-manager and publisher-only workspaces at desktop and phone widths.
The narrower single-column measure keeps sparse workspaces readable. Scoped copy
explains account/settings limits; unsupported destinations and empty sections disappear.
Keyboard navigation follows the meeting tools first, has a visible navy outline, and
activates the destination with Enter. Real browser journeys also opened Meetings,
Endeavors, Meeting types, Jobs, roster import/history, email sync, and Publishing.

### Local verification

Verified the working changes against base `74879fbdfa789632219d759b20f4fb0d111d9c60`
using the locked bundle, Chromium, and isolated test databases with synthetic records.

| Check | Result |
| --- | --- |
| Full ordinary suite, seed 60675 | 1,339 runs, 13,261 assertions; zero failures, errors, or skips |
| Full system suite, seed 56606 | 82 runs, 2,231 assertions; zero failures, errors, or skips |
| Focused workspace and website-token browser journeys | 5 runs, 218 assertions; zero failures, errors, or skips |
| Focused RuboCop | 5 files inspected; no offenses |
| Brakeman | Zero errors and security warnings |
| Zeitwerk and Tailwind build | Passed |
| Changed-document references and diff whitespace | Passed |

Browser assertions check target sizes, text floors, actual contrast, and overflow, with
hover and keyboard-focus states. Website-token creation and revocation retain their
existing lifecycle assertions after updating the hub's link label. Permission coverage
includes direct destination denial and later requests after grants are revoked.

In a separate checkout and database, restoring the old record-viewer Jobs link made
the focused permission test fail on the extra `/admin/jobs` destination. Restoring the
implemented helper passed the same test with 15 assertions. This demonstrates detection
of that specific regression; passing counts alone do not establish all workflow quality.

Screenshots and logs are local review evidence. No CI, production, paid AI generation,
commit, push, or deployment was performed for this change.
