# Empty National roster input follows existing fatal validation

Design for #111 under #84, source `66e8c8a`, October 10, 2026. The roster workflow
already treats missing required columns as fatal and preserves people/accounts on invalid
input. Empty and BOM-only files have no required columns; they should use that existing
failure path. This is not permission to apply an empty roster or mass-remove anyone.

First retain the parser's original partial-header assertions and add empty/BOM-only inputs
to that exact scenario. Expect an invalid result, no parsed rows and a missing-columns
message. Submit an actual zero-byte CSV through the existing upload route with existing
synthetic people/accounts/grants/import history. Inspect unchanged saved state before the
response, the new failed import and its rendered column error. Later ordinary valid upload
must update the existing identity, retain its login email and save the new member/account.

Initial conditional hypothesis: only after reproduction, normalize absent header arrays
at required-column validation;
retain all existing validation/errors/partial-row/confirmation behavior. No broad rescue,
dependency change or copied roster data. Existing parser/service/request variants stay.
A real browser upload/error/subsequent-success journey will complement them.

Use the frontend-design direction already applied to this work: preserve the existing
1919 failed/completed import pages, navy working type, paper panels and actual error text.
No new template, spacing, color or authority language is proposed. Inspect desktop and
390px renders during the actual error/recovery flow, retaining readable controls and no
overflow. Test setup sign-in alone is not evidence of uploading a file.

Before commit: reproduction or disproof, meaningful controlled-fault detection, clean
focused parser/upload/roster checks, restored
sources, lint and complete intended diff. Before any merge: final committed ordinary and
system suites serially, security, affected real browser behavior, fresh review, exact-SHA
and actual-main CI. No production operations, National/member-data copy or paid AI.


## Original candidate disproved; current behavior retained

Both new parser and actual empty-upload/recovery contracts pass on unchanged application
source: 2 / 48 / 0 (seed36058, 2.28s). Current CSV.parse returns a table whose empty
headers validate through the existing fatal path. No nil-header exception or runtime
repair is established. Retain the application exactly and treat this as bounded missing
regression coverage. The actual failed import preserves people/accounts/grants/history;
later valid upload saves the current member/new identity and retains the login email.

Expected controlled-fault outcomes: bypass required-column validation only for empty
headers. The new parser must fail its invalid-result assertion; the real empty-upload
request must fail its actual stored failed-import outcome even if identity rows remain
unchanged and a redirect occurs. Keep partial-header refusal intact. Restore exact parser
bytes in finally and prove clean expanded roster checks. No broad rescue or production
claim. Integrate the title-fix main `a88f11e`; final checks remain pending.


## Regression sensitivity and real upload recovery

Locked CSV 3.3.6 was checked directly: `CSV.parse("", headers: true)` returns a
`CSV::Table` with `headers == []`; BOM-only source normalizes to the same input.
The apparent nil-header mismatch was an incorrect hypothesis about the API, not a
confirmed exception. There is no application-file change in this candidate.

Temporarily return from `validate_headers!` only for empty headers, preserving original
partial-header validation. Both targeted contracts fail: 2 runs / 9 assertions / two
failures, zero errors/skips (seed8913, 0.82s). The parser incorrectly accepts the input;
the actual uploaded import is saved as completed rather than failed, even though people
remain unchanged. Exact parser bytes restored in finally; SHA256
`626f4a450679848915c5ebec110dafe8036e3d97f6b2de9649941f0cc0f11ad0`.
Restored parser, complete upload controller, importer and model checks pass 75 / 470 /
0 (seed35763, 2.79s). Every old partial-header and neighboring assertion remains.

Real browser upload plus the old result/warnings journey pass 2 / 27 / 0 (seed41034,
5.02s) on integrated `a88f11e`. Empty-file upload preserves actual people/users/grants,
saves a failed import and renders the error. Clicking the actual “Import another roster”
link allows a valid upload that updates the same member identity/address, preserves its
private login email and creates the new member/account. The old thirteen-account and
named deceased-reversal result journey is unchanged.

Failed and completed page captures were manually inspected at 1400/390px: plain saved
outcomes, readable wrapping and no horizontal overflow. The existing failed-page heading
calls the global missing-columns problem “1 row needs attention”; the contract asserts
the actual missing-columns explanation, not that incidental heading as a row count.
No result-template change is part of this coverage slice. Neither upload screenshots nor
serial request cases establish simultaneous removal/confirmation safety.

Focused commands use `/tmp/legion-overnight-env` and explicit synthetic test database
`postgresql:///legion_empty_roster_review_test`. Ordinary focus:
`bin/rails test test/services/roster_imports/csv_parser_test.rb test/controllers/admin/roster_imports_controller_test.rb test/services/roster_imports/importer_test.rb test/models/roster_import_test.rb`.
Browser: `CI=true PARALLEL_WORKERS=1 bin/rails test test/system/roster_import_results_test.rb`.
No dependency changes, test deletion/consolidation, production operations, actual National
roster copy or paid calls. Final committed serial full suites/security/candidate and main
CI remain required before merge.

## Complete retained roster source/assertion slice

These full-file reviews began on main `66e8c8a`; all relevant sources remain unchanged on
integrated `a88f11e` before these test additions. They concern actual distinct assertions,
not completion inferred from execution counts. The current governing user-management
workflow preserves National provenance, login-email separation and last-administrator
protection. Keep the following lower-level and request/browser evidence separately.

| Exact file | Distinct retained contracts and limits |
| --- | --- |
| `test/services/roster_imports/csv_parser_test.rb` | Literal fixture fields and member ID; UTF-8 and binary BOM; missing/duplicate ID with valid-row survival; fatal required headers versus malformed CSV. Original partial-header case now additionally exercises empty/BOM-only inputs. Fixed fixture expectations differ from generated application-header inputs. |
| `test/services/roster_imports/importer_test.rb` | Thirty cases: actual person/account/import writes and reimport, more than ten complete identities, deceased reversal versus deliberate manual disable, no contact values in summary, login-email preservation, unchanged rows, unsupported/expired/deceased/removed/return status, last admin, usable unique versus missing/shared emails. Large-removal preview preserves all people/accounts/attachment; confirmed stored source applies. Save-failure seam is restored and checks rollback. No live National source or concurrent supersession proof. |
| `test/controllers/admin/roster_imports_controller_test.rb` | Thirty original routed upload/history/confirmation/privacy/discard cases retained. Blank/non-upload/malformed parameters differ from attached empty content. Existing completed/failed/missing-attachment/superseded/repeated confirmation refusal and required checkbox protect different starting states. Pending future language differs from completed recorded changes, names/new accounts/deceased historical warnings. Ordinary-member denial and pending discard preserve privacy/people. New actual empty-file refusal/recovery complements them; serial locking requests are not a race proof. |
| `test/models/roster_import_test.rb` | Seven independent latest-successful/history/staleness, old/empty summary projections, truthful deceased warnings and pending attachment contracts retained. Exactly thirty-day staleness is not separately frozen here; this slice does not invent a cutoff rule. |
| `test/system/roster_import_results_test.rb` | Original real sign-in/result warnings/names/record-link/desktop-narrow journey retained; direct service import setup differs from new actual browser upload/error/recovery. Large-removal confirmation is outside this browser slice and remains covered separately by requests/service. |


Final candidate integrates merged passkey review main `283911d`; application roster
sources are unchanged. Integrated focused checks pass 75 / 470 / 0 (seed4814, 2.79s); actual browser
upload/results pass 2 / 27 / 0 (seed45162, 5.02s). All three changed Ruby files
lint clean, zero-byte fixture verified, complete diff reviewed and parser SHA unchanged.
