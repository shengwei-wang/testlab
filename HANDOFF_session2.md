# Batch Framework — Session 2 Handoff

Use this file to resume the design session in any AI chat (internal platform, Copilot, Windsurf).

Paste this at the start of your next session with this prompt:
> "I am a Capital Markets development manager building a Python batch job framework. Read this handoff document and act as my Executive Coach and Strategic Advisor. Lead with conclusions, flag trade-offs, end with one next action. When I say /grill-me, challenge my thinking with pointed questions one at a time."

---

## PROBLEM STATEMENT

**Primary problems:**
- 250-300 batch jobs running via Linux crontab on RHEL9 VM — brittle, no reuse, old bash/perl mix, poor logging
- Codebase inconsistency makes AI tooling ineffective

**Forcing function:** Company-mandated Control-M onboarding replaces crontab. Every job must be touched anyway — the framework rides this migration.

---

## TWO PARALLEL WORKSTREAMS

| Workstream | Scope | Target |
|---|---|---|
| Control-M onboarding | Replace crontab calls as-is, coarse-grain dependencies | End of June |
| Python batch rewrite | Rewrite all jobs using new framework, AI-assisted | End of December |

Control-M onboarding calls existing scripts unchanged. The rewrite replaces them incrementally.

---

## WHAT THE JOBS LOOK LIKE

~250-300 jobs total. Roughly:
- ~150 report jobs (70-80% external clients, custom formats per client)
- Start-of-day batch: imports from book-of-record system, loads exchange rates, index rates, security reference data, price data
- End-of-day: produces batch files for downstream systems
- Intraday: cyclic SFTP pull, database condition monitors

**Job patterns:**
1. Inbound file → parse → Sybase BCP/insert to staging table
2. Pull from Oracle/SQL Server/Sybase → load to Sybase → format → email/SFTP/NAS
3. Pull from Sybase → format as report/CSV → email/SFTP/NAS
4. API call → load to Sybase
5. Pull from Sybase → API POST

**Key insight:** Business logic lives in the database (stored procs). Bash/perl is glue — parse, move, format, trigger. AI tooling replaces the glue.

---

## DEFERRED (not in scope this year)

- Reports module GUI (OPS portal for report visibility, account list config, job rerun)
- Database schema refactoring
- Core account calculation module rewrite
- Web UI of any kind
- Dockerfile / Kubernetes (Phase 2)

---

## ALL RESOLVED DECISIONS

### Infrastructure & Runtime

| Decision | Resolved |
|---|---|
| Language | Pure Python only |
| Runtime invocation | `run_job.sh BATCH_JOB_NAME --business-date DATE --env ENV` → venv Python directly |
| Venv management | `uv sync --frozen` on deploy (Ansible preferred, IT support manual as interim). Never `uv run` at runtime |
| Dev workflow | VS Code Remote SSH as team standard. Devs work directly on dev VM |
| Phase 1 deployment | GitHub Actions → Ansible → Linux VM → shared venv |
| Phase 2 runtime | Kubernetes (on-prem, platform-team supported) — deferred |
| Scheduling | Control-M owns it entirely. No custom scheduler |

### Configuration Architecture

Two-layer config — merged at runtime in this order:

```
config/env/{dev,uat,prod}.yaml     ← infrastructure coords (hostnames, ports, paths)
+ config/jobs/{job_name}.yaml      ← structural job config (job type, date rules, transport method)
+ DB operational config table      ← tunable values (email DL, SFTP path, filename pattern)
+ Vault secrets                    ← passwords, private keys — never in code or YAML
= JobContext
```

**Rule:** Structural config (job type, stored proc, transport method) → Git only. Operational config (email DL, SFTP path, account list) → DB table, IT-support editable same-day via service ticket.

### Secrets Management

- **Tool:** HashiCorp Vault, AppRole auth (role_id non-secret in Git, secret_id on VM)
- **Secrets manifest** in Git at `config/secrets_manifest.yaml` — Vault paths + key names only, never values
- Vault fetched at job startup, injected into `ctx.secrets`
- Phase 2: swap AppRole for K8s auth, no other code change

### JobContext

```python
@dataclass
class JobContext:
    job_name: str
    business_date: date
    env: str                    # dev / uat / prod
    logger: BoundLogger         # structlog — auto-attaches job_name, business_date, env
    config: JobConfig           # merged structural + operational
    secrets: SecretsClient
    _db: ConnectionFactory      # lazy — only connects when accessed

    @property
    def sybase_main(self): ...  # primary Sybase
    @property
    def sybase_ref(self): ...   # reference data Sybase
    @property
    def sybase_ops(self): ...   # ops Sybase
    @property
    def oracle(self): ...       # Oracle (other system)
```

### Logging

- **Library:** structlog
- **Format now:** Human-readable to file + console (devs and IT support read these on VM)
- **Format later:** JSON to stdout (one config flag flip — no code migration needed)
- BoundLogger attaches `job_name`, `business_date`, `env` to every log line automatically

### Business Date

- **Source of truth:** Existing Sybase function `get_bus_day(currency, offset)`
- Framework calls it at startup based on job YAML config. Jobs never compute their own date.
- Control-M passes `--business-date` flag to override (for reruns and recovery)
- Eliminates the "copy script and hardcode date" workaround

