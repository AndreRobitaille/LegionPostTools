# Agent Environment and GPT-6 Astra

Migration reviewed September 5, 2026. This document records configuration and audit
results; it does not authorize releases, plugin installs, or paid generation.

## Shared guidance

`AGENTS.md` is the common project policy; `CLAUDE.md` imports it. Readability requirements
formerly visible only to Claude now apply to all agents. Design remains required at the
scope of the change, with visual skill use and desktop/narrow review for UI changes.
Verification is proportional, authorization persists across a session, and engineering
permission remains separate from official-record actions. Subagents are not mandatory.

`docs/superpowers/AGENTS.md` and its Claude entry point distinguish dated design rationale
from execution instructions. The directory and its substantive specs remain intact.
Roadmap work is not automatically authorized. Current lifecycle docs distinguish
corrections before membership approval from immutable accepted records and planned amendments.

Inherited Claude project memories include obsolete July branch/release claims, a claim
that there is only one rich-text field, and an older dashboard design status. Treat these
as historical context and use current code and feature docs. Those memory files were not
rewritten. Their advice against overbuilding does not override official-record audit
requirements. The inherited generic `simplify` skill assumes React/TypeScript and links
to `http://CLAUDE.md`; root guidance makes language applicability and local authority clear.
No new framework conventions or mandatory simplification pass were introduced.

## Model compatibility

The minutes provider now defaults to `gpt-6-astra`. `OPENAI_MINUTES_MODEL` still overrides
the default; historical run records and historical-model fixtures remain unchanged.
High reasoning, medium verbosity, the 360-second timeout, output cap, and credential
resolution are preserved. No fallback router exists in this provider.

The existing Responses request already uses strict structured output, no tools, and
`store: false`, with no sampling, logprob, or old cache-retention parameters. It needs
no endpoint migration. The installed OpenAI Ruby SDK 0.83.0 accepts arbitrary model
strings. Preserve the versioned minutes prompt and its evidence, privacy, source-ID,
and human-review requirements; developer-agent autonomy is not drafting authority.

For future configuration changes, Astra does not support `none`/`minimal` reasoning;
use `low` or a supported higher effort. Tool calling requires Responses. Do not add
`temperature`, `top_p`, or logprob parameters. No cache or service-tier changes are needed
for this application request. Official guidance restricts fast/priority processing with
EU data residency; no EU endpoint or residency configuration was found locally.

Source: [official Astra migration and prompting guidance](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra).

## Inherited plugins and hooks

The inspected Codex user config already selected Astra with medium reasoning and fast
service. It was preserved, including permissions, other plugins, and unrelated settings.
The user-level `AGENTS.md` was empty; no ancestor project guidance or repository hooks,
skills, or model overrides were found beyond the documented root Claude settings.

Claude user settings now disable `superpowers@claude-plugins-official` and
`security-guidance@claude-plugins-official`. `claude-code-setup` was already disabled.
No installed/enabled cowork-plugin-management or Anthropic DOCX/PDF/XLSX/PPTX/skill-creator
skills were found, so no speculative entries were added. Native document, PDF,
spreadsheet, presentation, and skill-creator equivalents are installed. Other plugins,
including frontend-design, Ruby LSP, and Codex Security, were preserved. Nothing was uninstalled.

The installed Superpowers 6.3.0 startup launcher produces valid Claude hook JSON, but
injects mandatory skill invocation and downstream planning/approval workflows. Disabling
the plugin removes that behavior on reload; changing a model alone would not. The installed
security-guidance 2.0.7 hooks can bootstrap an SDK at startup and schedule LLM reviews on
stop/commit/push with asynchronous rewakes. They were inspected without running installation
or paid review actions, then disabled as requested.

Both Herdr session hooks are retained. Synthetic tests verify shell syntax, quiet no-op
behavior outside Herdr, and reporting through an isolated local Unix socket. They do not
inject agent instructions. Ruby LSP's missing standalone manifest is intentional: its
marketplace entry supplies `lspServers` with `strict: false`, and `ruby-lsp` resolves on
PATH. No launcher repair or plugin removal was warranted.

Global backup: `/home/andre/.claude/backups/astra-migration-20260905-QqrCwu/` contains
`claude-settings.json` and `codex-config.toml`. Only the two requested enabled plugin
flags differ from the backup. To roll back later, restore those flags selectively if
other settings have changed; the full backup is available for comparison.

## Verification and activation

- Focused provider/generation tests: 10 tests, 62 assertions, zero failures/errors/skips.
- RuboCop: three changed Ruby files, no offenses; sandbox cache writes were unavailable.
- JSON/TOML parsing and backup comparison passed; native equivalent skill paths exist.
- Installed SDK request serialization accepts `gpt-6-astra`; no SDK upgrade needed.
- Both retained Herdr hooks and the Superpowers launcher passed synthetic checks above.
- No UI or lifecycle behavior changed, so full-suite/browser/production checks were not run.

No paid API call was made. Account access to Astra and real transcript output quality
remain unverified; offline tests are not quality evaluation. Any future authorized
evaluation should use approved data, stage suggestions only, and retain human review.

Start a fresh Claude session (or restart Claude) to unload disabled plugins and injected
context. Fresh Codex sessions receive revised repository guidance; its default model
already needed no change. A future authorized application release must restart web/worker
processes to load the new provider constant. This migration did not commit, push, deploy,
or modify production configuration/data. The existing roadmap edit was preserved.
