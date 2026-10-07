# Reliable AI minutes generation

Design and implementation contract, October 7, 2026.

## Problem and intended behavior

The October 6 Membership Meeting had three failed first-pass attempts on October 7.
Each ran for approximately 721 seconds: a synchronous OpenAI request timed out after
360 seconds, then the SDK automatically submitted the same generation again. No
provider response ID survived either timeout. The worker started the jobs immediately;
an earlier, larger transcript had succeeded with the same model and prompt.

Submit one Responses API request with `background: true` and `store: false`, then
persist its response and request IDs on the existing `MinutesDraftRun`. While OpenAI
reports `queued` or `in_progress`, schedule another Solid Queue job after ten seconds
to retrieve that response. Polling jobs release the worker between checks. Disable SDK
retries, so a lost submission response cannot silently start another paid generation.

Keep the current model, high reasoning, prompt, output cap, citation validation, and
human review. The existing dispatch page continues to show `running` until a complete,
validated result creates suggestions. No visual layout or user action changes are needed.
Minutes text, attendance, outcomes, and official-record authority remain human-controlled.

The draft-start disclosure must accurately name the configured model and explain temporary
background-response storage before an officer sends the transcript. Visual direction:
preserve The 1919's navy/cream/gold, existing typography, disclosure panel, and source ticket.
Use 16px body text and source values, and raise source-ticket labels to the 13px minimum.
Change the wording within those components;
keep the submission and manual-workspace actions together. Critique the rendered page at
1400px and 390px, including wrapping, horizontal overflow, and the disclosure's legibility.

## Failure and recovery boundaries

- Default each HTTP request to 60 seconds, independently of a 30-minute overall
  generation deadline measured from the durable run start. Existing installations may
  override the HTTP limit with `OPENAI_MINUTES_TIMEOUT_SECONDS`; the overall limit uses
  `MINUTES_DRAFT_GENERATION_TIMEOUT_SECONDS`.
- Re-entering a running attempt with a recorded response ID retrieves that response;
  it never submits another generation. Duplicate jobs cannot stage the result twice or
  overwrite a terminal run. A running attempt with no recorded ID must never be resubmitted.
- Retry transient retrieval timeouts, connection failures, and server errors within the
  overall deadline. Configuration, malformed output, and other terminal errors fail the
  attempt. Preserve already-recorded provider IDs on every failure.
- On overall expiry or unavailable/changed source, attempt cancellation of the known
  response once, then record failure. Cancellation failure cannot trigger regeneration
  or hide the local failure. Failed submission and worker/queue errors remain explicit.
- Recheck draft editability and transcript digest before staging results. A completed
  attempt creates source-bound suggestions atomically and does not apply them.
- A lost initial HTTP response may leave an unknown remote request. This design does
  not promise exactly-once provider execution, automatic crash recovery, or known cost
  when provider usage is unavailable. A deliberate user retry remains a new attempt.

## Privacy and validation

OpenAI background responses can use `store: false`, but temporary response storage
still supports asynchronous execution and polling (roughly ten minutes). Ordinary
abuse-monitoring controls also remain applicable. Do not claim zero retention or log
transcripts/model output. See [OpenAI background mode](https://developers.openai.com/api/docs/guides/background).

Use offline provider fixtures to cover submission, queued/in-progress polling, complete
results, transient and terminal errors, deadline cancellation, source/lifecycle changes,
duplicate completion, durable IDs, and queue scheduling failures. Run the Rails suite,
focused lint, and security checks. Live model access and this installation's background
mode acceptance remain unverified until a separately authorized generation.
