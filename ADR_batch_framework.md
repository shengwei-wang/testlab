# Architectural Decision Records — Batch Framework

All decisions resolved in the design session (May 2026).
Each ADR is a permanent record. To revisit a decision, create a new ADR that supersedes it — do not edit history.

---

## ADR-0001 — Pure Python, No Bash Hybrid

**Status:** Accepted

**Context:** Team spans Mac and Windows laptops with a shared Linux dev server. Previous jobs used bash and perl.

**Decision:** Framework code is pure Python only. Bash role is limited to the thinnest possible wrapper: activate venv, call Python runner. Nothing else in bash.

**Consequences:** Better AI tool effectiveness, consistent cross-OS behaviour, testability, stronger error handling. Bash wrapper is intentionally throwaway.

**Rejected:** Bash-Python hybrid (common pattern for Unix batch jobs). Rejected because AI tools are far less effective on bash, and error handling is weaker.

---

## ADR-0002 — uv for Package Management

**Status:** Accepted

**Context:** Need cross-platform dependency management with a lockfile.

**Decision:** `pyproject.toml` + `uv.lock` managed by `uv`. `uv sync --frozen` on deploy. Never `uv run` at runtime — call venv Python directly.

**Consequences:** 10-100x faster installs than pip. Lockfile guarantees reproducibility. `--frozen` flag prevents runtime package resolution.

