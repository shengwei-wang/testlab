# Handoff: Batch job observability (stats tables + wrapper + jobstat CLI)

**Date:** 2026-09-13
**Session goal:** Design, via a grill-me session, the job stats/metadata tables and the reusable
capture utility for the legacy Control-M batch estate, so the tables survive the 2027 Python rewrite.
**Next session focus:** Validate every decision and assumption below against the real source code
and Control-M job definitions, then produce an implementation plan for the next 1-2 sprints.

> Status of everything in this document: **PROPOSAL, reached without access to the source code.**
> The next agent must treat each decision as a hypothesis to confirm or overturn against the repo.
> Nothing here was validated against real scripts, real Control-M definitions, or real Sybase DDL.

---

## Context summary

The team runs 250-300 legacy bash/ksh/perl batch jobs on RHEL9, scheduled by Control-M, backed by
Sybase ASE. Prod support has no insight into runs: no reliable start/end, no file stats, no row
counts through the load pipeline. A Python rewrite is targeted for 2027 but not started. This
workstream builds the stats tables and a capture layer now, fed from the legacy scripts, to power a
plain-language system health report in the team's GUI app (Java REST backend, DevExtreme grid).
The tables are intended to be the run-time metadata layer of the 2027 framework, shipped early.

## Work completed (this session)

- Ran a depth-first grill-me over 13 decision branches; all resolved (see Decisions).
- Analysed the current wrapper `run_controlM.sh` (ksh) from a screenshot. Findings in Risks.
- Defined a 9-table schema for sprints 1-2, plus 3 deferred health tables.
- Defined the wrapper and `jobstat` CLI contract.

## Decisions made

| # | Decision | Rationale |
|---|---|---|
| D1 | Health report never calls the Control-M API live. Run context arrives as arguments from the job definition (`%%JOBNAME`, `%%ORDERID`, `%%RUNCOUNT`, `%%$ODATE`); job definitions and dependencies come from an **offline export script** (Automation API `deploy jobs::get`) re-run after each release. | Report must work when Control-M is unhealthy; no auth/latency in the Java path; history preserved. |
| D2 | Job identity = `(ctm_folder, ctm_job_name)` with surrogate `job_id`. Script path is an attribute. | Multiple Control-M jobs call the same script; the scheduled unit is the identity. |
| D3 | A **Python wrapper replaces** (does not chain) `run_controlM.sh`. Byte-compatible log path and line format. Rolled out per Control-M folder over 2-3 releases; ksh wrapper kept as fallback. | Wrapper must see the output stream to derive status anyway; ksh wrapper has real bugs (see Risks); Python wrapper becomes the 2027 framework entry point. |
| D4 | `status` = pattern-derived from output (existing Control-M contract, ERROR/FATAL patterns from `logmessage_map.properties`). `exit_code` = raw child exit code, informational. `fail_reason` = first matched line. Mismatches surfaced in the report. | Changing the contract means revalidating every downstream Control-M condition; that is rewrite scope. |
| D5 | Wrapper resolves business date at start via existing Sybase `get_bus_day(currency, offset)`. `job.bus_date_rule` in {CAD, USD, BOTH, CALENDAR}; `job.primary_calendar`; `job_run.business_date` is the single reporting date; `job_run_calendar` holds one row per resolved calendar; `ctm_odate` stored alongside. | Jobs use CAD, USD, or both calendars; intraday jobs use calendar date. Child table avoids currency-named columns. |
| D6 | One wrapper launch = one `job_run` row. Unique on `(ctm_order_id, ctm_run_count)`. Control-M re-launched cyclics get one row per cycle; internally looping scripts get one row with iterations as `job_run_event` rows. `job.is_internal_loop` flag. | Both cyclic patterns exist. |
| D7 | `jobstat` CLI (Python, existing Sybase connector). Reads `JOBSTAT_RUN_ID` from environment exported by the wrapper. Commands: `event`, `file`, `deliver`, `metric`. Always exits 0. Never emits text matching ERROR/FATAL patterns (own prefix `JOBSTAT-WARN:`). If Sybase unreachable, spools JSONL to `$MSD/tmp/jobstat.<run_id>.jsonl`; wrapper flushes at end. ~10 calls per run max. | The stats layer must never fail a job or flip its status. |
| D8 | File-intrinsic stats are typed columns on `job_run_file`. Pipeline row counts are generic `job_run_metric` rows with a `metric_def` catalog and seeded names. | New counts need no DDL; catalog stops naming drift. |
| D9 | Health tables (`job_expectation`, `job_baseline`, `job_health_daily`) **deferred** until 3-4 weeks of real data exist. Sprints 1-2 ship capture only. | Bands designed on real variance are better; empty DDL is release noise. |
| D10 | `job` and `job_dependency` pre-loaded from the Control-M export script (source `CTM`). Wrapper auto-inserts a stub with source `AUTO` for unknown jobs; never fails the run. | Team has Control-M API access with own credentials. |
| D11 | Every run is stored, never overwritten. `trigger` in {CTM, MANUAL, RECON}, `run_by` (OS user). Manual prod runs must go through the wrapper (`--manual`), a runbook change. `superseded_by_run_id` set by the reconciler. Report uses a `latest run per job per business date` view. | Audit trail; rerun count is itself a health signal. |
| D12 | `job_run_file_delivery` child table: one outbound file can have many deliveries (NAS, EMAIL, SFTP, SCP, API). | "Generated but not delivered" and partial delivery must be expressible. |
| D13 | Args stored as-is (no secrets on Control-M command lines today; scripts source env files). Wrapper keeps a mask hook for `-p`, `--password`, `pwd=`, `token=` and `job.arg_mask_pattern`. `stderr_tail` (~2 KB) stored on failed runs. 13-month retention, monthly purge off-hours. Java reads through views with a read-only login; only wrapper, `jobstat`, export script, and reconciler write. | Defence in depth; queryable by more than the GUI. |