```yaml
# config/jobs/fx_rate_load.yaml
business_date:
  primary:
    currency: CAD
    offset: 0
  also_need:
    - currency: USD
      offset: -1
```

### Operational Metadata

- Table: `job_runs` in main Sybase DB
- Written by framework on job completion — job handlers never touch it
- Phase 1 fields: `job_name`, `start_time`, `end_time`, `status`
- File load jobs also capture: filename, file timestamp, filesize, header/trailer values, data row count, records loaded to Sybase

### Handler Pattern

```python
class FxRateLoadJob(FileLoadJobHandler):
    def execute(self, ctx: JobContext) -> JobResult:
        rows = parse_fx_file(ctx.inbound_file)
        ctx.sybase_main.execute_proc("sp_load_fx_rates", rows)
        return JobResult.success(rows_loaded=len(rows))
```

Handler contains only: what to read, what to compute/transform, what to write.
Framework handles: logging, retry, metadata write, SFTP, email, secrets, date resolution.

### Handler Types (incremental — add as R2 surfaces need)

- `BaseJobHandler` — shared framework wiring
- `FileLoadJobHandler(BaseJobHandler)` — inbound file processing, file stats capture
- `ReportJobHandler(BaseJobHandler)` — query, format, deliver
- `CyclicJobHandler(BaseJobHandler)` — polling, condition check, early exit
- More added in R2/R3 as real jobs reveal what's needed

### Team

| Person | Role |
|---|---|
| You | Framework designer, R1 primary builder, strategic driver |
| Abid (Team Lead) | Technical owner from R2 onward, offshore coordination, code review enforcer |
| Vlad (IC, peer) | R2 real job rewrites — parallel track |
| 2 offshore devs | R3 bulk migration, execute against templates |

---

## PHASE 1 — THREE RELEASES

### R1 — Framework Skeleton (target: mid-July)

**Delivers:**
- Repo scaffolding: `CONTEXT.md`, `docs/adr/`, `config/`, `pyproject.toml`, `uv.lock`
- AI instruction files: `AI_INSTRUCTIONS.md` (canonical) + thin wrappers: `CLAUDE.md`, `.github/copilot-instructions.md`, `.windsurfrules`
- Framework skeleton: `JobContext`, `BaseJobHandler`, `FileLoadJobHandler`
- Config stack: env YAML loader, structural YAML loader, operational DB config reader, Vault AppRole integration, merge logic
- Business date resolver: wraps `get_bus_day`, declarative YAML config, Control-M override flag
- Structured logging: structlog, human-readable, JSON-ready
- `job_runs` table schema + framework write on completion
- Secrets manifest pattern + Vault fetch at startup
- One dummy job that exercises the full stack end-to-end
- Bash wrapper: `run_job.sh`
- GitHub Actions → Ansible deploy to dev VM
- VS Code Remote SSH setup guide in README

**Definition of done:** Dummy job runs end-to-end on dev VM via bash wrapper, reads from Vault, resolves business date via `get_bus_day`, writes `job_runs` record, produces readable logs. Abid can read and explain every line.

**Explicitly excludes:** SFTP/email/API transport, `ReportJobHandler`, `CyclicJobHandler`, any real job migration.

### R2 — First Real Jobs (target: end of August)

Rewrite 1-2 real existing jobs using the framework. Framework meets reality. Gaps get fixed. Defines `ReportJobHandler` and other subclasses as needed.

**R2 is the productivity checkpoint.** If it takes >6 weeks, re-scope R3 — don't push harder.

### R3 — AI-Assisted Bulk Migration (target: December)

Offshore team executes bulk migration using R2 jobs as the AI reference example. AI tools get the actual working jobs as spec, not abstract documentation.

**Realistic outcome:** 60-70% of jobs migrated by December. Remainder tagged Q1. That's still a major win — don't let completion pressure compromise framework quality.

---

## AI-NATIVE SDLC

**Living documents in repo (PR-enforced — Abid owns in code review):**
- `CONTEXT.md` — domain glossary. New concept introduced = update required before merge
- `docs/adr/` — architectural decisions. New decision = ADR before merge

**Skills to embed in repo and use in AI sessions:**
- `/grill-me` — design decisions, stress-testing plans
- `/to-prd` — convert resolved decisions to PRD
- `/to-issues` — break PRD into GitHub issues
- `/tdd` — vertical slice TDD for framework modules
- `/improve-codebase-architecture` — ongoing architecture review using CONTEXT.md vocabulary

---

## CRITICAL RISKS

1. **Resource concentration** — you are the R1 bottleneck. If you get pulled by promotion demands, R1 slips and everything cascades.
2. **No job inventory stratification** — 250-300 jobs with unknown complexity distribution. Do this before writing the PRD.
3. **AI productivity is assumed, not measured** — R2 is the first real data point. Let it inform R3 scope.
4. **No cutover validation pattern** — how does a rewritten report job prove it produces equivalent output? Design this before R2 ships.
5. **No rollback story** — define before replacing any production job.

---

## IMMEDIATE NEXT ACTIONS (in order)

1. **Stratify the job inventory** — 1-2 days with Abid. Categorize all jobs: type + simple/medium/complex. This changes everything about R3 scoping.
2. **Run `/to-prd`** on this session to generate the R1 PRD. That's the charter.
3. **Start R1 repo scaffolding** — `CONTEXT.md`, `docs/adr/`, `AI_INSTRUCTIONS.md` first. Code second.
