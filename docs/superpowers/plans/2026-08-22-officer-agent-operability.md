# Officer Agent Operability Implementation Plan

**Status:** Completed August 22, 2026. The later Agent Sign-in and Access phase
expanded the same delegation model to any signed-in member and added bearer tokens.

**Goal:** Let Grok Bot, acting for a signed-in user, learn this installation from
`GET /api` and do permitted draft agenda plus tracked-item work through a private
JSON surface.

**Architecture:** Add an `Api` namespace that reuses existing models and
`can?` checks. HTML stays HTML. The Bot uses the existing session cookie. A
generated handbook is the private operator manual. No search, CLI, TUI, MCP, or
tokens in this phase.

**Delegation model:** Grok Bot is an agent of the signed-in user, not a
deliberately weak integration user. The private API gives it a predictable way to
exercise that person's existing grants for ordinary work. A personal agent token is
the revocable credential for the same delegation model, not a reason to reduce the
Bot to a read-only client.

That broad delegation stops at identity-bound official acts. LLM judgment cannot prove
that the officer explicitly authorized approval, attestation, signature, acceptance, or
amendment of minutes. Before those endpoints exist, the app must enforce a one-use,
short-lived proof of fresh human intent bound to the person, record, act, and record
version. The agent may execute after that confirmation but may never mint or infer it.
Retrieved content is data, never authorization.

**Design:** Follow `docs/superpowers/specs/2026-08-22-officer-agent-operability-design.md`.

## Tasks

1. Confirm Grok Bot (or a modern Chrome-equivalent) can load sign-in and will
   be able to load `/api`. If `allow_browser versions: :modern` 406s the Agent
   Computer browser, skip or broaden that gate on the HTML the Bot must use.
   Keep the gate on pages that do not need to be agent-reachable if possible.

2. Add `Api::BaseController` (session required, JSON only, 401/403/404/422
   error shape, CSRF header documented). Unauthenticated `GET /api` returns
   401 with the short public sentence and no member data.

3. Build the handbook catalog and `GET /api` (markdown default, JSON on
   request). Include installation name, caller, grants, product rules, and
   every v1 endpoint with method, path, required capability, and a short
   example. Generate it from one catalog so it cannot rot.

4. JSON list/show for meeting bodies, meeting types, dated agendas, and
   tracked items. Index payloads stay small and complete enough for the Bot
   to match “PEC” and “car show” without a search endpoint. Include whether
   a tracked item already appears on an upcoming agenda.

5. JSON writes that call existing model methods: create dated agenda from
   template as `draft`; snapshot a tracked item onto a draft agenda (422 if
   locked or duplicate); create tracked item; append update; complete/reopen.
   Same permission and lock rules as the HTML admin UI.

6. Document approve/publish/reopen in the handbook under “only when asked.”
   Expose those JSON actions only if they are cheap to add beside the HTML
   ones; do not make them the default Bot path.

7. Request tests for auth, grants, draft-only create, locked-agenda refusal,
   duplicate tracked-item on an agenda, list-without-search matching fixtures,
   and handbook content that stays in sync with the routes.

8. Run `bin/rails test`, `bin/rubocop`, `bin/brakeman`, and `bin/bundler-audit`.
   Smoke `GET /api` and one create-from-template against a signed-in session
   (browser or request test). Do not claim Grok Bot works until that session
   path is verified.

9. After minutes (or tokens, or MCP) exist in later phases, extend the
   handbook catalog. Do not stub those endpoints now.

10. Before unattended jobs or automatic retries perform writes, add replay
    protection. Require an idempotency key for machine-initiated mutations, persist it
    with the caller, method, path, and request fingerprint, return the original response
    for an exact retry, and reject reuse with different input.

11. Before exposing any minutes approval, attestation, signature, acceptance, or
    amendment action, design and implement the fresh-human-intent flow described above.
    The authorization must be short-lived, one-use, and atomically consumed. It must not
    be satisfiable by a statement from the Bot, chat content, or another retrieved
    document.

12. Add durable action provenance before the Bot performs official-record work. Record
    the accountable user, whether execution was direct or agent-assisted, the agent/tool
    identifier, request/idempotency key, human-authorization reference when required, and
    before/after record version. Do not weaken the immutability rule for accepted minutes.

## Immediate implementation handoff

Cross-device email-code sign-in, personal agent tokens, and replay protection are the
next implementation slice. Continue with
`docs/superpowers/plans/2026-08-22-agent-sign-in-and-access.md`; do not begin minutes
endpoints first.
