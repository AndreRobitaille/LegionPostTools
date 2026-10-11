# Exact dated-agenda workspace and member-document source cases

Source `95a38a373154c1905f7de6726e96bccb41c4120c`, five fully read files /61 cases. Source reading and recorded execution/fault proof remain separate.

## test/controllers/admin/dated_agenda_items_controller_test.rb

Reviewed file blob: `4773c682239ff8b0f2fbf19761ca3e45a1c9bc73`.

- [signed out users are redirected](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L15)
- [users without manage_agendas are denied](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L21)
- [edit page offers the shared modal removal warning](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L30)
- [update copied item does not change template item or catalog entry](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L49)
- [update can move an item to another agenda section](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L77)
- [stale lock_version redirects with latest-version alert](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L91)
- [add catalog item copies it into dated agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L105)
- [discussion form selects the requested section and offers document controls](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L120)
- [discussion topic belongs only to the selected agenda section](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L138)
- [discussion topic can be created with just a title in an empty section](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L172)
- [invalid discussion topic retains the section wording and visibility choices](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L187)
- [discussion topics cannot use a section from another agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L209)
- [discussion topics require sign in and manage_agendas](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L226)
- [approved and published agendas cannot accept discussion topics](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L245)
- [reorder rewrites item positions for a draft agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L268)
- [reorder accepts only active agenda item ids when inactive items exist](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L281)
- [reorder succeeds when an inactive agenda item occupies position one](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L296)
- [reorder with a bad id set is rejected](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L313)
- [reorder with a partial id set is rejected](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L322)
- [reorder is blocked on a locked agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L332)
- [reorder returns locked status for a locked agenda json request](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L343)
- [locked agenda item edit redirects with alert](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L353)
- [stale parent agenda blocks item update after approval](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L365)
- [authorized officer can remove a draft dated agenda item](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L378)
- [authorized officer can refresh a draft officer roll call](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L390)
- [locked officer roll call cannot be refreshed](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L406)
- [signed out users cannot edit an agenda-local officer list](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L419)
- [users without manage_agendas cannot edit an agenda-local officer list](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L428)
- [non-roll-call items do not expose an officer-list editor](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L439)
- [authorized officer can edit the agenda-local officer list without changing Post roles](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L448)
- [agenda-local officer list can preserve a vacancy and add an optional office](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L483)
- [agenda-local officer list can remove a meeting-only row](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L506)
- [agenda-local officer list rejects removing every row](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L529)
- [locked agenda-local officer list cannot be edited](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L549)
- [locked agenda rejects removal](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L566)
- [another organization's dated agenda routes are not found](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_items_controller_test.rb#L579)

## test/controllers/admin/dated_agenda_sections_controller_test.rb

Reviewed file blob: `500dc2a4b343c3886100ed62e4b51cefc678d156`.

- [authorized officers can create rename and reorder sections](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_sections_controller_test.rb#L13)
- [move changes the section order one position at a time](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_sections_controller_test.rb#L26)
- [locked agendas reject section pages and json reorder](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_sections_controller_test.rb#L37)
- [cannot remove a nonempty section or the final section](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_sections_controller_test.rb#L54)
- [another organization's agenda is not found](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agenda_sections_controller_test.rb#L67)

## test/controllers/admin/dated_agendas_controller_test.rb

Reviewed file blob: `fc2a78e99acddfc6884a75f768cd21d9c4873367`.

- [legacy index redirects agenda managers to meetings](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agendas_controller_test.rb#L15)
- [users without agenda authority are denied](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agendas_controller_test.rb#L21)
- [edit shows lifecycle tools and meeting-owned details](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agendas_controller_test.rb#L27)
- [approve publish and reopen preserve the human lifecycle](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agendas_controller_test.rb#L41)
- [invalid lifecycle transition reports the model error](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agendas_controller_test.rb#L55)
- [destroy removes the agenda but keeps its meeting](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agendas_controller_test.rb#L63)
- [another organization's agenda is unreachable](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agendas_controller_test.rb#L78)
- [agenda manager receives the member PDF but not the private notes PDF](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agendas_controller_test.rb#L91)
- [current Commander and Adjutant receive the private notes PDF](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/controllers/admin/dated_agendas_controller_test.rb#L110)

## test/system/dated_agendas_test.rb

Reviewed file blob: `0df11d86a28e8e27bb9e240180084ed500ca72fa`.

- [drag-reordering agenda items auto-saves the new order](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/dated_agendas_test.rb#L34)
- [officer adds a meeting-specific discussion topic at desktop and narrow widths](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/dated_agendas_test.rb#L51)
- [approved agenda hides drag handles and item edit controls](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/dated_agendas_test.rb#L114)
- [dated agenda item list and edit page share the removal modal](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/dated_agendas_test.rb#L124)
- [meeting list opens the stable meeting workspace](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/dated_agendas_test.rb#L150)
- [Commander reviews document controls and the responsive private notes copy](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/dated_agendas_test.rb#L162)
- [officer reconstructs a historical meeting's officer list without changing Post roles](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/dated_agendas_test.rb#L208)
- [officer reviews the delete warning and deletes a published agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/dated_agendas_test.rb#L248)
- [member navigates from meetings to a published agenda at desktop and phone widths](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/dated_agendas_test.rb#L276)

## test/system/meeting_documents_test.rb

Reviewed file blob: `a712b064c9e2245dde7ae70107decee010bcf16d`.

- [members can distinguish and open both meeting documents on desktop and phone](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/meeting_documents_test.rb#L6)
- [attested member minutes retain rich text formatting on desktop phone and print](https://github.com/AndreRobitaille/LegionPostTools/blob/95a38a373154c1905f7de6726e96bccb41c4120c/test/system/meeting_documents_test.rb#L121)
