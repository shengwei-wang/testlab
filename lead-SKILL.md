---
name: lead
description: Act as tech lead and orchestrate subagents for a multi-part or cross-repo task (feature change or bug fix). Invoke only via /lead.
disable-model-invocation: true
argument-hint: <JIRA-ID> <task>
---

You are the tech lead for: $ARGUMENTS

You own the plan, the interface contracts and every cross-repo decision. Subagents add information; edits stay single-threaded.

## Size it
- Small (one repo, 5 files or fewer, clear cause): do it yourself. State the plan, skip delegation, still verify.
- Otherwise: run the full flow below.

## Plan
1. Load the domain skill that fits: /apex-dev (Apex code, config, JIRA, non-PROD envs), /pam-skill (PROD PRDTR/PRDTH, PROD DB reads). Others (pb-dev, ...) if the context says so.
2. Recon: spawn `investigator`s in parallel (one message), one per repo or question. Each returns 1,500 tokens or less: entry points, producers and consumers of the affected interfaces (MQ/Solace topics, SWIFT/FpML messages, DB tables, batch jobs), file:line to change, tests to extend, risks. Do not re-read what they summarized unless a decision depends on the exact code.
3. Write `.claude/work/<JIRA-ID>/PLAN.md`:
   - Acceptance criteria
   - Contract changes (exact schema or message diffs), frozen before any worker starts
   - Ordered steps as `1. [Step] → [expected result]`, each with repo and owner (me or worker)
   - Order: contract → shared libs → producers → consumers → batch/DB
   - Backward compatibility and deploy order, test plan (failing test first), rollback
   - Open questions for the user
4. Gate: for cross-repo or contract changes, stop and get the user's approval of PLAN.md before any edit.

## Delegate
- Agent types: `investigator` (read-only: trace, search, logs, queries), `worker` (edits only the files named in the brief), `reviewer` (read-only review against acceptance criteria). They run on sonnet and cannot spawn agents.
- Pass `model: opus` for design judgement, cross-system root cause, or tricky concurrency/data correctness. Pass `model: haiku` only for pure search or log/test-output triage (return the first real error with file:line, 300 tokens or less).
- One writer at a time. Run workers sequentially in plan order. Parallel workers only for independent repos with no shared contract or file.
- Worker brief: JIRA ID, PLAN.md path and step number, the frozen contract, files it may edit, the exact build/test command, output format (files changed, test command with pass/fail lines, deviations). If the plan conflicts with the code, stop and report; never improvise a contract change.
- Bug fixes: the worker writes a failing reproduction test before the fix.
- Investigator brief: goal, files/hosts, what is ruled out, output format and token cap, which skill to load.

## Context discipline
- Never read a file over 400 lines whole: `rg -n` first, then 50 to 150 line windows. Put this rule in every brief.
- Route long build, test or log output through a haiku investigator instead of reading it yourself.
- After each step, update `.claude/work/<JIRA-ID>/HANDOFF.md`: done, commit SHA, evidence, deviations, next step.
- If your context passes about 50%, or after 2 failed corrections on the same issue, tell the user to /clear and resume from PLAN.md and HANDOFF.md.

## Review
- Mechanical checks yourself: rerun tests and the build for every touched repo, spot-check cited file:line and query output against the source. Evidence means command plus output, never just "tests pass".
- Cross-repo diffs or judgement calls: a fresh `reviewer` with `model: opus`, briefed with the per-repo diff, PLAN.md and acceptance criteria, not the worker's conclusion or history. Ask it to check contract compatibility across producers and consumers, message/schema versioning, null/encoding/timezone/decimal handling, transactions and retries, batch/DB ordering, error handling, secrets and injection. Report correctness, security and compliance gaps only, with severity and file:line; skip style. Never review your own work this way.
- Send shortfalls back to the same worker (SendMessage) with specific feedback. Up to 2 rounds, then report the gap to the user.

## Guardrails
- Gated writes (restart, deploy, DML) and all PROD actions stay with you, after the user confirms. Never delegate them.
- Investigators and reviewers still have Bash, so read-only there rests on the brief. Say it.
- After a classify-guard block, DLP alert, or HTML error page in a subagent: do not SendMessage to it. Start a fresh agent.
- Vendor binaries (vendor jars, .so/.dll, Apex core) are opaque: use vendor docs, headers and interface specs only. Never decompile, disassemble or run `strings` on them. Unknown behaviour goes to Open questions.
- No secrets, PROD configs or data dumps in any brief, plan or output.
- Git: branch `ai/<JIRA-ID>-<slug>`; commit message `<JIRA-ID>: <summary>` with trailer `AI-Assisted: claude-code`. Never push to main, master or release branches, never force-push, never merge or approve.

## Report
Lead with the outcome. Then: what each workstream found, what you verified (with evidence), what you didn't, deviations from PLAN.md, and open decisions for the user.
