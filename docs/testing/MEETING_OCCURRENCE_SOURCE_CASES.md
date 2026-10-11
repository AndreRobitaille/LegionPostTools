# Exact Meeting occurrence and template-management source cases

Source `95a38a373154c1905f7de6726e96bccb41c4120c`, seven fully read files /66 cases. Source reading and recorded execution/controlled faults remain separate.

## test/models/meeting_test.rb

Reviewed file blob: `9800a5d2b69f7a083cfa183dd9eb5db676929b05`.

- [defaults title and snapshots the body's effective place](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/models/meeting_test.rb#L16)
- [associations must belong to the same organization](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/models/meeting_test.rb#L27)
- [blank title is regenerated when the meeting date changes](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/models/meeting_test.rb#L37)
- [ordinary meeting updates synchronize draft agenda snapshots](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/models/meeting_test.rb#L45)
- [ordinary meeting updates respect official agenda boundaries](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/models/meeting_test.rb#L53)

## test/controllers/meeting_minutes_controller_test.rb

Reviewed file blob: `1198370f2ee3a81ea951f6648dd6b4fd10cc829b`.

- [PDF requires sign-in and an attested member-visible copy](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meeting_minutes_controller_test.rb#L15)
- [ordinary members can open the attested PDF without modifying official records](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meeting_minutes_controller_test.rb#L30)
- [reopened and handed-off corrections download the attested snapshot](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meeting_minutes_controller_test.rb#L46)
- [pending corrections retain the attested PDF until final approval locks the corrected revision](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meeting_minutes_controller_test.rb#L62)
- [PDF lookup stays in the installed organization](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meeting_minutes_controller_test.rb#L77)
- [generation failure returns members to the minutes with plain guidance](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meeting_minutes_controller_test.rb#L91)

## test/controllers/meetings_controller_test.rb

Reviewed file blob: `ac88125f31d73188d38200ecbe7a5adfcd0da9a9`.

- [signed out users are redirected](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meetings_controller_test.rb#L13)
- [index features the next meeting and groups all past meetings by year](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meetings_controller_test.rb#L18)
- [index links directly to a published upcoming agenda and removes generated title repetition](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meetings_controller_test.rb#L36)
- [index presents unavailable upcoming agendas as noninteractive](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meetings_controller_test.rb#L52)
- [meeting without an agenda is visible with honest state text](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meetings_controller_test.rb#L61)
- [past meeting retains the agenda link and identifies missing minutes](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meetings_controller_test.rb#L72)
- [attested revision is member visible while still awaiting membership approval](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meetings_controller_test.rb#L85)
- [membership-approved revision is presented as the official minutes](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meetings_controller_test.rb#L123)
- [member paper always uses the attested snapshot while working corrections change](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/meetings_controller_test.rb#L155)

## test/controllers/admin/meeting_types_controller_test.rb

Reviewed file blob: `7b92990409ce989abd8075f32f6f825d42b3da15`.

- [signed out users are redirected](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L9)
- [users without manage_agendas are denied](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L15)
- [index is read-only and lists existing meeting types](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L24)
- [seed defaults creates default meeting types with a post request](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L41)
- [create meeting type](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L53)
- [create on a fresh organization uses the first position without seeding defaults](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L65)
- [newly created meeting type appends after seeded defaults](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L75)
- [seed defaults after a custom meeting type keeps ordering unique](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L86)
- [invalid create does not seed defaults as a side effect](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L98)
- [update meeting type](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L111)
- [invalid update returns unprocessable entity](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L123)
- [edit form hides developer fields](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L133)
- [cannot edit another organization meeting type](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L146)
- [destroy deletes a meeting type and its items](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L156)
- [reorder persists the new meeting type order](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L172)
- [reorder rejects ids from another organization](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L186)
- [reset defaults restores suggested types and keeps custom ones](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L198)
- [reset agenda restores a suggested type's items](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L212)
- [reset agenda is a no-op with an alert for a custom meeting type](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L225)
- [index shows drag reorder, delete, and reset suggested when defaults present](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L235)
- [index shows add suggested when defaults are missing](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L249)
- [edit page has inline name edit and instant active toggle](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L260)
- [edit page shows reset agenda only for suggested types](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meeting_types_controller_test.rb#L276)

## test/controllers/admin/meetings_controller_test.rb

Reviewed file blob: `f49fee4f75d496e66eb8e9f4885e4442f37f3873`.

- [signed out and unauthorized users cannot manage meetings](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meetings_controller_test.rb#L20)
- [index separates upcoming and past meetings](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meetings_controller_test.rb#L29)
- [minutes managers can open records without agenda mutation controls](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meetings_controller_test.rb#L43)
- [agenda-only managers do not see draft minutes or transcript status](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meetings_controller_test.rb#L62)
- [new uses body place defaults and renders plain meeting fields](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meetings_controller_test.rb#L85)
- [create schedules a meeting without creating an agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meetings_controller_test.rb#L98)
- [invalid create returns guided errors](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meetings_controller_test.rb#L121)
- [prepare agenda copies template into the meeting](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meetings_controller_test.rb#L129)
- [meeting type is required before preparing an agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meetings_controller_test.rb#L143)
- [draft agenda heading follows meeting edits](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meetings_controller_test.rb#L155)
- [locked agenda prevents heading changes until reopened](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meetings_controller_test.rb#L177)
- [only an empty meeting can be deleted](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/meetings_controller_test.rb#L198)

## test/controllers/api/meetings_api_test.rb

Reviewed file blob: `89a5e1d54b769984396e2400fa15bac89ad0e4d5`.

- [create list show and update a meeting occurrence](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/meetings_api_test.rb#L15)
- [dated agenda creation attaches to an existing meeting](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/meetings_api_test.rb#L44)
- [meeting with an agenda cannot be deleted](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/meetings_api_test.rb#L54)
- [ordinary member and personal delegate can read occurrences without officer duties](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/meetings_api_test.rb#L63)
- [agenda-only meeting responses exclude restricted transcript and working minutes including update echoes](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/api/meetings_api_test.rb#L81)

## test/system/meeting_types_test.rb

Reviewed file blob: `adfdba84d079884774215bb438770ad769faae1d`.

- [renaming a meeting type via click-to-edit](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/meeting_types_test.rb#L21)
- [toggling active state without a form submit button](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/meeting_types_test.rb#L34)
- [deleting a meeting type after confirming](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/meeting_types_test.rb#L45)
- [removing a template item after confirming preserves a published agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/meeting_types_test.rb#L60)
- [drag-reordering agenda items auto-saves the new order](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/meeting_types_test.rb#L90)
- [moving agenda sections saves the meeting order](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/meeting_types_test.rb#L109)