**Rejected:** pip + requirements.txt (slower, no lockfile guarantees). pip-tools (additional tooling without uv's speed benefit).

---

## ADR-0003 — Shared Venv on Dev VM

**Status:** Accepted

**Context:** Phase 1 runtime is a Linux VM. Jobs share a narrow dependency profile.

**Decision:** One shared venv on the dev VM. All jobs use it. Managed by deploy pipeline only — IT support never manually pip-installs.

**Consequences:** Simple, low overhead. Acceptable for Phase 1. Phase 2 (containers) solves per-job isolation automatically.

**Rejected:** Per-job venvs (unnecessary overhead for Phase 1 given shared dependency profile).

---

## ADR-0004 — Control-M as Sole Scheduler

**Status:** Accepted

**Context:** Control-M is the company-mandated scheduler for all batch jobs.

**Decision:** Control-M owns all scheduling, job dependencies, file watchers, and calendar logic. The framework does not implement any scheduler behaviour.

**Consequences:** Framework is simpler. Control-M Jobs-as-Code (Automation API) in JSON defines the schedule. Framework only responds to invocation.

**Rejected:** Custom scheduler, custom dependency logic. Not in scope at any phase.

---

## ADR-0005 — Two-Layer Config: Git YAML + Operational DB

**Status:** Accepted

**Context:** Structural config needs Git version control and change management. Operational config (email DLs, SFTP paths) needs same-day IT-support editability without a PR.

**Decision:** Structural config (job type, handler, stored proc, transport method, business date rules) lives in Git-controlled YAML. Operational config (email DL, SFTP destination, filename pattern, account list) lives in a DB table editable by IT support via service ticket.

**Merge order at runtime:** `env YAML → structural YAML → operational DB config → Vault secrets = JobContext`

**Consequences:** Git retains audit trail for structural decisions. IT support can update operational values same-day. Operational DB becomes the GUI data source when the OPS portal is built (deferred).

**Rejected:** All config in Git (too slow for IT support use cases). All config in DB (loses version control and AI tool effectiveness on flat files).

---

## ADR-0006 — Vault AppRole for Secrets, Secrets Manifest in Git

**Status:** Accepted

**Context:** Company mandates HashiCorp Vault for all secrets and passwords. Capital Markets requires full auditability.

**Decision:** Vault AppRole auth (role_id in Git, secret_id on VM). Secrets fetched at job startup, injected into `ctx.secrets`. A `config/secrets_manifest.yaml` in Git lists all Vault paths and key names — never values.

**Consequences:** Secrets never in code, YAML, or env vars at rest. Manifest gives full discoverability — developers grep the repo to find any secret reference. IT support uses manifest as authoritative list for Vault management.

**Phase 2 change:** AppRole replaced by K8s auth. No other code changes required.

**Rejected:** Environment variables at rest (audit risk). `.env` files (less auditable than Vault). Token auth (expires, needs renewal logic).

---

## ADR-0007 — Business Date Delegates to get_bus_day in Sybase

**Status:** Accepted

**Context:** Business date rules (CAD/USD holidays, weekday roll) already implemented and tested in Sybase function `get_bus_day(currency, offset)`.

**Decision:** Framework calls `get_bus_day` at startup based on declarative YAML config per job. Jobs never compute their own business date. Control-M `--business-date` flag overrides for reruns.

**Consequences:** Single source of truth for holiday calendars. Eliminates the biggest source of bugs in legacy jobs (each computing its own date independently). Eliminates the "copy script and hardcode date" rerun pattern.

**Rejected:** Reimplementing holiday calendar logic in Python (duplication, drift risk, migration cost).

---

## ADR-0008 — structlog for Logging, Human-Readable Now, JSON-Ready

**Status:** Accepted

**Context:** Phase 1 is a Linux VM. Devs and IT support read logs on the VM. Phase 2 will be containers where JSON-to-stdout is standard.

**Decision:** structlog with human-readable output to file and console for Phase 1. JSON renderer configured but disabled — one flag flip enables it for Phase 2. BoundLogger auto-attaches `job_name`, `business_date`, `env` to every log line.

**Consequences:** Readable logs now. Zero migration cost when containers ship.

**Rejected:** Plain Python logging (no structured context auto-attachment). JSON-only now (unreadable for IT support on VM).

---

## ADR-0009 — Operational Metadata in job_runs Table, Main Sybase DB

**Status:** Accepted

**Context:** Need audit trail, SLA tracking, and debug/replay capability. Want to minimise DB infrastructure changes.

**Decision:** `job_runs` table in main Sybase DB. Phase 1 fields: `job_name`, `start_time`, `end_time`, `status`. File load jobs also capture file stats (filename, size, row counts, records loaded). Framework writes this — job handlers never touch it.

**Consequences:** Audit trail available immediately. Foundation for OPS portal (deferred). No new DB infrastructure required.

**Rejected:** Separate DB for operational metadata (extra infrastructure, not justified for Phase 1). Events table (deferred — start/end/status sufficient for Phase 1).

---

## ADR-0010 — Type-Specific Handler Subclasses, Added Incrementally

**Status:** Accepted

**Context:** Job inventory has meaningfully different job types with different context needs.

**Decision:** `BaseJobHandler` provides shared framework wiring. Type-specific subclasses (`FileLoadJobHandler`, `ReportJobHandler`, `CyclicJobHandler`) add context appropriate for that job type. New types added only as real jobs in R2/R3 surface the need.

**Consequences:** Offshore developers pick the right base class — correct `ctx` attributes and framework behaviours are automatic. Job handlers stay thin. Framework protects developers from framework complexity.

**Rejected:** Single universal base handler (cluttered context, confusing at scale across 250 jobs). All handler types defined upfront in R1 (over-engineering before R2 reveals actual needs).

---

## ADR-0011 — AI-Native SDLC: CONTEXT.md + ADRs + AI_INSTRUCTIONS.md, PR-Enforced

**Status:** Accepted

**Context:** Team will use AI tools (GitHub Copilot, Windsurf, Claude Code, internal AI platform) as primary development assistants across all phases.

**Decision:** Three living documents form the AI-native foundation:
- `CONTEXT.md` — domain glossary, authoritative vocabulary for all AI sessions
- `docs/adr/` — architectural decisions, prevents AI tools re-litigating settled choices
- `AI_INSTRUCTIONS.md` — canonical AI instructions, with thin tool-specific wrappers (`CLAUDE.md`, `.github/copilot-instructions.md`, `.windsurfrules`)

PR requirement: new module → update `CONTEXT.md`. New architectural decision → new ADR. Abid enforces in code review.

**Skills adopted:** grill-me (design decisions), to-prd (PRD generation), to-issues (task breakdown), tdd (implementation), improve-codebase-architecture (ongoing review).

**Consequences:** Every AI session starts context-aware. Offshore developers can use AI tools effectively without framework deep-dive. Design decisions accumulate in searchable, diff-able form.

**Rejected:** ADRs as optional documentation (they drift and become useless). Per-session AI context (no team-level consistency). Tool-specific files as primary source (duplication and drift across tools).

---

## ADR-0012 — VS Code Remote SSH as Dev Workflow Standard

**Status:** Accepted

**Context:** Team uses VS Code and IntelliJ. Sybase driver only works on Linux dev VM. Previous workflow: edit locally, SCP to VM, run remotely.

**Decision:** VS Code Remote SSH as team standard. Editor, terminal, Python interpreter, and Copilot all run in VM context. No sync step — developer works directly on VM.

**Consequences:** AI-assisted iteration cycle is seconds, not minutes. Copilot sees the real Python environment. IntelliJ users can use SSH interpreter feature as equivalent.

**Rejected:** Folder sync (still requires separate SSH terminal to run, breaks Copilot's interpreter context). Local development (sybpydb doesn't exist on local machines).

---

## ADR-0013 — Lazy DB Connection Factory on JobContext

**Status:** Accepted

**Context:** JobContext exposes four DB connections (sybase_main, sybase_ref, sybase_ops, oracle). Most jobs use only one or two.

**Decision:** DB connections are lazy properties on JobContext. Connection is only established when the property is first accessed. Jobs pay only the connection cost for what they actually use.

**Consequences:** Faster startup for simple jobs. No unnecessary connections to systems the job doesn't use.

**Rejected:** Eager connection at startup (wasteful, slower, connects to systems the job never touches).
