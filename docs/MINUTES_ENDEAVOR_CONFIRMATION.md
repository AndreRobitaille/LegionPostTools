# Creating or linking an Endeavor during minutes review

## Product decision

Officers may create a continuing-work record from a draft minutes item without leaving
the meeting workflow. They may also link an existing Endeavor. Both actions preserve
the minutes item's wording, outcomes, and source agenda snapshot. Recording an Endeavor
does not approve a motion, approve minutes, or rewrite the original agenda.

The manual actions appear beside each editable minutes item. **Create Endeavor from this
discussion** opens a short form with the item title and recorded discussion as suggested
starting text; when recorded discussion is blank, use its agenda wording. A human edits
the title and description and selects **Create and link**. **Link existing Endeavor**
opens the same bounded workflow with an existing-record selector. Both return to minutes.

Creation requires `manage_minutes` and `manage_agendas`; linking an existing record
requires `manage_minutes`, matching the existing item editor. Hide unauthorized actions
and enforce the same grants on submission. No new grant or official-record authority
is implied by minutes editing.

## AI suggestion and confirmation

Add a source-cited `endeavor_proposal` suggestion targeting an exact existing MinutesItem.
The AI may suggest a new title/description and why continuing tracking is warranted,
or propose an exact existing Endeavor id supplied in its context. It must first prefer
reuse, omit routine topics and mere brainstorming, and cite transcript support for the
Post taking on continuing work. Skip items with an already confirmed link. AI generation
only stores suggestions; it creates no Endeavor and changes no item links.

The proposal card shows the proposed record, rationale, and transcript lines. **Review
and create** and **Edit proposal** open the manual creation form with the suggested text.
**Link existing** opens its existing-record mode; **Dismiss** uses ordinary audited
discard. A suggested existing record is preselected, subject to human confirmation.
Unplanned business must first become a minutes item through ordinary review; no title
matching or speculative target is used to attach a proposal to a not-yet-created item.

Confirmation locks the parent minutes and rechecks draft state, verifies the item's
submitted lock version, and atomically creates/links. AI confirmation also records
reviewer/time/application provenance; a manually created Endeavor records its creator.
Repeated or stale confirmation cannot create duplicate records. Exact
normalized title matches prevent accidental duplicate creation in this workflow and
direct the officer to existing records. Similar names remain a human identity decision.
Cross-meeting proposals, sections, and cross-organization Endeavors are rejected.

The original AI payload remains immutable during review; corrected form values are used
to create the record, with the resulting record identified in the review provenance.
Existing generic "use suggestion" cannot implicitly create an Endeavor. The private
review API requires an explicit `endeavor_action` of `create` or `link`, an item
`lock_version`, and, for creation, human-confirmed title/body; linking needs an exact
organization-scoped `endeavor_id`. Normal suggestion review/discard behavior is retained.
Historical runs and existing suggestions remain readable. A narrow migration extends
the suggestion-kind check constraint; it changes no historical data. Rolling it back
after proposals have been stored safely refuses rather than deleting those audit rows.
Queued runs whose recorded prompt/schema predates this change fail before a provider
call with a retry instruction; completed runs retain their original provenance.

## API parity design

Expose the same atomic manual confirmation as
`POST /api/meetings/:meeting_id/minutes/items/:item_id/endeavor`. Flat JSON must
include `endeavor_action` and the current **item** `lock_version`. Creation accepts
reviewed `title`/`body` and requires both minutes and agenda management; linking or
changing a link accepts an exact organization-scoped `endeavor_id` and requires
minutes management. Reuse the web confirmation service so draft locks, duplicate
checks, rollback, and source preservation remain identical. Return the updated item
and the confirmed Endeavor; do not require agents to create a potentially orphaned
record in a separate request. Existing minutes detail, Endeavor listing, and AI run
detail provide the form's starting text, choices, item versions, and proposal evidence
references, so no separate preview endpoint is needed. AI run detail accepts explicit
`include_source=true` to return each proposal's numbered `source_excerpt` using the
same normalization as the web evidence ribbon. Omit excerpts by default; return null
when the restricted transcript has been purged. Agents must not interpret normalized
line numbers as raw file line offsets.

