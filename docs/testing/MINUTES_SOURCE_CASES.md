# Pinned minutes component and browser case index

Reviewed source: `5c54e39307cd80824d3d3cbbb6138a0306e22e2f`. Each exact case name links the source line
reviewed in [MINUTES_REVIEW_SOURCE_REVIEW.md](MINUTES_REVIEW_SOURCE_REVIEW.md).
Located assertions, actual suite execution and regression/fault demonstrations are
separate evidence. Every case remains; no consolidation is established.

## test/controllers/admin/minutes_corrections_controller_test.rb

Reviewed file blob: `d811b05c6259663290c53abb14f6675ead510117`.

- [Adjutant can prepare and complete an audited reopening](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_corrections_controller_test.rb#L31)
- [Commander can begin reopening attested minutes without attestation authority](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_corrections_controller_test.rb#L59)
- [Commander can record membership approval of an attested exact revision](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_corrections_controller_test.rb#L70)
- [draft minutes remain on the ordinary September workflow](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_corrections_controller_test.rb#L99)
- [pending corrections require their adopted wording before identity confirmation](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_corrections_controller_test.rb#L111)

## test/controllers/admin/minutes_draft_runs_controller_test.rb

Reviewed file blob: `4fa7001cb49a052516e14d0abbf1ff04249ad417`.

- [minutes manager sees the external-processing disclosure before drafting](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L35)
- [starting a draft returns immediately and enqueues background generation](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L50)
- [pending draft page monitors its authenticated status without pretending to know a percentage](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L65)
- [a proposed Endeavor link is visible and editable before use](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L86)
- [draft review keeps every suggestion as an individual human decision](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L115)
- [draft review presents attendance as one radio sheet with AI choices preselected](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L140)
- [attendance sheet records AI matches and human corrections in one bounded review](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L176)
- [using one suggestion changes only its ordinary minutes field](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L218)
- [using a suggestion through Turbo replaces its card and counter without a redirect](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L239)
- [motion review shows AI names and requires a human result](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L263)
- [motion with a known result and no names exposes the full record](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L289)
- [verified motion links roster people and preserves the AI-heard names](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L307)
- [edit-before-using shows the same roster verification controls](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L336)
- [internal viewers cannot initiate or review AI draft runs](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_draft_runs_controller_test.rb#L350)

## test/controllers/admin/minutes_editor_controller_test.rb

Reviewed file blob: `f1c2049de0a3023add628a79c9955408877ccdca`.

- [manager edits the independent minutes heading](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_editor_controller_test.rb#L22)
- [workspace renders the complete manual editing controls](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_editor_controller_test.rb#L44)
- [internal record viewer sees the workspace but cannot edit it](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_editor_controller_test.rb#L82)
- [manager adds renames moves and removes an empty section](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_editor_controller_test.rb#L95)
- [manager adds edits moves and removes standalone minutes items](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_editor_controller_test.rb#L122)
- [manager records motion results and roster-backed participants](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_editor_controller_test.rb#L161)
- [motion form uses plain result choices and roster search](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_editor_controller_test.rb#L210)
- [other motion result stores the specific recorded outcome](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_editor_controller_test.rb#L226)
- [manager records officer attendance while preserving explicit unknowns](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_editor_controller_test.rb#L244)
- [attested minutes reject every editor surface](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/minutes_editor_controller_test.rb#L265)

## test/controllers/admin/jobs_controller_test.rb

Reviewed file blob: `8f5f9c3de706df7f870887a367e59e2e76da77ef`.

- [minutes manager sees the durable AI run ledger and job controls](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/jobs_controller_test.rb#L27)
- [needs attention excludes successful and discarded runs](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/jobs_controller_test.rb#L45)
- [retry creates and enqueues a linked run without changing the failure](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/jobs_controller_test.rb#L65)
- [retry redirects to the existing active retry](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/jobs_controller_test.rb#L83)
- [discard and restore preserve the failed run](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/jobs_controller_test.rb#L97)
- [a user without minutes or settings authority cannot open the console](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/jobs_controller_test.rb#L116)

## test/controllers/admin/meeting_minutes_controller_test.rb

Reviewed file blob: `7f3eade68fdd7442f47871233c44a24e57d604a3`.

- [minutes managers can create the scaffold and open the workspace](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/meeting_minutes_controller_test.rb#L22)
- [internal record viewers may read but not create minutes](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/meeting_minutes_controller_test.rb#L37)
- [current Commander and Adjutant duties can read but not edit minutes](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/meeting_minutes_controller_test.rb#L53)
- [authorized officers can open the current draft as an inline PDF](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/meeting_minutes_controller_test.rb#L71)
- [unrelated users cannot open the workspace](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/meeting_minutes_controller_test.rb#L91)
- [future meetings cannot begin minutes](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/meeting_minutes_controller_test.rb#L102)
- [Commander sees the handoff action and begins one-use confirmation](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/meeting_minutes_controller_test.rb#L114)
- [Adjutant can edit the Commander handoff before attestation](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/meeting_minutes_controller_test.rb#L139)
- [unresolved attendance is explained rather than hiding the next step](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/controllers/admin/meeting_minutes_controller_test.rb#L160)

## test/models/meeting_minutes_test.rb

Reviewed file blob: `a80c7ea1e81b7f30842054cc384f3960c43bdf33`.

- [keeps legacy JSON fingerprints for official minutes actions](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L16)
- [creates a structured draft from a past meeting without an agenda](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L28)
- [seeds independent agenda snapshots and officer attendance](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L50)
- [catalog and template changes leave copied agenda and minutes content independent](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L86)
- [draft agenda supplies structure but meeting supplies the heading](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L129)
- [rejects a second minutes record for one meeting](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L140)
- [does not begin minutes before the meeting](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L157)
- [meeting and source records cannot cross occurrence boundaries](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L173)
- [outcomes retain explicit unknown facts](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L201)
- [meeting cannot be deleted after minutes exist](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L220)
- [approval snapshots an exact revision and a different Adjutant can attest it](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L228)
- [attestation authority is sufficient even for an officer who handed off the draft](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L272)
- [attested minutes can be corrected before membership approval without losing history](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L286)
- [membership approval requires a later occurred meeting of the same body](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L384)
- [Adjutant attests a draft directly without an invented Commander endorsement](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L416)
- [Adjutant edits after Commander handoff and attests the actual finished text](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L434)
- [stale content and missing attestation authority cannot release a draft](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L458)
- [approval with pending corrections locks only when Adjutant confirms the final text](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/meeting_minutes_test.rb#L473)

## test/models/minutes_draft_run_test.rb

Reviewed file blob: `17e8d4245a4f7ab89c1333f6171fc15e46161930`.

- [retry and discard provenance must describe the same durable run](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/models/minutes_draft_run_test.rb#L4)

## test/services/minutes_drafting/source_document_test.rb

Reviewed file blob: `86bc00a0157063a0155d72683b37d83f40ca0493`.

- [preserves normal transcript lines with stable numbering](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/services/minutes_drafting/source_document_test.rb#L4)
- [turns a punctuation-only single-line transcript into reviewable source lines](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/services/minutes_drafting/source_document_test.rb#L12)
- [does not lose content from an oversized passage without spaces](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/services/minutes_drafting/source_document_test.rb#L21)

## test/services/minutes_drafting/prompt_test.rb

Reviewed file blob: `c17b94bae8029865679a6e404a1752c69d8938f7`.

- [routes transcript content by agenda subject instead of speaking order](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/services/minutes_drafting/prompt_test.rb#L4)
- [requires useful detail while protecting sensitive reports and uncertain identities](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/services/minutes_drafting/prompt_test.rb#L16)

## test/jobs/minutes_draft_generation_job_test.rb

Reviewed file blob: `492af1fb588d17f148865f1ff5424a02a9fb20e1`.

- [delegates the prepared run to the drafting service](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/jobs/minutes_draft_generation_job_test.rb#L27)
- [records a safe failure state when the worker stops unexpectedly](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/jobs/minutes_draft_generation_job_test.rb#L39)
- [schedules another short job while the same background response is running](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/jobs/minutes_draft_generation_job_test.rb#L51)
- [a completed generation does not schedule another poll](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/jobs/minutes_draft_generation_job_test.rb#L65)
- [queued jobs submit once and retrieve the same response until completion](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/jobs/minutes_draft_generation_job_test.rb#L73)
- [a rejected polling enqueue records a queue failure and retains the response ID](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/jobs/minutes_draft_generation_job_test.rb#L106)

## test/system/minutes_background_drafting_test.rb

Reviewed file blob: `bb100483805bb9f149764dc692ee3deae03e195b`.

- [the start page discloses temporary response storage and stays readable at narrow widths](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/system/minutes_background_drafting_test.rb#L20)

## test/system/minutes_approval_flow_test.rb

Reviewed file blob: `fd42abcc7d05b85c0f8a20ca4fa1f0a4f5e8c1b1`.

- [Commander handoff Adjutant edits and meeting corrections reach a locked record without extra approval clicks](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/system/minutes_approval_flow_test.rb#L25)
- [Adjutant draft attests directly with one clear status on desktop and phone](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/system/minutes_approval_flow_test.rb#L115)
- [ending officer duties denies a subsequent save in the same browser while member navigation remains](https://github.com/AndreRobitaille/LegionPostTools/blob/5c54e39307cd80824d3d3cbbb6138a0306e22e2f/test/system/minutes_approval_flow_test.rb#L133)
