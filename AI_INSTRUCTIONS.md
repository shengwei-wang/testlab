# AI_INSTRUCTIONS.md — Batch Framework

This is the canonical AI instructions file for the Capital Markets Batch Job Framework.
All AI tool-specific files (CLAUDE.md, .github/copilot-instructions.md, .windsurfrules) reference this file.
Read this before generating any code, tests, config, or documentation for this project.

---

## What This Project Is

A declarative, reusable Python batch job framework for a Capital Markets team.
It replaces 250-300 bash/perl crontab jobs with structured, testable, AI-navigable Python.
Jobs are migrated to this framework incrementally — existing jobs run unchanged on Control-M until rewritten.

**The business logic lives in Sybase stored procedures. This framework is the glue layer.**

---

## Read These First

Before generating anything, read:
- `CONTEXT.md` — authoritative domain vocabulary. Use these terms exactly in all code, tests, and docs.
- `docs/adr/` — all architectural decisions. Do not re-litigate decisions recorded here.

---

## Project Structure

```
batch_framework/
  core/
    context.py          # JobContext dataclass
    runner.py           # framework entry point — called by run_job.sh
    config_loader.py    # merges env YAML + structural YAML + operational DB + Vault
    business_date.py    # wraps get_bus_day Sybase function
    logging.py          # structlog setup
    vault.py            # Vault AppRole auth + secrets fetch
    db.py               # lazy connection factory (sybase_main, sybase_ref, sybase_ops, oracle)
    metadata.py         # writes job_runs table — never called by job handlers
  handlers/
    base.py             # BaseJobHandler
    file_load.py        # FileLoadJobHandler
    report.py           # ReportJobHandler
    cyclic.py           # CyclicJobHandler
  jobs/
    fx_rate_load.py     # example: one file per job handler
    ...
config/
  env/
    dev.yaml
    uat.yaml
    prod.yaml
  jobs/
    fx_rate_load.yaml   # structural config per job
    ...
  secrets_manifest.yaml # Vault paths + key names only — never values
docs/
  adr/                  # architectural decision records
tests/
  unit/
  integration/
run_job.sh              # thin bash wrapper — activates venv, calls runner
pyproject.toml
uv.lock
CONTEXT.md
AI_INSTRUCTIONS.md
```

---

## The Handler Pattern

Every job handler looks like this. Nothing more, nothing less:

```python
from batch_framework.handlers.file_load import FileLoadJobHandler
from batch_framework.core.context import JobContext, JobResult

class FxRateLoadJob(FileLoadJobHandler):
    def execute(self, ctx: JobContext) -> JobResult:
        # ctx gives you everything — use it
        rows = parse_fx_file(ctx.inbound_file)
        ctx.sybase_main.execute_proc("sp_load_fx_rates", rows)
        return JobResult.success(rows_loaded=len(rows))
```

**Handler responsibility:** what to read, what to compute/transform, what to write to the DB.
**Framework responsibility:** logging, retry, metadata write, SFTP, email, secrets, date resolution.

### Picking the right base class

| Job does this | Use this base |
|---|---|
| Reads an inbound file, loads to Sybase | `FileLoadJobHandler` |
| Queries Sybase, formats, delivers via SFTP or email | `ReportJobHandler` |
| Polls for a condition on a schedule | `CyclicJobHandler` |
| None of the above | `BaseJobHandler` |

---

## Structural Config (YAML)

One file per job in `config/jobs/`. This is the Git-controlled definition of the job.

```yaml
# config/jobs/fx_rate_load.yaml
job_name: fx_rate_load
handler: batch_framework.jobs.fx_rate_load.FxRateLoadJob
job_type: file_load

business_date:
  primary:
    currency: CAD
    offset: 0
  also_need:
    - currency: USD
      offset: -1

transport:
  method: sftp
  # destination and credentials come from operational config + Vault
```

**Never put in structural YAML:** passwords, private keys, email addresses, SFTP paths (those go in operational DB config or Vault).

---

## Business Date Rules

**Never compute business dates in Python.** Always declare them in the job YAML and let the framework call `get_bus_day(currency, offset)` in Sybase at startup.

```python
# In a handler:
ctx.business_date          # primary resolved date
ctx.business_dates.usd_t1  # secondary resolved date (if declared in YAML)

# NEVER do this in a handler:
from datetime import date, timedelta
today = date.today()  # WRONG — doesn't handle holidays
```

---

## Secrets Rules

**Never put secrets anywhere except Vault.**

```python
# Correct — secrets injected via ctx at startup
password = ctx.secrets.get("sybase_main", "password")

# Wrong — never do any of these:
password = "hardcoded"
password = os.environ["DB_PASSWORD"]
password = config["password"]
```

To add a new secret: add its Vault path and key name to `config/secrets_manifest.yaml`, then add the actual secret to Vault. Never commit a value.

---

## Logging Rules

Use `ctx.logger` everywhere. Never configure a logger inside a handler.

```python
# Correct
ctx.logger.info("rows_loaded", count=len(rows), file=ctx.inbound_file.name)

# Wrong
import logging
logger = logging.getLogger(__name__)  # bypasses structured logging
```

The logger automatically attaches `job_name`, `business_date`, and `env` to every line.

---

## Database Rules

Use lazy properties on `ctx`. Only access what the job actually uses.

```python
ctx.sybase_main   # primary Sybase — most jobs use this
ctx.sybase_ref    # reference data Sybase
ctx.sybase_ops    # ops Sybase
ctx.oracle        # Oracle (other system)
```

Never open a raw database connection inside a handler. Never write to `job_runs` from a handler.

---

## Testing Rules

Tests verify behaviour through public interfaces, not implementation details.

```python
# Good — tests what the job does
def test_fx_rate_load_inserts_correct_row_count(fake_ctx, sample_fx_file):
    fake_ctx.inbound_file = sample_fx_file
    result = FxRateLoadJob().execute(fake_ctx)
    assert result.stats["rows_loaded"] == 10

# Bad — tests implementation
def test_parse_fx_file_called_once(mock_parse):
    ...  # mocking internals — don't do this
```

Write one test → implement → repeat (vertical slices). Never write all tests first.

---

## ADR Protocol

When making an architectural decision:
1. Create `docs/adr/ADR-NNNN-short-title.md`
2. Record: context, decision, consequences, alternatives rejected
3. PR cannot merge without the ADR if a new module is introduced or an existing decision is changed

---

## What AI Tools Must Never Do

- Compute business dates in Python — use `get_bus_day` via framework
- Put secrets in YAML, code, or env vars
- Add logging setup inside handlers
- Write to `job_runs` inside handlers
- Add scheduling logic — Control-M owns this
- Create per-job venvs
- Add Windows-specific code paths
- Add Dockerfile or Kubernetes manifests (Phase 2)
- Use `uv run` at job runtime — call venv Python directly
- Re-litigate decisions in `docs/adr/`
