# CONTEXT.md — Batch Framework Domain Glossary

This file is the authoritative domain vocabulary for this project.
All code, tests, ADRs, and AI-generated content must use these terms exactly.
Update this file whenever a new concept is introduced. PR requires update if a new module is named after a concept not listed here.

---

## Core Concepts

**Batch Job**
A scheduled unit of work that runs unattended, typically on a business date cadence. Invoked by Control-M. Returns exit code 0 (success) or 1 (failure).

**Job Handler**
A thin Python class containing only the business logic for one batch job. Implements `execute(ctx: JobContext) → JobResult`. Never contains logging setup, retry logic, transport logic, or metadata writes — the framework handles those.

**JobContext**
The assembled runtime context injected into every job handler. Contains: resolved business date, lazy DB connections, structured logger, merged config, and secrets client. Jobs read from context; they never construct it.

**JobResult**
The return value of `execute()`. Carries: status (success/failure), stats (rows loaded, records processed), and optional message. Framework uses this to write operational metadata.

**Job Inventory**
The complete registry of all batch jobs known to the framework. Each entry maps a `BATCH_JOB_NAME` to its structural YAML config and operational DB config.

**Structural Config**
The Git-controlled YAML definition of a job. Contains: job type, handler class, business date rules, transport method, stored procedure name. Changes require PR and change management. Lives in `config/jobs/{job_name}.yaml`.

**Operational Config**
The DB-table-controlled tunable values for a job. Contains: email distribution list, SFTP destination path, filename pattern, account list pointer. IT support can update same-day via service ticket. Never in Git.

**Config Stack**
The merge order at runtime: `env YAML → structural YAML → operational DB config → Vault secrets = JobContext`. Each layer overrides the previous for overlapping keys.

**Business Date**
The authoritative date a job uses for data selection and file naming. Resolved by the framework at startup by calling `get_bus_day(currency, offset)` in Sybase. Jobs never compute their own business date.

**Business Date Override**
A `--business-date DATE` flag passed from Control-M that bypasses `get_bus_day` and injects the specified date directly. Used for reruns and recovery scenarios.

**get_bus_day**
The existing Sybase database function that resolves a business date given a currency (CAD or USD) and day offset. Single source of truth for all holiday calendar logic. The framework wraps this; it is never reimplemented in Python.

**Job Run**
A single execution instance of a batch job. Recorded in the `job_runs` table with: `job_name`, `start_time`, `end_time`, `status`.

**Operational Metadata**
Runtime statistics written by the framework to the `job_runs` table on job completion. Job handlers never write operational metadata directly.

**File Stats**
For inbound file load jobs: the metadata captured about a processed file — filename, file timestamp, file owner, filesize, header value, trailer value, data row count, and records loaded to Sybase.

**Secrets Manifest**
The Git-committed file at `config/secrets_manifest.yaml` that lists every Vault path and key name the framework accesses. Values are never stored — only paths and key names. Authoritative reference for IT support when rotating or adding secrets in Vault.

**Job Type**
The category of a batch job that determines which base handler subclass it uses. Defined in structural YAML. Current types: `file_load`, `report`, `cyclic`. New types added incrementally as R2/R3 surface the need.

---

## Handler Types

**FileLoadJobHandler**
Base handler for inbound file processing jobs. Framework provides: inbound file path, file stats capture, archival. Handler provides: parse logic, Sybase load logic.

**ReportJobHandler**
Base handler for report generation and delivery jobs. Framework provides: query execution, SFTP/email delivery, delivery confirmation. Handler provides: data selection query, formatting logic.

**CyclicJobHandler**
Base handler for intraday polling jobs. Framework provides: polling interval, early exit signalling. Handler provides: condition check logic.

---

## Infrastructure Terms

**Control-M**
The mandated enterprise scheduler. Owns all job scheduling, dependencies, file watchers, and calendar logic. The framework does not reimplement any scheduler behaviour.

**BATCH_JOB_NAME**
The unique identifier for a job, passed as the first argument to `run_job.sh` and used to look up all config. Consistent across Control-M, the framework, the job inventory, and the repo.

**Shared Venv**
The single Python virtual environment on the dev VM shared by all batch jobs. Managed by `uv sync --frozen` on deploy. Never modified at runtime.

**Dev VM**
The shared Linux (RHEL9) development and runtime server. Hosts the shared venv, Sybase ASE, and the OCS client required by sybpydb. Developers connect via VS Code Remote SSH.

**AppRole**
The Vault authentication method used by the framework. A `role_id` (non-secret, in Git) and `secret_id` (secret, on VM) are exchanged for a short-lived token at job startup. Replaced by K8s auth in Phase 2.

---

## Calendar Terms

**CAD Business Day**
A weekday that is not a Canadian bank holiday. Resolved via `get_bus_day('CAD', offset)`.

**USD Business Day**
A weekday that is not a US bank holiday. Resolved via `get_bus_day('USD', offset)`.

**T+0 / T-1 / T+1**
Business day offsets relative to today. T+0 CAD returns today if it's a CAD business day, otherwise the next CAD business day.

---

## What AI Tools Must Never Do

- Compute business dates directly in Python — always call `get_bus_day` via the framework
- Put secrets, passwords, or private keys in YAML, code, or environment variables
- Add logging setup inside job handlers — the framework handles this
- Write to `job_runs` inside job handlers — the framework handles this
- Add scheduling logic — Control-M owns this
- Create per-job venvs
- Add Windows-specific code paths
- Add Dockerfile or Kubernetes manifests (Phase 2 only)