## Proposed schema (sprints 1-2, column level, to be turned into Sybase ASE DDL in the repo)

```
job
  job_id              int identity PK
  ctm_folder          varchar     ) unique together
  ctm_job_name        varchar     )
  script_path         varchar
  args_template       varchar     nullable
  job_type            varchar     file_load | report | cyclic | other
  is_internal_loop    bit
  bus_date_rule       varchar     CAD | USD | BOTH | CALENDAR
  primary_calendar    varchar     CAD | USD
  bus_date_offset     smallint    default 0
  owner_team          varchar     nullable
  arg_mask_pattern    varchar     nullable
  active              bit
  source              varchar     CTM | AUTO | MANUAL
  synced_at, created_at, updated_at

job_dependency
  job_id, depends_on_job_id, condition_name, source, synced_at

job_run
  run_id              bigint identity PK
  job_id              FK
  ctm_order_id        varchar     nullable (MANUAL)
  ctm_run_count       int         nullable
  ctm_odate           date        nullable
  business_date       date        reporting date, always set
  trigger             varchar     CTM | MANUAL | RECON
  run_by              varchar
  host                varchar
  pid                 int
  args                varchar
  start_ts, end_ts    datetime
  status              varchar     RUNNING | SUCCESS | FAILED | KILLED | UNKNOWN
  exit_code           int         nullable
  fail_reason         varchar     nullable
  stderr_tail         varchar     nullable, failed runs only
  log_path            varchar
  superseded_by_run_id bigint     nullable
  UNIQUE (ctm_order_id, ctm_run_count) where not null

job_run_calendar
  run_id, calendar, business_date

job_run_event
  event_id, run_id, seq, stage, event_ts, level, message

job_run_file
  file_id             bigint identity PK
  run_id              FK
  direction           IN | OUT
  file_name, file_path, size_bytes, file_mtime, file_owner
  business_date       date nullable   (the file's own date, may differ from run)
  total_rows, data_rows   int nullable
  header_text, trailer_text   varchar nullable
  recorded_at

job_run_file_delivery
  delivery_id, file_id, dest_type (NAS|EMAIL|SFTP|SCP|API), dest_target,
  attempted_at, delivered_at, status, detail

job_run_metric
  run_id, metric_name (FK metric_def), metric_value numeric, metric_text nullable,
  stage nullable, file_id nullable, recorded_at

metric_def
  metric_name PK, description, unit, higher_is_worse
  seed: rows.file.data, rows.csv, rows.staging, rows.loaded, rows.updated, rows.rejected
```

Deferred (do not create yet): `job_expectation`, `job_baseline`, `job_health_daily`.

## Wrapper and CLI contract (proposal)

```
# Control-M command line, per job definition
runjob.py --folder %%FOLDER --job %%JOBNAME --order %%ORDERID --run %%RUNCOUNT --odate %%$ODATE \
          -- /path/to/legacy_script.ksh arg1 arg2

runjob.py duties: insert job_run (RUNNING) -> resolve business date(s) -> export JOBSTAT_RUN_ID
  -> exec child with merged stdout/stderr -> stream lines to log file (same path/format as today)
  -> pattern-match ERROR/FATAL -> on exit: status, exit_code, fail_reason, stderr_tail, end_ts
  -> flush jobstat spool if present -> exit with Control-M-compatible code
  -> trap SIGTERM: forward to child, close run as KILLED
  -> --manual (no ctm args), --bypass (exec only, no DB), stats-DB failure never fails the job

jobstat event  <stage> [message]
jobstat file   --dir in|out --path P [--rows N --data-rows N --header "..." --trailer "..." --bus-date D]
jobstat deliver --file <name> --dest sftp:host:/path --status OK|FAIL [--detail "..."]
jobstat metric <name> <value> [--stage S] [--file <name>]
```

## Assumptions to verify against real code (do this FIRST, Opus, plan mode, read-only)

