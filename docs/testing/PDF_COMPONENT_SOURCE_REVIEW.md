# PDF component source and assertion review

Bounded #84 review at b965cf76, October 11, 2026. Governing PDF_DOCUMENT_DELIVERY.md
requires finished bounded PDFs, signed loopback sources, exact saved document identity,
current document-specific authority and separation of private cues/working corrections.
A member PDF uses its immutable member-visible revision; signed sources deny arbitrary
resources and mark omitted media without changing saved source or revisions.

Read all seven files, forty cases, fixtures, assertions and helpers. Exact names/lines
and blobs are pinned in [PDF_COMPONENT_SOURCE_CASES.md](PDF_COMPONENT_SOURCE_CASES.md).
Recorded actual-main CI38122975568 at b965cf76 passes all four jobs: ordinary1297/11980
then system74/1598, no failures/errors/skips. This is separate from source reading and
fault proof. No test/app edit or new execution belongs to this source-only slice.

| Exact file / cases | Starting state, action, outcome and practical limits |
| --- | --- |
| `test/services/calendar_pdf_test.rb` /5 | Independent month/view filename, exact signed organization/date/view/categories, renderer delegation and loopback URL with restored fake method, fixed61-second signature expiry, six signed invalid date/view/category shapes fail closed. Fake PDF proves transport wiring, not actual rendering; the complete token projection is separate from the narrower render payload checks. |
| `test/services/dated_agenda_pdf_test.rb` /4 | Exact agenda/notes filenames and saved title after real template rename, complete signed organization/agenda/variant identity, unknown variant refusal. It does not itself exercise expiry or render bytes; source and browser components remain. |
| `test/services/meeting_minutes_pdf_test.rb` /5 | Exact draft/attested filenames, saved draft title despite real template rename, actual human attestation plus changed working title retains immutable filename, exact signed minutes/organization identity. One label fixture directly sets status without a revision; it is not actual lifecycle approval. |
| `test/controllers/calendar_pdf_sources_controller_test.rb` /8 | Nonempty own/foreign/public/private events and private Endeavor; sessionless loopback source preserves two layouts, fixed month/time/description escaping and no officer controls/private context. Signed filters resist unsigned query overrides; explicit empty selection hides all; public preview excludes private meetings; signed foreign Post selects its own timezone/content. CSP exact asset protocol and missing/invalid/expired/nonlocal/missing-organization refusal. Hidden filtered HTML is retained for printing; this is a source response, not real PDF text/dimensions or member-route authority. |
| `test/controllers/dated_agenda_pdf_sources_controller_test.rb` /6 | Nonempty hidden member wording/private cue/roll call distinguishes agenda and notes; exact saved titles survive template rename. Both variants apply nonce/CSP, retain centered wording/emblem, omit media with readable marker and preserve saved rich source. Invalid signatures and non-loopback requests refuse. This source suite has no explicit expired-token detector; document action authority and native rendering remain independent. |
| `test/controllers/meeting_minutes_pdf_sources_controller_test.rb` /10 | Fixed narrative, agenda wording, attendance/vacancy and three motion results; draft labels and no controls/Endeavor context. Actual handoff/attestation/meeting approval select immutable text, title, revision/digest and truthful folio. Direct Adjutant omits Commander endorsement; pending corrections show working officer text while member source retains old attested text. Reopen/private changes cannot alter signed member revision; handed-off or superseded, unrelated, expired, nonlocal and invalid tokens refuse. Stored payload/digest survive media substitution. HTML footer/folio assertions do not alone prove repetition on every rendered page; some refusal cases assert status only. Preserve real approval/member/PDF neighbors. |
| `test/system/pdf_resource_security_test.rb` /2 | Actual AssumeSSL source with controlled reachable HTTP trap, restored global app/socket/thread, desktop/390px emblem/design/14px marker/overflow. Deliberately bypass presentation sanitization and observe browser CSP violation URIs plus zero trap requests; native Chromium produces four real PDF byte streams and a member source retains old narrative after private working changes, with no trap contact. Native byte-prefix checks do not parse every page's text/dimensions; extra captures/PDF files are optional. Meaningful parsed document and authorization tests remain independent. |

All assertions are retained. Component transport/signature fixtures, HTTP content separation,
resource traps and native rendering have distinct failure detection. No safe consolidation
or deletion is demonstrated. Existing representative PDF budget, immutable projection and
resource-policy evidence remain linked in the workflow matrix; this source review adds
no universal fault-proof or production/provider claim. #79/#93 decisions remain separate.
