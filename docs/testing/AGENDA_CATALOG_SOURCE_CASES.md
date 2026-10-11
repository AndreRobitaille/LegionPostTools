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

## test/models/meeting_body_test.rb

Reviewed file blob: `0bad3d8dba64f8a2935d52427bf8c88863db5ed4`.

- [uses the meeting body's location before the organization default](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_body_test.rb#L4)

## test/models/meeting_type_test.rb

Reviewed file blob: `2b0b8f28ead7e44d04d29269e93f05c551b2cc52`.

- [derives slug from name when none is given](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_test.rb#L8)
- [derived slug avoids collisions within the organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_test.rb#L14)
- [slug uniqueness is scoped to organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_test.rb#L22)
- [name uniqueness is scoped to organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_test.rb#L31)
- [position uniqueness is scoped to organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_test.rb#L43)
- [normalizes blank source key to nil](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_test.rb#L52)
- [orders by position then name](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_test.rb#L59)
- [can be destroyed cleanly](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_test.rb#L66)
- [reorder! rewrites position to the given 1-based sequence](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_test.rb#L76)
- [reorder! rejects ids outside the organization and changes nothing](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_test.rb#L88)
- [reorder! rejects duplicate ids](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_test.rb#L102)

## test/models/meeting_type_agenda_section_test.rb

Reviewed file blob: `f5c382b53046f4ae8143da32a9f37c14d87265b5`.

- [new meeting types receive a default section](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_agenda_section_test.rb#L9)
- [section titles are normalized and unique within a meeting type](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_agenda_section_test.rb#L14)
- [reorder changes only the selected meeting type](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_agenda_section_test.rb#L23)
- [a section with agenda items cannot be destroyed directly](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_agenda_section_test.rb#L34)

## test/models/meeting_type_agenda_item_test.rb

Reviewed file blob: `ad389dc39a91663543688e32c4cae836fa82288c`.

- [copies title summary and body from catalog entry](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_agenda_item_test.rb#L18)
- [copies document controls and Commander notes from catalog entry](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_agenda_item_test.rb#L27)
- [template edits do not modify the catalog entry](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_agenda_item_test.rb#L41)
- [prevents duplicate catalog entry in same meeting type](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_agenda_item_test.rb#L52)
- [position uniqueness is scoped to meeting type](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_agenda_item_test.rb#L60)
- [same catalog entry can be used by another meeting type in same organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_agenda_item_test.rb#L81)
- [rejects catalog entries from another organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_agenda_item_test.rb#L90)
- [reorder! rewrites item position to the given 1-based sequence](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_agenda_item_test.rb#L106)
- [reorder! rejects ids from another meeting type](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/models/meeting_type_agenda_item_test.rb#L120)

## test/services/meeting_type_template_seeder_test.rb

Reviewed file blob: `784513ca8ab26a8cb9fbe5dea853267c96098f11`.

- [seeds default meeting types for an unseeded organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L9)
- [seeds membership meeting with exact ordered titles](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L25)
- [seeds pec meeting with exact ordered titles](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L60)
- [seeds meeting-shaped sections for the supplied templates](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L73)
- [reseeding does not overwrite local edits](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L95)
- [reseeding upgrades untouched literal bullets in template items](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L114)
- [reseeding does not reactivate a removed seeded template item](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L127)
- [retires a referenced placeholder without changing its dated agenda snapshot](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L141)
- [reseeding does not change meeting type or template item counts](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L191)
- [template reset does not restore a removed catalog entry](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L201)
- [reseeding upgrades existing seeded items from the migration fallback section](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L215)
- [seeding is independent by organization](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L243)
- [defaults_missing? is true when a seeded meeting type is missing template items](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L254)
- [seeding appends defaults when preferred positions are taken by custom meeting types](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L262)
- [reseeding a missing template item appends when its canonical position is occupied locally](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L271)
- [inserts newly introduced ceremony items into an older template order](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L299)
- [reset_for! restores suggested meeting types to defaults and leaves custom types](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L335)
- [reset_agenda_for! restores one suggested type's items to default](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L350)
- [reset_agenda_for! is a no-op for a non-suggested meeting type](https://github.com/AndreRobitaille/LegionPostTools/blob/b965cf76ea7e8228db074e5df6d2e886df40cc30/test/services/meeting_type_template_seeder_test.rb#L363)
