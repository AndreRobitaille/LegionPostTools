# API guidance and actual authority

Design for #81, October 10, 2026. Current Roles and minutes policy govern personal
delegates; Website connections governs fixed Post-owned consumer credentials. The live
permission-filtered GET /api remains the operating handbook. The standing brief still
calls the website feed anonymous, contradicting the generated brief and current routes.
The August 31 parity design mixes historical draft-only details with later extensions;
label the original scope and link current lifecycle/member-read rules clearly.

## Bounded contract

Compare JSON and Markdown actions with actual requests for seven independent expected
profiles: member, minutes drafter, Commander handoff actor, Adjutant attester, internal
viewer, technical administrator and publisher. Explicit grants isolate each duty here;
#78 supplies configured-office turnover coverage. Both formats must advertise permitted
representative actions and omit denied ones. Real requests must expose the expected
saved data, preserve records on refusal, and retain the owner's current grants.

Member reads do not include working minutes or restricted transcripts. Drafters and
technical administrators may prepare working minutes but administration does not grant
identity-bound handoff/attestation or publication. Internal viewers may explicitly read
restricted source evidence without drafting. Publishers use editorial endpoints with
explicit authority. Official actions are only-when-asked personal-bearer acts; session
API requests direct the person to the human confirmation flow rather than signing.

Retain existing component and request tests for exact delegated owner/token, record
version/content digest, one-use confirmation, lifecycle events and cached once-only
receipts. Strengthen the existing handoff/attestation assertions where needed. Explicitly
document unavailable API reopening, membership approval, amendments and token management;
existing token-management denial tests supply actual boundary requests.

Reuse the full WebsiteAccessAuthenticationTest matrix for approved feed/portrait reads,
anonymous/personal/session denial, Post scope, website-token private/editorial denial,
revocation and authenticated conditional reads. Add content/record preservation assertions
where useful. A controlled missing-credential fault must expose approved content to the
anonymous request and fail those assertions, then restore exact controller bytes. A
controlled handbook advertisement fault must fail an independently expected duty/request
contract; catalog entries themselves are not the expected-permissions oracle.

No new API endpoint, permission policy, official-record shortcut or UI is planned.
Synthetic local tests and offline publisher fixtures only; no production evidence,
deployment, data copying or paid AI. Full serial suites and exact candidate/actual-main
CI remain required before merge. Suite-wide review #84 and live publisher handback #60
remain distinct from this bounded contract verification.

## Detection evidence

The corrected focused set runs 38 tests / 1,482 assertions / no failures, errors or
skips (seed 64533, 9.87s). This includes all seven independently expected caller
profiles and existing handbook, website access, unavailable token-management,
operator-instruction and minutes action tests. The first caller assertion assumed an
ID field absent from the current handbook; it now checks the actual caller name.
No endpoint, policy or denial expectation was relaxed.

Three reversible faults demonstrate distinct detection:

- Advertising delegated approval to `manage_settings` instead of `approve_minutes`
  fails the Administrator profile's independent action expectation: 1 / 19 / one
  failure. Restored handbook SHA-256
  `2a5cb1afbd315b02798b4bec396296f75211c5e53414647614a0984bb25ebd80`.
- Allowing missing website credentials to select a stored token exposes actual
  approved synthetic person data to the anonymous request; its content assertion
  fails before checking 401: 1 / 2 / one failure. Restored controller SHA-256
  `e6d48b78e2b29b9a7dfaf7378ffbe442b98a7bbc2b85dbe2e89239a0e787d383`.
- Restoring the old standing brief fails the website-credential contract: 1 / 2 /
  one failure (seed 8440). Python finally restored the corrected brief exactly.

Existing handoff/attestation tests retain their prior assertions and add exact revision
payload/version/digest, actual delegated owner/token, one-use confirmation and
byte-identical once-only receipts with unchanged official graphs. Website tests retain
all prior denied modes and add absence of approved content on anonymous requests plus
authorized conditional 304 before revocation. These are synthetic local proofs, not
production behavior. Final committed suites and CI are recorded separately in the
overnight ledger before merge.
