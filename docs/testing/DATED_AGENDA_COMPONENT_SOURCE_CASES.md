# Exact template and dated-agenda component source cases

Source `b965cf76ea7e8228db074e5df6d2e886df40cc30`, six fully read files / 39 exact cases.
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
