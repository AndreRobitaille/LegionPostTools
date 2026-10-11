# Exact template and dated-agenda component source cases

Source `b965cf76ea7e8228db074e5df6d2e886df40cc30`, ten fully read files / 79 exact cases.
Source review is separate from recorded execution and representative fault evidence.

## test/controllers/admin/meeting_type_agenda_items_controller_test.rb

Reviewed file blob: `576d54fc721b3384c8d24beee113faff2c1b3292`.

- [picker requires manage_agendas](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L14)
- [picker lists active catalog entries and excludes inactive entries](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L22)
- [add catalog item copies it into meeting type with rich body](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L32)
- [add catalog item appends at next position](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L46)
- [duplicate add is rejected](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L57)
- [non duplicate validation failure is not reported as duplicate](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L69)
- [non catalog unique violation uses generic message](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L87)
- [duplicate record not unique is reported as duplicate](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L107)
- [update template item does not change catalog entry](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L127)
- [remove hard-deletes a seeded template item and leaves the catalog entry](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L154)
- [remove deletes local template item and leaves catalog entry](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L167)
- [remove preserves items already copied into draft approved and published agendas](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L180)
- [reorder persists the new item order](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L247)
- [edit form renders editable template fields](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L260)
- [update can move an item to another section](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L281)
- [cannot use another organization's catalog entry or meeting type](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L296)
- [add rejects an inactive catalog entry](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L307)
- [existing template item survives when its source catalog entry becomes inactive](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L317)
- [edit page renders draggable agenda rows with trash buttons](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_items_controller_test.rb#L331)

## test/controllers/admin/meeting_type_agenda_sections_controller_test.rb

Reviewed file blob: `53a6a314cab545e34c062cfeaa39a16b8b47ab3e`.

- [section management requires manage_agendas](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_sections_controller_test.rb#L11)
- [authorized officers can create and rename a section](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_sections_controller_test.rb#L19)
- [invalid section renders the designed form](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_sections_controller_test.rb#L32)
- [reorder rejects foreign section ids](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_sections_controller_test.rb#L41)
- [move changes the section order one position at a time](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_sections_controller_test.rb#L52)
- [only an empty nonfinal section can be removed](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/meeting_type_agenda_sections_controller_test.rb#L63)

## test/models/dated_agenda_section_test.rb

Reviewed file blob: `3025a214d0904a4624bf95861e30aae97c819571`.

- [new dated agendas receive a default section](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_section_test.rb#L12)
- [source section must belong to the agenda meeting type](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_section_test.rb#L16)
- [locked agendas reject section creation update and destruction](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_section_test.rb#L24)
- [reorder persists section order](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_section_test.rb#L34)

## test/models/dated_agenda_roll_call_entry_test.rb

Reviewed file blob: `ae518c7acedef2fabe13f9599e9d59e05c68dd10`.

- [dated roll call snapshots required and assigned offices as of the meeting date](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_roll_call_entry_test.rb#L28)
- [snapshot uses meeting date rather than agenda creation date](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_roll_call_entry_test.rb#L43)
- [later officer changes do not rewrite the dated snapshot](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_roll_call_entry_test.rb#L52)
- [draft roll call can be deliberately refreshed](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_roll_call_entry_test.rb#L63)
- [approved agenda roll call cannot be refreshed](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_roll_call_entry_test.rb#L75)

## test/services/minutes_agenda_wording_backfill_test.rb

Reviewed file blob: `af722ce9a378df08dad8103dea236447daa0d5e9`.

- [separates an exact legacy agenda snapshot from appended minutes paragraphs](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/minutes_agenda_wording_backfill_test.rb#L28)
- [moves agenda-only legacy wording without inventing minutes](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/minutes_agenda_wording_backfill_test.rb#L47)
- [refuses to guess when legacy wording is not an exact snapshot](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/minutes_agenda_wording_backfill_test.rb#L57)

## test/migrations/reinterpret_legacy_dated_agenda_times_test.rb

Reviewed file blob: `0bb5c960a87ff6dc78e4c8e1108777f8b7dd224c`.

- [reinterprets the legacy UTC components in the organization's zone](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/migrations/reinterpret_legacy_dated_agenda_times_test.rb#L30)
- [down restores the prior UTC-wall representation](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/migrations/reinterpret_legacy_dated_agenda_times_test.rb#L40)

## test/controllers/admin/dated_agenda_endeavors_controller_test.rb

Reviewed file blob: `c5e9c7a170c97e1b95f367492f2a9312af6aa2be`.

- [picker groups active Endeavor for a chosen section](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dated_agenda_endeavors_controller_test.rb#L15)
- [manager adds a snapshot to the selected agenda section](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dated_agenda_endeavors_controller_test.rb#L26)
- [duplicate Endeavor is rejected](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dated_agenda_endeavors_controller_test.rb#L40)
- [locked agenda rejects Endeavor](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dated_agenda_endeavors_controller_test.rb#L52)
- [plain member cannot use the picker](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dated_agenda_endeavors_controller_test.rb#L64)
- [another organization's Endeavor is not found](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/dated_agenda_endeavors_controller_test.rb#L72)

## test/models/dated_agenda_item_test.rb

Reviewed file blob: `57df196b50670dc6e5bf94d7783baf1bf8b60e2c`.

- [catalog entry must belong to the same organization as the dated agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_item_test.rb#L12)
- [behavior_type must be one of the supported catalog behavior types](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_item_test.rb#L22)
- [create_from_catalog_entry copies rich text body](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_item_test.rb#L34)
- [create_from_endeavor snapshots content independently](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_item_test.rb#L42)
- [Endeavor must belong to the same organization as the dated agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_item_test.rb#L56)
- [Endeavor can appear only once on an agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_item_test.rb#L67)
- [stale item update and destroy fail after parent approval](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_item_test.rb#L78)
- [reorder! rewrites positions to match the given id order](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_item_test.rb#L91)
- [reorder! uses only active agenda items when validating the id set](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_item_test.rb#L103)
- [reorder! succeeds when an inactive agenda item occupies position one](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_item_test.rb#L117)
- [reorder! bumps lock_version](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_item_test.rb#L131)
- [reorder! raises when the id set does not match the agenda's items](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_item_test.rb#L142)
- [reorder! raises when given only a subset of agenda item ids](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_item_test.rb#L151)

## test/models/dated_agenda_test.rb

Reviewed file blob: `b2974619d60325f70d8da60b10b312f0e5cec615`.

- [create_from_template copies active template items into a dated agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L12)
- [meeting upcoming uses the installation's local calendar-day boundary](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L28)
- [stores an installation-local start as UTC](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L40)
- [create_from_template snapshots document controls and Commander notes](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L48)
- [create_from_template copies section structure and item membership](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L69)
- [copied dated agenda sections are independent from template sections](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L84)
- [copied dated agenda items are independent from later template edits](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L93)
- [editing a dated agenda item does not change the template item](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L104)
- [locked agendas reject ordinary item changes](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L113)
- [locked agendas reject item creation](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L122)
- [locked agendas reject item destruction](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L132)
- [a locked agenda can be destroyed as a whole with its sections and items](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L142)
- [approve only allows draft agendas](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L157)
- [publish only allows approved agendas](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L170)
- [reopen only allows approved or published agendas](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/dated_agenda_test.rb#L187)

## test/controllers/dated_agendas_controller_test.rb

Reviewed file blob: `4e0583801e74253b8e80d59cf047f636ca1aa020`.

- [legacy index redirects authenticated members to meetings](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/dated_agendas_controller_test.rb#L18)
- [signed out users are redirected from agenda and print](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/dated_agendas_controller_test.rb#L24)
- [published agenda renders its saved place and returns to meeting record](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/dated_agendas_controller_test.rb#L31)
- [draft agenda remains private](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/dated_agendas_controller_test.rb#L45)
- [published agenda title stays independent after its template is renamed](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/dated_agendas_controller_test.rb#L53)
- [print returns the published member agenda as an inline PDF](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/dated_agendas_controller_test.rb#L64)
