# Bounded real PDF browser delivery

Bounded #134/#84 design, source b965cf76, October 11, 2026. Typography PR#133
exact CI38123404349 catches ScriptTimeoutError at MinutesApprovalFlowTest's real
PDF fetch (seed53468, Chrome154.0.8037.97). Its artifact shows the correct member
HTML/final corrected revision; it does not establish the PDF response duration or
an application renderer failure. Keep that failed run and the draft PR visible.

Locked Capybara3.40's Selenium driver sets asynchronous script_timeout to its
two-second default. The actual renderer permits thirty seconds, including a real
Chromium process and source request; governing PDF_DOCUMENT_DELIVERY.md requires
bounded generation and controlled failure. PDF fetches in minutes approval, meeting
documents and dated agendas use the shorter general timeout. Other ordinary JSON
or UI checks should retain their current wait. No renderer or product policy changes.

Before editing the helper, temporarily delay the minutes browser's actual PDF fetch
by three seconds. It must still fetch and parse the actual authorized PDF, with every
existing content and immutable-graph assertion intact. Expect the existing helper to
raise ScriptTimeoutError; restore exact source. Add a small shared PDF-only async
helper with a fixed35-second upper bound (the renderer's30 plus transport/termination
margin), using ensure-backed Capybara.using_wait_time and verifying the ordinary wait
is restored. Change only the three PDF call sites; preserve their scripts and assertions.

Repeat the same isolated delay on the corrected helper and require real PDF bytes,
parsed content and saved identity/immutability to pass. Restore exact source. A separate
wrong-content request must still fail the existing readable-PDF assertion, then restore
and run clean approval/meeting-document/dated-agenda/resource-security neighbors.
No permanent sleep, retry, skip, blanket timeout increase, exception suppression or
fake successful PDF. The deterministic budget mismatch is separate from certainty
about the original CI request's precise elapsed time.

Review the complete diff before committing. Final committed ordinary/system suites
run serially, with lint/security, exact-candidate and actual-main CI before normal
merge/closure. Reintegrate the verified repair into draft PR#133 and requalify that
final candidate. No production, paid AI, member-data copy or official application.

Original isolated three-second fetch delay reproduces ScriptTimeoutError at the same
real minutes PDF helper:1/62, zero failures, one error, seed44796, 11.36s. Exact
test restoration SHA2567f1ce8aee55c13008cbb52386c6d583b4bec54289cabca33e00e2f0ab62fc388.
No delay remains. This proves the shorter harness budget rejects allowed delayed
delivery; the original CI request's exact latency remains unmeasured.

Corrected helper with the same three-second real-fetch delay passes1/95,
seed11482, 19.81s, including actual PDF parsing/content/unchanged record assertions
and ordinary-wait restoration. Exact corrected test restoration
SHA256a14ae88696807d23657d7883889d7dfaaf7ae8292912dc98305b70fdaf157b9b.

The first wrong-HTML response control returns the existing error-key callback object
and raises WebDriverError before the readable-PDF assertion:1/62/1 error, seed1624.
Do not credit that invocation as assertion proof. A temporary message-key result for
that same actual non-PDF response reaches the existing String assertion and fails
1/64/1, seed18145, 9.53s. Both temporary URL and result-field changes restore exactly
to the same corrected SHA above; production scripts remain unchanged.

Restored four-file browser neighbors pass16/437, seed15803, 61.48s: actual approval,
member HTML/PDF identity and rich formatting, agenda/notes PDF and restricted resources.
After the final negative control, approval3/133 seed44513, 18.30s passes again.
Four changed Ruby files lint clean; diff checks pass. Fresh desktop document selection
and phone member-format captures were inspected with intact readable content/navigation.
No test assertion was removed; the helper adds ordinary-wait restoration assertions.
Final committed full suites and exact-candidate/main CI remain pending.
