# Member Meeting API reading

Design for #77, October 10, 2026. Current governing Meeting/member policy allows every
enabled signed-in member to read every saved occurrence in the installed Post, including
upcoming/past occurrences with no published document. Roles policy gives a personal
delegate the same current baseline; it does not grant officer workspace access.

## Contract and privacy boundary

Allow authenticated `GET /api/meetings` and `GET /api/meetings/:id` without officer grants.
Keep mutation capabilities and installed-Post scoping unchanged. Include safe occurrence
identity/schedule/place, and explicit member-document links. Return no draft agenda
identity/state unless the caller manages agendas; no transcript metadata unless the caller
already has transcript-read authority; and no working minutes summary unless the caller
already has working-minutes read authority. Apply this projection to list/detail and
mutation echoes, so agenda-only managers cannot receive restricted minutes/source data.

Add explicit read-only member document paths under
`/api/meetings/:meeting_id/member_documents/{agenda,minutes}`, with `/print` PDF paths.
These share the HTML member boundaries, even for an officer: published agendas only and
the actual attested/member revision only. The existing `/minutes` endpoint remains the
officer workspace. Missing/unavailable/foreign documents return 404. Anonymous, disabled,
revoked/expired personal credentials fail authentication; enabled former officers retain
the member baseline. No new role, capability, confirmation bypass or public access.

Member agenda JSON reflects on-screen published content: active sections/items, heading,
member wording only when enabled, summary fallback only when body is absent, no private
Commander cues or roll-call entries. PDFs retain the existing print contract, which omits
summary fallback. Member minutes JSON uses the selected immutable revision's saved
heading, attendance, sections/narrative/outcomes and snapshot attestation/authority. Do
not return raw working rows, source FKs, confirmation evidence, token/account data, AI
runs/suggestions or transcript text. Pending corrections retain the last attested copy;
final membership approval selects the exact approved revision and authority label.
Select the revision once for document/detail metadata, so the identifier and rendered
content cannot come from two different revision selections. The returned `sha256`
identifies the original saved immutable revision; the sanitized member JSON projection
does not contain private source identifiers and is not the original digest input.

Use the same explicit member links/authority summaries in Meeting responses. Do not
silently reinterpret the legacy officer `minutes` summary as a member document. Preserve
existing officer request/response behavior within current grants. The JSON/Markdown
handbooks advertise member reads for all callers and explain the workspace distinction.

## Verification and visual direction

Before repair, reproduce member list/detail denial and agenda-only restricted summary
disclosure with persisted synthetic records. Exercise browser-session and personal-bearer
reads through the full document lifecycle, then subsequent reads after permission loss.
Compare actual selected revision/authority and visible content, exclude private/working
markers, and preserve the official graph. Keep current component selection, auth and
PDF failure tests. Real browser archive navigation and actual JSON/PDF reads provide
separate transport/rendering evidence; renderer stubs alone do not establish real PDFs.

The user-facing member UI keeps the existing 1919 document/archive layout. Review desktop
and narrow member screens while exercising navigation and denial. This is parity for the
existing private member workflow, without a new browser control or publication behavior.
Full ordinary/system suites run serially on the final revision, with focused lint/security,
exact-SHA CI and actual-main verification before completion.

## Evidence before final verification

Unchanged application `34d6abd`: two focused request regressions produced 2 runs /
3 assertions / 2 failures / no errors/skips (seed 17526, 2.27s). Ordinary member list
returned 403. Agenda-only list returned both transcript metadata (including filename,
retention and creator) and a private draft heading/lifecycle. This reproduced restricted
summary disclosure, not full transcript text disclosure. Source-only findings are kept
separate from this runtime evidence.

After repair, six focused request/model-independent HTML neighbor files passed
46 / 1146 / 0 (seed 58460, 9.16s). Strengthened lifecycle assertions then passed
5 / 506 / 0. Controlled fault substituted mutable working `revision_payload` for the
saved member snapshot: 1 / 84 / one failure at expected saved heading versus actual
working corrected heading, with no routing/error failure. Exact controller bytes were
restored (SHA-256 `0e551ba862bcf1c9d5e8b54f6132c234e498b91b5ee03fcef26fc0328ba8dffa`),
and all five scenarios passed again (seed 17499, 2.85s). No fault remains installed.

Existing `MeetingDocumentsTest` retains native/custom protected deletion, member
navigation, formatting, provenance, and HTML PDFs. It now also fetches member JSON and
real PDF bytes with a synthetic member bearer, and navigates the narrow archive to the
exact document. Two scenarios / 156 assertions passed (20.81s). Desktop/390px member
screens inspected: readable 1919 document cards, wrapping and no horizontal overflow.
PDF route-selection/error tests use an explicit renderer stub; browser PDF extraction
is separate real-rendering evidence. No existing assertion removed or test skipped.

Main's #80 merge is integrated before final verification. Full committed-candidate
local suites, lint/security and exact-SHA CI are still required; this is not completion.
