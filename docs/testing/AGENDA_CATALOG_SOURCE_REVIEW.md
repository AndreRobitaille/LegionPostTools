# Agenda catalog component and browser source review

Bounded #84 source/assertion review at b965cf76, October 11, 2026. Governing
COMMANDER_AGENDA_AND_ROLL_CALL.md separates member wording from private Commander
cues and fixes catalog -> template -> dated agenda -> minutes snapshot boundaries.
Catalog defaults and active choices affect future copies; historical records remain.
American Legion ceremony wording and local officer edits retain their concrete meaning.

Read every case, fixture, helper and assertion in four files / 47 exact cases. Names,
source lines and file blobs are pinned in [AGENDA_CATALOG_SOURCE_CASES.md](AGENDA_CATALOG_SOURCE_CASES.md).
Actual-main b965cf76 CI38122975568 passes all four jobs: PostgreSQL17.11 ordinary
1297/11980 then system74/1598, zero failures/errors/skips. This recorded execution
is separate from source reading and representative fault proof. No test or app edit,
new execution, deletion or consolidation belongs to this source-only review.

| Exact file / cases | Located starting state, action, saved/visible/subsequent outcome and limits |
| --- | --- |
| `test/controllers/admin/agenda_item_catalog_entries_controller_test.rb` /16 | Signed-out/no-agenda grant denial; actual seeded index with independent drag/move/edit/remove controls, inactive rows and empty drop destinations; actual category/order persistence and foreign/unknown payload preservation; adjacent-category movement; soft removal and foreign removal refusal; context-specific back links; actual rich-text/private-cue/wording-switch creation and saved updates; recoverable invalid create/update error summaries; officer-facing fields and attachment-free Lexxy; foreign edit refusal. Invalid update does not assert every old attribute; foreign edit is GET, not a complete foreign write matrix. Do not infer those additional detectors from the title or status alone. |
| `test/models/agenda_item_catalog_entry_test.rb` /16 | Invalid category/behavior errors; blank provenance keys and nil-summary normalization; organization-scoped slug normalization, uniqueness, automatic creation and collision numbering; rich wording/private notes and document flags; category/order normalization; incomplete/duplicate/unknown/foreign reorder rejection; adjacent movement and outer boundaries; soft removal preserves rows, excludes choices, closes positions and retains template/dated provenance links. The removal case retains link identity, not an independent comparison of every copied body; meaningful historical snapshot tests elsewhere remain. Foreign reorder checks the own row, not every foreign attribute. |
| `test/services/agenda_item_catalog_seeder_test.rb` /11 | Fixed28 new baseline entries and repeat count stability; untouched structured roll-call upgrade; independent Legion script fragments/visibility and list counts; complete definition-to-row transport; local title/rich text preservation; literal-bullet upgrade preserves local cues; removed entries stay removed; retired section placeholders stay absent; later closing steps receive a fixed order; second Post seeds independently. Full transport expectations intentionally use definitions/ActionText normalization, while fixed count, concrete wording, lists and historical/local-edit checks remain independent. No live National-source publication or production re-seeding proof. |
| `test/system/agenda_item_catalog_entries_test.rb` /4 | Actual magic-link browser drag saves changed category; accessible arrow action saves order without drag; real destructive confirmation shows record, copy-preservation explanation and Cancel focus before soft removal; edit page also opens that modal. The drag case checks category but not exact final order; the last case opens without submitting. No narrow-layout, lost-authority or historical PDF proof belongs to these four cases. Retain distinct gesture, non-drag and modal/focus detectors. |

The actual catalog controller scopes entries through the installation's organization;
its move/reorder/remove paths preserve existing narrow exceptions and messages.
Index seeding is documented and intentionally asserted, not an inferred runtime defect.
No safe test consolidation is established. Keep validation, local seed preservation,
real UI gestures and historical snapshot components independently. Broader scoped
agenda/template/API/PDF variants remain listed in the inventory. No production,
paid AI or real member-data copy occurred.
