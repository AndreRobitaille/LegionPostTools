# Member navigation, personal work, and Post workspaces

October 12, 2026. Andre approved separating Officer tools from Administration and
putting Buddy Checks under Your work, with desktop/phone verification and a LAN-bound
development server afterward.

## User jobs and destinations

The desktop bar keeps five stable member destinations: Dashboard, Calendar,
Meetings, Endeavors, and People. On a phone these same links appear under Member
site in Menu. Each destination is exposed once in the accessibility tree.

Menu groups the remaining destinations, at every width:

- **Your work:** Buddy Checks for current callers or authorized Post coordinators; Your assigned calls for
  a scoped Membership caller. Personal welfare work is available without a Post office.
- **Post duties:** Officer tools, a distinct `/officer-tools` task hub for current
  membership leadership or existing operational grants. It groups meeting work,
  Membership, separate Buddy Check coordination, agenda setup, publishing, and permitted processing tasks.
- **Application settings:** Administration, the existing `/admin` hub restricted
  to settings administrators. Accounts, Post-position configuration, roster imports,
  integrations, and technical maintenance remain here under their existing guards.
- **Your account:** Your profile and Sign out. App connections remain inside Profile.

A person holding both kinds of authority sees both hubs. A 1st Vice Commander can
reach Membership from Officer tools without technical-administrator access. A publisher
or record viewer receives the same operational destinations their grants permit.
Approval-only users receive a useful shared Meeting destination. The controller guards
on every existing leaf page remain unchanged, including personal official-record acts.

Old `/admin` bookmarks for scoped officers redirect to Officer tools. Removing settings
access after a browser session was established must remove Administration on the next
request; direct `/admin` requests must not render account/settings tools. Removing Post
authority must remove the Officer tools destination and deny its hub on the next request.

## Visual direction

Use the frontend-design skill and The 1919 system. Keep navy #0A2240, gold #C6A15B,
cream #F4EEDD, paper #FBF7EC, and the existing system sans. Use the admin redesign's
bounded destination rows for both hubs. Meeting work keeps its gold edge in Officer
tools; roster attention stays beside the import task in Administration.

Menu is a short directory of areas. The small, navy section labels clarify why a
destination is present; individual officer tasks live inside the hub. Keep links at
16px or larger with 44px targets and labels at least 13px. At narrow/short viewports,
Menu scrolls inside the viewport so Profile and Sign out remain reachable. The button
uses the existing click, Escape, outside-click, and keyboard-arrow behavior. Arrow
navigation skips links hidden at the current width.

Operational leaf pages return to Officer tools; account/configuration pages return to
Administration. Active menu marking follows the workspace containing the current task.

## Verification

Exercise ordinary members, pilot callers, assigned callers, current membership leaders,
agenda/minutes managers, publishers, record viewers, and full administrators. Verify
actual hub/leaf navigation, current-grant removal, ordinary denial, and no background
work on reads. Inspect 1400px, tablet, 390px, and short phone menus, including keyboard
focus and scrolling to Sign out. Preserve existing official-action/session tests.

Use synthetic test data. Start the development server only after verification; bind it
to `0.0.0.0`, inspect its listener and health, and leave it running for Andre. Do not
reset or copy development/production member data.
