# Protected meeting-content deletion

Design for #82 and #83, October 10, 2026. Governing boundaries:
[Meeting foundation](MEETING_FOUNDATION_AND_MEMBER_ARCHIVE.md),
[minutes approval](MINUTES_APPROVAL_AND_ATTESTATION.md), and the independent
catalog → template → dated agenda → minutes snapshot chain.

An agenda manager may remove an unused Meeting Type and its template, or a dated
agenda/child with no protected references. Removing an agenda preserves its Meeting.
Published agendas without historical dependents remain deliberately removable through
the existing warning/confirmation; publication alone is not a permanent-record lock.

A Meeting Type referenced by a Meeting, dated agenda or minutes cannot be removed.
An agenda, item or section referenced by minutes or retained AI suggestion lineage
cannot be removed. Keep existing model/database reference restrictions; do not detach
sources, cascade into minutes or rewrite copied content to permit deletion. Locked
agenda children still require reopening; reopening does not release historical
references. Template-item removal remains a separate optional-provenance operation.

## Action and feedback

Inspect current references when the delete request runs, even if they were created
after the person opened the screen. Use `destroy!` and narrowly handle expected
`DeleteRestrictionError`/`RecordNotDestroyed` failures. Transactions roll back all
partial child deletion. Unexpected errors remain visible to engineering.

HTML returns to the surviving relevant list/editor with an alert explaining that
meeting records use the content and it cannot be deleted. It never reports successful
deletion when destruction is refused. API returns HTTP 422 with a truthful error;
current authentication, duty, organization and version requirements still apply.
No permission or immutable-record change is part of this design.

## Visual direction

Use the existing 1919 bounded working page and alert banner: cream/card paper,
navy headings, red attention copy, system sans working text (16px body, 14px
secondary, 13px labels). Preserve existing delete/confirm controls, focus behavior
and document-serif rendering. The only new UI is plain refusal copy in that banner;
no new layout, palette, component or density. Inspect its wrapping, readability and
continued navigation at 1400px and 390px with synthetic records.

## Regression evidence

Retain successful unreferenced deletion, locked-parent refusal, denied/foreign requests
and optional template-source nullification coverage. Strengthen request/API tests with
actual references and persistent record/source/content assertions. A browser uses the
real delete/confirm flow and checks truthful feedback plus subsequent document reading.

For each new regression, record the failure against the original controller first,
then the corrected run. Where stronger content-loss detection needs a controlled fault,
state the expected assertion, isolate the fault in the temporary test checkout, restore
only the fault and prove a clean run. No tests are removed merely for similarity.
