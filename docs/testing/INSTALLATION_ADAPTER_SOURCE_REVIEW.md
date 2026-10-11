# Installation, access and offline adapter source review

Bounded #84 review at b965cf76, October 11, 2026. Installation is for configurable
American Legion Posts; setup creates a local Person/account, technical administration
and explicit Legion preset, never publisher authority or evidence of a National import.
Current roles/management guidance keeps manual permissions, dated officer capabilities,
National membership information and sign-in eligibility distinct. PDF print identity
and private attachment boundaries remain components. Mail and AI may call external
providers in production, but every located adapter case here uses synthetic offline
boundaries; serialization is not evidence of provider acceptance or delivery.

Read eight complete files /39 cases, all fixtures/helpers/assertions. Exact names/lines
and blobs pinned in [INSTALLATION_ADAPTER_SOURCE_CASES.md](INSTALLATION_ADAPTER_SOURCE_CASES.md).
Recorded b965cf76 actual-main all-four CI38122975568 passes ordinary1297/11980 then
system74/1598 without failures/errors/skips. Source reading is separate from execution,
paid/live acceptance and representative faults. No test/app edit or new run here.

| Exact file / cases | Starting state, action, outcome and limits |
| --- | --- |
| `test/controllers/setup_controller_test.rb` /13 | Real empty setup form and create counts for Post/account/session, fixed address/public email/preset11 offices/2 bodies/installation completion, technical administration and no publisher grants. Invalid form preserves three counts; completed/disabled/repeated setup cannot reopen or duplicate; Post-only/User-only incomplete form states and real partial POST reuse identity; both existing rows without completed setup require operator recovery and cannot grant/sign in. Invalid case does not assert Person count/every partial row; creation does not independently inspect every saved account/Session field or later Profile. Initial local provenance/readback remains the bounded #115 follow-up. |
| `test/controllers/admin/dashboard_controller_test.rb` /9 | Anonymous and ordinary member deny hub; manual full administrator sees concrete administration/navigation links without scoped context; actual assigned Adjutant agenda duty shows Officer tools/private context while hiding settings/roster; scoped backlinks, manual minutes manager's meeting/jobs-only links; fixed recent2-day/overdue31-day/no-import roster labels. GET visibility does not prove every linked write/grant-loss transition, exact30-day boundary or #93 near-midnight authority; those existing components remain independent. |
| `test/integration/direct_upload_security_test.rb` /2 | Actual anonymous client obtains its valid CSRF token with protection enabled, but direct upload remains404/empty and Blob count unchanged; signed-in alternate content-type/identified metadata also cannot mint upload capability. Global forgery setting restores in ensure. These denial detectors do not establish authorized upload behavior; actual transcript upload components remain separate. |
| `test/models/organization_test.rb` /2 | Independent normalized valid/invalid public print email and two nonblank address lines versus invalid three lines. Unsaved validation/formatter checks differ from persisted setup/template/PDF and configured timezone tests. |
| `test/services/american_legion_post_preset_test.rb` /3 | Actual configurable Post gets fixed eleven office names/order/required flags/membership authority, explicit Commander/Adjutant capabilities, no Vice Commander application grants, exact two meeting bodies/distribution; repeat counts prevent duplicates. Deliberately changed preset title/grants/body defaults restore without new rows. This is explicit preset restoration, separate from catalog/template seeders that preserve local content; it does not prove officer assignment dates or second-Post isolation. |
| `test/services/mail_delivery_test.rb` /4 | Ensure-restored configured fake backend receives exact user/link/code; actual ActionMailer test delivery count1; offline intercepted Loops post contains exact template/email/name/link/code; synthetic provider rejection yields fixed400/message. Environment placeholders delete in ensure; no external HTTP/TLS/delivery or full email-body assertion. Keep these adapter checks alongside real synthetic sign-in browser components. |
| `test/services/openai_sdk_contract_test.rb` /3 | Real locked SDK uses an OfflineTransport with no network, serializes Responses create/retrieve/cancel exact paths/methods/background/store/timeout and reads pending IDs/parsed suggestions/request and token/reasoning data. Invalid JSON retains SDK IDs/category; Endeavor accounting uses SDK usage cache/write fields. Client retries disabled; these strict serialization/response-model detectors do not prove the external service accepts background/store configuration, live paid completion or every provider failure. |
| `test/services/endeavor_history/provider_test.rb` /3 | Offline response Struct/capture checks independent model/high reasoning/strict schema/no sampling/tools/store/truncation and exact usage/cache/reasoning, incomplete refusal, explicit Astra/Sol per-stage defaults/environment override with restored environment. Refusal title includes refused but located fixture exercises incomplete; no live acceptance, transport serialization or every error category follows. SDK and whole offline history pipeline components remain independent. |

Prioritize initial account/recovery, direct-upload capability denial and explicit officer
preset grants as P0 in the inventory; their generic original runner classification
missed the authority boundary. Every test/assertion is retained. Installation recovery,
meaningful navigation visibility,
CSRF denial, print identity, concrete Legion preset, mail transport and SDK/model contract
boundaries detect distinct faults; no safe consolidation/deletion is established.
Current runner/support/configuration and actual restored sign-in/provider-failure evidence
remain in the matrix. #115, #79 and #93 decisions/evidence are not replaced by this source
review. No production, real member-data copy or paid provider call occurred.
