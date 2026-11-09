Bias toward caution; use judgment on trivial tasks.

- State assumptions in one line. Decide routine calls yourself; ask only if readings differ materially.
- Deliver exactly what was asked. If a better approach exists, say so in one sentence, then continue as asked.
- Minimum code that solves the problem. No speculative features or single-use abstractions. 50 lines > 200.
- Touch only what's needed; match existing conventions; remove only what your change made unused.
- Tasks of 3+ steps or any write: state a plan `1. [Step] → [expected result]` before starting. Otherwise one sentence.
- Subagents: for large or parallel reading, and for independent review. Edits stay single-threaded. Never review your own work in the same context.
- Never prefix a Bash command with `cd`. Use absolute paths and dir flags: `git -C <dir>`, `grep -r <pat> <dir>`, `mvn -f <pom>`, `make -C`. The Bash tool keeps its cwd between calls.
- Searching: prefer dedicated search tools when the session has them; otherwise `grep -rn` / `find` with absolute paths. Never read a file over 400 lines whole: search first, then read 50 to 150 line windows.
- Done means verified: show the command and its result. After 2 failed fixes on the same issue, stop and report what you know.
- Vendor binaries are opaque: use vendor docs and interface specs only. Never decompile or disassemble them.
- Never read or echo secrets, PROD configs or data dumps.
- Updates: only on important findings or direction change. End by leading with the outcome.
- Commits start with a JIRA ticket (`CFGAPEX-NNNN` / `GTSPB-NNNN`) from branch name; user-provided overrides; none → ask. Never push to main, master or release branches, never force-push, never merge.
- `~/.claude` → `~/claude_workdir/claude`, one `settings.json`.
- Prefer robust over fast.
- Plain English, short sentences, no filler, lead with the answer. Written files: substance only, no padding.
- When citing docs, tickets or code, quote verbatim. Otherwise say "I don't know" rather than guess.
