# Pinned agenda catalog case index

Reviewed source: `b965cf76ea7e8228db074e5df6d2e886df40cc30`. Each case remains. Source reading, actual
suite execution and meaningful regression demonstration are distinct evidence. See
[the catalog review](AGENDA_CATALOG_SOURCE_REVIEW.md).

## test/controllers/admin/agenda_item_catalog_entries_controller_test.rb

Reviewed file blob: `e9706584b0e091eb4800e195229bbc7db56881cf`.

- [signed out users are redirected](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L9)
- [users without manage_agendas are denied](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L15)
- [index seeds and lists entries for agenda managers](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L24)
- [reorder saves positions within and across categories](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L79)
- [reorder rejects foreign ids and changes nothing](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L97)
- [reorder rejects unknown categories and changes nothing](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L115)
- [move down crosses into the next category](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L130)
- [remove hides an entry without physically deleting it](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L141)
- [cannot remove another organization entry](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L155)
- [index back link points to administration for manage_settings users](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L168)
- [create entry](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L177)
- [invalid create returns unprocessable entity with error summary](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L214)
- [update entry rich text and active flag](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L233)
- [invalid update returns unprocessable entity with error summary](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L264)
- [edit form hides developer fields and keeps officer-facing ones](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L293)
- [cannot edit another organization entry](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/controllers/admin/agenda_item_catalog_entries_controller_test.rb#L330)

## test/models/agenda_item_catalog_entry_test.rb

Reviewed file blob: `609c987d4fb6b3186750672113b4bcd26efaa4a1`.

- [validates category and behavior type](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L8)
- [normalizes blank source keys to nil and allows duplicates](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L23)
- [normalizes nil summary to an empty string](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L48)
- [normalizes slug and enforces organization scoped uniqueness](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L62)
- [same slug can be reused by a different organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L85)
- [derives slug from title when none is given](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L109)
- [derived slug avoids collisions within the organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L121)
- [supports rich text body](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L141)
- [defaults document wording to the agenda and draft minutes](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L155)
- [supports private Commander notes](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L168)
- [reorder changes categories and writes contiguous positions](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L181)
- [reorder rejects incomplete duplicate and unknown category payloads atomically](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L195)
- [reorder rejects an entry from another post](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L214)
- [move reorders within a category and crosses the adjacent category boundary](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L228)
- [move rejects the outer catalog boundaries](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L242)
- [removing an entry preserves template and dated agenda copies](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/agenda_item_catalog_entry_test.rb#L250)

## test/services/agenda_item_catalog_seeder_test.rb

Reviewed file blob: `55362c58df67f2bbf20533685fd14233e4268f32`.

- [creates the regular meeting baseline](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/agenda_item_catalog_seeder_test.rb#L8)
- [upgrades the untouched roll call item to structured behavior](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/agenda_item_catalog_seeder_test.rb#L27)
- [stores full script text for ceremony entries](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/agenda_item_catalog_seeder_test.rb#L37)
- [creates every fresh entry with the declared catalog defaults](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/agenda_item_catalog_seeder_test.rb#L57)
- [does not overwrite local edits when run again](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/agenda_item_catalog_seeder_test.rb#L75)
- [stores seeded bullet content as semantic lists](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/agenda_item_catalog_seeder_test.rb#L87)
- [upgrades untouched literal bullets without overwriting local rich text](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/agenda_item_catalog_seeder_test.rb#L99)
- [does not restore a seeded entry removed from the catalog](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/agenda_item_catalog_seeder_test.rb#L114)
- [retires former section placeholders instead of recreating them as items](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/agenda_item_catalog_seeder_test.rb#L127)
- [inserts newly introduced closing steps into an older catalog order](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/agenda_item_catalog_seeder_test.rb#L150)
- [can seed a second organization independently](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/agenda_item_catalog_seeder_test.rb#L173)

## test/system/agenda_item_catalog_entries_test.rb

Reviewed file blob: `379f25fd15c3d96b545e78c2bec1711aa9805d2a`.

- [dragging a catalog item into another section saves its category and order](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/agenda_item_catalog_entries_test.rb#L18)
- [compact arrow controls move an item without JavaScript drag gestures](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/agenda_item_catalog_entries_test.rb#L31)
- [trash action removes an item from the catalog after confirmation](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/agenda_item_catalog_entries_test.rb#L46)
- [edit page repeats the catalog removal modal at the bottom](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/system/agenda_item_catalog_entries_test.rb#L66)