- [ ] Control-M AutoEdit variable names and whether `%%FOLDER`/`%%JOBNAME`/`%%ORDERID`/`%%RUNCOUNT`/`%%$ODATE` can be passed on the command line for your agent version.
- [ ] `run_controlM.sh` is the only wrapper in use; no jobs bypass it. Confirm the exact log path/line format to reproduce.
- [ ] What `LOGNAME=\`basename $APPLICATION\`.log` actually produces for jobs with arguments (looks broken; confirm).
- [ ] `logmessage_map.properties` is global, not per-application; pattern semantics (`grep -f`, unquoted echo).
- [ ] `get_bus_day(currency, offset)` signature and which jobs use CAD/USD/both/calendar date.
- [ ] Which cyclic jobs are Control-M re-launched vs internal loops.
- [ ] Existing Python Sybase connector, shared venv, and how a Python entry point is deployed to the batch VM (uv, Ansible, GitHub Actions per team conventions).
- [ ] Sybase ASE conventions in the repo: identity columns, datetime type, varchar sizes, naming, schema/owner for new tables in the main DB.
- [ ] Whether prod support runs scripts manually in prod today and how (for the runbook change).
- [ ] Control-M Automation API access from the VM with team credentials; token handling.

## Open items / next steps

- [ ] Produce ADRs in `docs/adr/` for D1-D13 (one per decision or grouped sensibly). Externalise; do not re-derive next session.
- [ ] Sybase DDL for the 9 tables plus views `v_job_run_latest`, `v_run_reconciliation`.
- [ ] Implementation plan: release A = wrapper + `job`/`job_run` on one folder; release B = `jobstat` + file/metric/delivery on 1-2 pilot file-load jobs; release C = export script + `job_dependency` + reconciler; then folder-by-folder rollout.
- [ ] Runbook update for manual runs via wrapper.
- [ ] Java REST endpoints against the views; DevExtreme grid columns for the reconciliation view.

## Key references

- `run_controlM.sh` (ksh wrapper) in the repo; PATH-prefixed, `rbc_logger` function.
- `$MSD/config/logmessage_map.properties`: ERROR/FATAL pattern source.
- Existing GUI app repo (Java REST + DevExtreme) for report hosting.
- Prior design decisions for the 2027 framework (May 2026 grill session): `job_runs` in main Sybase DB, two-layer config (YAML + DB), Vault AppRole, structlog, `get_bus_day` as sole business-date source. This handoff supersedes the "start/end/status only" scope from that session.

## Environment & dependencies

- RHEL9 batch VM, Control-M agent, Sybase ASE, shared Python venv, existing Python Sybase connector (name/version: verify).
- Java REST backend + DevExtreme grid GUI app (existing).
- Control-M Automation API reachable with team credentials `[REDACTED]`.
- Team conventions: `AGENTS.md` as governance artifact, `docs/adr/`, plan mode first, Sonnet default, Opus for judgment tasks, PreToolUse guard hooks in `.claude/settings.json`.

## Suggested skills

- **grill-me**: after the code review, re-grill only the decisions the code contradicted. Do not re-run the whole tree.
- **handoff**: at the end of the work-env session, write a fresh handoff into `docs/handoff/` so the next session (or Abid) starts from a reviewed artifact, not a compact summary.

## Risks / watch-outs

- The ksh wrapper's `EXITCODE` set inside a pipeline works only because ksh runs the last pipeline stage in the current shell; a bash port silently breaks it.
- `FINISHED` timestamp reuses the last output line's `DATE1`, so today's end times are wrong for scripts that go quiet before exiting. Do not treat historical log timestamps as ground truth when baselining.
- Log file keyed by script name: two Control-M jobs on the same script share one log and can interleave. The new wrapper must keep this behaviour byte-compatible in release A and only fix it later, or prod support tooling breaks.
- Any `jobstat` output containing "ERROR" will flip the job to FAILED through the pattern-matcher. Enforce the `JOBSTAT-WARN:` prefix in tests.
- Wrapper bugs fail every job. Ship `--bypass`, roll out per folder, keep `run_controlM.sh` deployable.
- Do not create the health tables early; the temptation to show RED/GREEN before data exists produces bad thresholds that then get trusted.

---

## First prompt for the work-env session (paste into Claude Code, Opus, plan mode)

```
Read docs/handoff/2026-09-13-batch-observability.md in full. Treat every decision D1-D13 and the
proposed schema as hypotheses, not facts. Work through the "Assumptions to verify" checklist by
reading the actual code: run_controlM.sh, logmessage_map.properties, three representative job
scripts (one file-load with BCP, one report/outbound, one cyclic), the Python Sybase connector,
the Control-M job export if available, and the existing Sybase DDL conventions.

For each assumption: CONFIRMED / CONTRADICTED / UNKNOWN, with the file and line that decides it.
For each contradicted assumption, propose the smallest change to the decision or schema and state
what else it affects. Then write an implementation plan for releases A, B, C as described, sized
for a team of four with one senior owner. Do not write code yet. Do not re-derive decisions the
code confirms.
```
