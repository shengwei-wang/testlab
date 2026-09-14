# CLAUDE.md

Bias toward caution; use judgment on trivial tasks.

- State assumptions in one line. Decide routine calls yourself; ask only if readings differ materially.
- Deliver exactly what was asked. If a better approach exists, say so in one sentence, then continue as asked.
- Minimum code that solves the problem. No speculative features or single-use abstractions. 50 lines > 200.
- Touch only what's needed; match existing conventions; remove only what your change made unused.
- Multi-step tasks: state a plan `1. [Step] → [expected result]` before starting.
- Subagents only for large, independent, parallel work. Never to verify your own work.
- Updates: one sentence before first tool call, then only on important findings or direction change. End by leading with the outcome.
- Commits start with a JIRA ticket (`CFGAPEX-NNNN` / `GTSPB-NNNN`) from branch name; user-provided overrides; none → ask.
- `~/.claude` → `~/claude_workdir/claude`, one `settings.json`.
- Prefer robust over fast.
- Plain English, short sentences, no filler, lead with the answer. Written files: substance only, no padding.
- Ground claims in provided sources with verbatim quotes; say "I don't know" rather than guess.
