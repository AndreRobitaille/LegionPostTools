# Independent restricted-source input boundary

Bounded #124/#84 component slice, source79bf811, October11,2026. Read the actual
MeetingTranscript model, MeetingTranscripts::Create and all seven existing component
cases. MINUTES_LIFECYCLE and the real intake form promise UTF-8 text up to5MB; use
the existing Rails five-megabyte byte boundary as an independent test expectation.
This changes no application behavior, retention schedule, MIME policy or official record.
#79/PR#98 still own the unanswered recovery-start and actual deletion lifecycle.

The old oversized pasted fixture uses MeetingTranscript::MAX_BYTES+1. A raised app
limit also raises that fixture, so rejection can still pass. First demonstrate that
coupling with a reversible test-only10MB limit while running the unchanged old case;
restore exact model bytes in finally. Then retain that same assertion/message and use
the independent existing5MB+1 input. Keep every other normalization/upload/one-source/
invalid/duplicate/organization/already-purged assertion and component distinction.

One new bounded case can exercise both pasted and actual uploaded source paths. Use
valid multibyte UTF-8 whose exact byte size is5MB, plus one byte above it. Before the
refusal, save actual creator/meeting and storage graph. Above-boundary refusal must
leave transcript/blob/attachment counts and saved identity unchanged before generic
error assertions. A later fresh read/retry must accept exactly5MB, retain actual pasted
text or original attached bytes, fixed byte size, creator and SHA256 metadata, without
changing meeting/creator fields. Subsequent source reads must agree with stored bytes.
Uploaded raw-byte retention differs from pasted normalization; preserve the existing
BOM/CRLF fixture evidence and do not assert a changed file-normalization policy.

Under the same raised-limit fault, the strengthened old refusal and independent new
boundary must now fail meaningfully. Restore exact bytes in finally and verify clean
seven retained components plus the added case and source/provider/request neighbors.
No duplicate request/browser workflow is needed for a component limit: the existing
real source intake/recovery/permission-loss/sign-out journey remains separate evidence.
Final committed ordinary/system suites serially, lint/security, exact-candidate and
actual-main CI remain required before normal code merge. No production, copied member
data, paid AI, external provider requests, test skips, broad rescue or consolidation.

Original raised-limit fault leaves the old coupled case passing1/15 seed4918,1.83s;
finally restores model8c4279abdef61387c22737851d6151d9b986e38efa737fcf55cc6dc20f14c8d5.
The first new full-byte assertion compares a UTF-8 string to binary downloaded bytes
and fails8/134/1; compare .b on both sides to state the actual raw-byte contract.
After that fixture correction, stored bytes agree but source_text raises real
Encoding::UndefinedConversionError from ASCII-8BIT to UTF-8:8/134/1 error,
seed30217,1.54s. Creation validates UTF-8 before storage; Active Storage downloads
binary bytes and the read path currently attempts a binary-to-UTF-8 transcode.

Expand this bounded design before the app edit: retain the existing ASCII upload case
and add a small accented/BOM/CRLF source with exact stored raw bytes/digest and later
normalized UTF-8 read. Reproduce that read error first. The smallest correction should
interpret a copy of the validated bytes as UTF-8 before the existing normalization,
without changing stored bytes, metadata, MIME/retention/access/official policy or
normalization behavior. Every existing case/assertion stays. Verify small real stored
Unicode source plus independent byte boundary, then execute the finally-restored
raised-limit fault against the strengthened cases and clean neighbors/browser.

Small original uploaded-component reproduction1/10/1 error, seed64339,0.73s:
the exact raw uploaded bytes match before the actual BOM/accented source read raises.
The Unicode defect now also needs a distinct real uploaded-file browser variant,
retaining the original pasted invalid/recovery journey. Use actual file controls,
saved byte/digest/creator/minutes assertions, later reader and authority-loss refusal.
Visual direction remains the established 1919 paper/navy restricted-source panels
and newly merged16px source body; inspect actual accented text at1400/390 without
changing layout, controls, retention wording or human-authority guidance.


The one-line read correction preserves raw bytes and existing normalization. Its first
new saved-state comparisons fail8/143/2 (seed63721) because the in-memory attachment
owner has version1 while its initial persisted version is2. Reload before taking the
initial stored snapshot, keeping every full after-read comparison; do not omit version
or timestamps. Corrected component/request/provider/generation neighbors pass62/674
seed37430,4.55s. Repeated raised-limit fault after that clean baseline fails2/25/2
seed55628,1.05s at required rejection, no errors/skips. Finally restores repaired
model SHA2565810c53d8209d3684dfea147b3f654ee62ccc67f08331c97ace93b1ab3557695.
Restored same neighbors62/674 seed32829,4.69s pass, no failures/errors/skips.
Three changed Ruby files lint clean. All old assertions remain; the independent5MB
fixture changes only an application-coupled expectation. The new real-upload browser
variant and final main integration/qualification remain pending before any merge.
