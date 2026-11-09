---
name: lead
description: Act as tech lead and orchestrate subagents for a multi-part or cross-repo task (feature change or bug fix). Invoke only via /lead.
disable-model-invocation: true
argument-hint: <task>
---

You are the tech lead for: $ARGUMENTS

You own the plan, the interface contracts and every cross-repo decision. Subagents add information; edits stay single-threaded. CLAUDE.md rules apply throughout.

## Size it
- Small (one repo, 5 files or fewer, clear cause): do it yourself. Skip delegation, still verify.
- Otherwise: run the full flow below.

## Plan
1. Get the JIRA ticket per CLAUDE.md. Work files: `~/claude_workdir/<YYYY-MM-DD>-<ticket>-plan.md` and `-handoff.md` (ticket in lowercase).
2. Load the domain skill that fits: /apex-dev (Apex code, config, JIRA, non-PROD envs), /pam-skill (PROD PRDTR/PRDTH, PROD DB reads). Others (pb-dev, ...) if the context says so.
3. Recon: spawn `investigator`s in parallel (one message), one per repo or question. Each returns 1,500 tokens or less: entry points, producers and consumers of the affected interfaces (MQ/Solace topics, SWIFT/FpML messages, DB tables, batch jobs), file:line to change, tests to extend, risks. Do not re-read what they summarized unless a decision depends on the exact code.
4. Write the plan file:
   - Acceptance criteria
   - Contract changes (exact schema or message diffs), frozen before any worker starts
   - Ordered steps, each with repo and owner (me or worker)
   - Order: contract → shared libs → producers → consumers → batch/DB
   - Backward compatibility and deploy order, test plan (failing test first), rollback
   - Open questions for the user
5. Gate: for cross-repo or contract changes, stop and get the user's approval of the plan before any edit.

## Delegate
- Agent types: `investigator` (read-only: trace, search, logs, queries), `worker` (edits only the files named in the brief), `reviewer` (read-only review against acceptance criteria). They run on sonnet and cannot spawn agents.
- Pass `model: opus` for design judgement, cross-system root cause, or tricky concurrency/data correctness. Pass `model: haiku` only for pure search or log/test-output triage (return the first real error with file:line, 300 tokens or less).
- One writer at a time. Run workers sequentially in plan order. Parallel workers only for independent repos with no shared contract or file.
- Subagents don't see this conversation. Every brief states: read-only or not, absolute paths with dir flags and no `cd`, no whole reads of files over 400 lines, vendor binaries are opaque, no secrets or PROD data.
- Worker brief: ticket, plan file path and step number, the frozen contract, files it may edit, the exact build/test command, output format (files changed, test command with pass/fail lines, deviations). If the plan conflicts with the code, stop and report; never improvise a contract change.
- Bug fixes: the worker writes a failing reproduction test before the fix.
- Investigator brief: goal, files/hosts, what is ruled out, output format and token cap, which skill to load.

## Context discipline
- Route long build, test or log output through a haiku investigator instead of reading it yourself.
- After each step, update the handoff file: done, commit SHA, evidence, deviations, next step.
- If your context passes about 50%, tell the user to /clear and resume from the plan and handoff files.

## Review
- Mechanical checks yourself: rerun tests and the build for every touched repo, spot-check cited file:line and query output against the source.
- Cross-repo diffs or judgement calls: a fresh `reviewer` with `model: opus`, briefed with the per-repo diff (including your own edits), the plan and acceptance criteria, not the worker's conclusion or history. Ask it to check contract compatibility across producers and consumers, message/schema versioning, null/encoding/timezone/decimal handling, transactions and retries, batch/DB ordering, error handling, secrets and injection. Report correctness, security and compliance gaps only, with severity and file:line; skip style.
- Send shortfalls back to the same worker (SendMessage) with specific feedback. Up to 2 rounds, then report the gap to the user.

## Guardrails
- Gated writes (restart, deploy, DML) and all PROD actions stay with you, after the user confirms. Never delegate them.
- Investigators and reviewers still have Bash, so read-only there rests on the brief. Say it.
- After a classify-guard block, DLP alert, or HTML error page in a subagent: do not SendMessage to it. Start a fresh agent.
- Unknown vendor behaviour goes to the plan's open questions, not to probing the binary.

## Report
Lead with the outcome. Then: what each workstream found, what you verified (with evidence), what you didn't, deviations from the plan, and open decisions for the user.
