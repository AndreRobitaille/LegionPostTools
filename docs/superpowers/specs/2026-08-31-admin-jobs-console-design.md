# Admin Jobs Console Design

## Purpose

The Jobs console gives an Adjutant or administrator one plain answer: is background
work moving, and does any recorded run need human attention? It is an operational
ledger for American Legion meeting work, not a generic Solid Queue control panel.

The first supported run types are AI minutes drafts and roster email syncs because
both already persist sanitized, human-readable status records. Queue internals are
shown only as current health signals. Raw job arguments and backtraces are never
rendered because they may contain private member data and because replaying an
arbitrary queue row is not a safe domain action.

## Authority and record rules

- A user with `manage_minutes` may see AI minutes draft runs and retry or discard a
  failed draft run.
- A user with `manage_settings` may also see roster email syncs. That capability
  already implies `manage_minutes`.
- Retry creates a new linked run using the current authorized source. The failed run
  is never reset or overwritten.
- Discard means “remove from the needs-attention view.” It records who discarded the
  run and when; it does not delete history. Discarded runs remain available through
  the Discarded filter.
- The initial console does not offer automatic retry/discard for roster email syncs.
  Retrying an external contact sync requires its existing roster/configuration
  preflight and belongs in that workflow. A failed sync links to its detail page.
- A finished Solid Queue row is not treated as proof that domain work succeeded.
  Durable workflow state is authoritative.

## Visual direction

The subject is a Post duty log for an officer checking unattended work. The audience
includes older members and people with low computer confidence. The page's one job is
to separate normal completed work from the few rows that require a decision.

Use the established **The 1919** colors, typography floors, bounded content width,
warm rules, and explicit focus rings. The signature element is an **operations
blotter**: a restrained paper ledger with a strong left status rail on every run.
It should feel like a record book maintained by the Post, not a generic analytics
dashboard.

Do not use a grid of redundant metric cards. Put the worker signal, waiting count,
and working count in one compact status strip. Below it, provide one run ledger with
three clear filters: Current, Needs attention, and Discarded. A failed row exposes its
reason and actions without a disclosure triangle.

Desktop wireframe:

```text
<- Administration
BACKGROUND JOBS                     [Worker available | 0 waiting | 0 working]
See work that continues after leaving a page.

[Current] [Needs attention 1] [Discarded]

RUN HISTORY
|red rail| AI minutes draft              FAILED
|        | July Membership - requested ...
|        | Timed out after 6 minutes
|        | [Retry as new run] [Discard from attention] [Open run]
|green   | AI minutes draft              COMPLETED
|rail    | July Membership - 3 minutes ...                 [Open run]
```

At narrow widths, each ledger row becomes a single vertical block: status, title,
meeting, timing, then full-width or wrapping actions. No horizontal table or hidden
actions are allowed. The health strip wraps without overflow. All interactive text is
at least 16px, secondary text at least 14px, and labels at least 13px.

## Queue monitoring

The console reports a worker as available when a Solid Queue Worker process has a
recent heartbeat. It also reports ready and claimed execution counts. These are
point-in-time diagnostics, not durable history. Finished queue records are regularly
cleared, so the run ledger is built from application records instead.

The AI draft dispatch status endpoint and browser request use `no-store`. Completion
already transitions to the review page, but the monitor should never depend on a
conditional cached response.

## Failure and retry behavior

Retry is offered only for a failed, still-draft `MinutesDraftRun`. It creates a new
`MinutesDraftRun` with `retry_of_id` pointing to the failed attempt, records the current
requester, validates the current transcript, and enqueues the existing background job.
The action warns that the transcript will be sent to OpenAI again.

If preparation or enqueueing fails, the newly created attempt (when one exists) records
the safe failure category and the user returns to the Jobs console with plain guidance.
No retry changes the meeting minutes directly.