AI proposals continue through their scoped `use`, `edit`, or `discard` endpoints.
Confirmation must include an explicit create/link choice, reviewed values, and current
item version; an empty use request cannot create a record. Keep original proposal
payload and reviewer/application provenance readable. Use `409` for stale manual
confirmation; existing suggestion review reports rejected review as `422`. Advertise
creation only to callers with both grants, and linking to minutes managers. Document
exact bearer retries, source review, and all web-equivalent paths in the generated
handbook and `docs/DISCUSSION_TOPICS_API.md`; test session and bearer execution with
synthetic records, including locked minutes and cross-scope input.

## Visual direction before implementation

Follow The 1919: navy `#0A2240`, working navy `#0D2C54`, gold `#C6A15B`, ivory `#FCFAF1`,
officer blue `#2F5F87`, and graphite `#303740`. System sans is the working face; Georgia
continues to identify rendered meeting records. Keep 16px controls/body, 14px helpers,
13px labels, existing focus treatments, and naturally wrapping actions at 390px.

The signature is a quiet gold-ruled **Continuing Post work** strip inside the relevant
minutes item, keeping the identity action beside its discussion. Avoid a separate
dashboard or promotion wizard. The short form uses the existing bounded panel and a
meeting/topic destination, followed by editable title/description or the existing-record
selector. An ordinary text area makes this summary easy to review without duplicating
the rich-text minutes editor. The AI source ribbon remains the evidence anchor.

```text
Discussion item and recorded minutes
  | Continuing Post work |
  Create Endeavor from this discussion · Link existing Endeavor

Review proposed Endeavor
  Meeting / discussion title
  Why continuing tracking is suggested + cited transcript lines
  [Title                       ]
  [Description                 ]
  Existing Endeavors: [recognizable names / link existing]
  [Create and link] [Link existing instead] [Cancel]
```

Critique desktop and 390px rendered results, including long topic titles, evidence,
existing choices, validation retention, keyboard focus, and action wrapping.

The rendered review kept creation in one short form, with readable source evidence
above the human-confirmed title and description. The new proposal's ribbon/labels were
raised to 13px, evidence and helpers to at least 14px, and actions to 16px with 44px
targets. At 390px the destination, evidence, and action row wrap inside the bounded
column without overflow; tabbing from the title reaches the description. The existing
minutes wording remains visually separate from the gold continuing-work action strip.

## Verification

Use synthetic provider responses only. Test generation without mutations, id/source
scope, reuse suggestions, explicit confirmation, grant checks, drafts and locked records,
stale/double submissions, duplicate-title handling, validation rollback, source-wording
preservation, and provenance. Browser coverage exercises manual creation, AI editing and
confirmation, existing linking, and dismissal. Run relevant lint, full application
regressions and security checks because this crosses identity and meeting-record paths.

Verified locally September 30, 2026:

- Application suite: 1,062 tests, 7,766 assertions, no failures/errors/skips.
- Browser suite: 41 tests, 484 assertions, no failures/errors/skips. A final long-title
  proposal review at 390px also passed (1 test, 14 assertions).
- Desktop and 390px creation, AI proposal/evidence, and minutes-workspace screenshots
  reviewed. No horizontal overflow; keyboard navigation reaches the description.
- Focused Ruby lint passed; Brakeman reported no errors or warnings; Bundler Audit found
  no vulnerabilities. Documentation references and diff whitespace checked.
- The migration was applied to the test database. No development/production data was
  migrated, and no real transcript or paid AI request was used. Synthetic tests prove
  mechanics and boundaries, not live model suggestion quality.

The queued-version regression exposed an existing provider Error constant defined in
the Result file. Moving it to its own Rails-autoloaded file preserves the exception
contract and lets failures before any provider result be handled reliably.

The subsequent API parity implementation passed 57 focused API tests (760 assertions)
and the full 1,074-test application suite (7,955 assertions), with no failures, errors,
or skips. Ten affected Ruby files passed lint; Brakeman had no errors or warnings and
Bundler Audit found no vulnerabilities. See [the API contract](DISCUSSION_TOPICS_API.md)
for session/bearer examples, explicit source reads, confirmation and dismissal, and
the exact permission/error/retry boundaries. This follow-up changes no web UI.
