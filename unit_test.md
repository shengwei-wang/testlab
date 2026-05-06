You are working in agent mode on a <REPO_TYPE> repository that currently has zero unit tests. Goal: achieve 80%+ line coverage uploaded to SonarQube. You will run in a loop: analyze, generate, execute, measure, fix, repeat — until coverage ≥ 80% on production code that has business logic.

Read every section below before taking any action. The QUALITY GUARDRAILS are non-negotiable and override the coverage target.

## QUALITY GUARDRAILS — these override everything else

1. **Never modify production code to make a test pass.** The only exception is extracting a seam for testability (clock, random, system env). If you do this, stop and tell me before continuing.
2. **Every test must assert behavior** — a return value, a state change, an exception type, or an observable side effect. Tests that only assert that a mock was called (`verify(mock).method()` / `mock.assert_called()`) without also asserting an outcome are forbidden.
3. **Mock only external boundaries** — database, HTTP clients, message brokers, file system, clock, randomness, environment. Never mock the class under test. Never mock simple value objects, DTOs, or pure functions.
4. **If a generated test fails, diagnose first.** Three options: (a) the test is wrong → fix the test, (b) the production code has a bug → stop and report it to me, do not patch the test to hide it, (c) the code is untestable as written → stop and report.
5. **Never delete, disable, `@Ignore`, `@Disabled`, `skip`, or `xfail` a test to make the build green.** If a test must be skipped, stop and ask.
6. **No tautological tests.** Do not assert `x == x`, do not re-implement the production logic inside the test, do not assert on the literal output of a mock you just configured with that exact value.
7. **Deterministic and isolated.** No real network. No real DB. No `Thread.sleep` / `time.sleep`. No real `Instant.now()` / `datetime.now()` — inject a clock if needed. Tests must pass in any order, run in parallel safely.
8. **Coverage is a floor, not the goal.** If hitting 80% requires testing trivial code (getters/setters, DTOs, config classes, generated code, `main` entry points), exclude that code from coverage measurement instead of writing meaningless tests.

## STEP 1 — Discover and report (do not write tests yet)

Inspect the repo and produce a short report covering:
- Build system + version (Maven/Gradle, or Python packaging — pyproject.toml / setup.py / requirements.txt)
- Source layout, package/module structure
- Frameworks in use (Spring Boot, FastAPI, Flask, Kafka client, JMS, batch entry points)
- Existing test framework if any (JUnit 4/5, TestNG, pytest, unittest)
- Existing coverage tooling if any (jacoco-maven-plugin, pytest-cov, coverage.py)
- Existing mocking library if any (Mockito, unittest.mock, pytest-mock)
- A ranked inventory of production files by testable business logic (HIGH / MEDIUM / EXCLUDE)
  - HIGH: services, domain logic, calculations, transformations, validators, parsers
  - MEDIUM: controllers, message handlers, job entry points, non-trivial utilities
  - EXCLUDE: DTOs, getters/setters, generated code, `*Application.java` / `main()`, pure config classes, migrations

**Stop here and wait for me to confirm the inventory before generating tests.**

## STEP 2 — Configure coverage tooling (only if missing)

### Java / Maven
- Add `jacoco-maven-plugin` to `pom.xml`: `prepare-agent` bound to `initialize`, `report` bound to `verify`.
- Create or update `sonar-project.properties` at repo root:
  - `sonar.projectKey`, `sonar.projectName`
  - `sonar.sources=src/main/java`
  - `sonar.tests=src/test/java`
  - `sonar.java.binaries=target/classes`
  - `sonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml`
  - `sonar.coverage.exclusions` for excluded categories from Step 1
- Verify: `mvn clean verify` → confirm `target/site/jacoco/index.html` exists.

### Python
- Add `pytest`, `pytest-cov` to dev dependencies if missing.
- Configure `[tool.coverage.run]` in `pyproject.toml` (or `.coveragerc`):
  - `source = ["<package>"]`
  - `branch = true`
  - `omit` for excluded categories from Step 1
- Update `sonar-project.properties`:
  - `sonar.python.coverage.reportPaths=coverage.xml`
  - `sonar.sources=<package>`
  - `sonar.tests=tests`
- Verify: `pytest --cov=<package> --cov-branch --cov-report=xml --cov-report=term-missing`

## STEP 3 — Naming and folder conventions (strict)

### Java
- Path: `src/test/java/<same.package.path>/`
- Class: `<ClassName>Test.java` — one test class per production class
- Method: `should_<expected>_when_<condition>` OR `methodName_condition_expectedResult`
- Tests never go under `src/main`.

### Python
- Path: `tests/` at repo root, mirroring package structure
- File: `tests/<subpackage>/test_<module>.py`
- Function: `test_<unit>_<condition>_<expected>`
- Tests never go inside the production package directory.

## STEP 4 — Generate, run, measure, fix (the loop)

For each HIGH-priority file, then MEDIUM:

1. **Plan first** — list the test cases you intend to write (name + one-line intent). Each public method must cover: happy path + at least one edge case + at least one error/exception path.
2. **Write the test file.** Use Arrange-Act-Assert (or Given-When-Then). One logical concept per test.
3. **Run the suite** — `mvn test` or `pytest --cov=<package> --cov-branch --cov-report=xml --cov-report=term-missing`.
4. **Read the output.** If a test fails, apply guardrail #4. If it passes, read the coverage report.
5. **Identify uncovered branches** in the file you just worked on. Add targeted tests for them — but only if the uncovered code has business logic. If it's trivial, add it to the coverage exclusion list with a one-line justification.
6. **Move to the next file** when the current file is at 80%+ OR all remaining uncovered lines are justifiably excluded.

Repeat until total coverage ≥ 80% on non-excluded code.

### Framework-specific guidance
- Spring Boot: prefer `@WebMvcTest`, `@DataJpaTest`, plain unit tests. Avoid full `@SpringBootTest` unless integration coverage is genuinely needed.
- FastAPI / Flask: use the test client for handlers; mock the service layer below.
- Kafka / JMS consumers: test the handler function directly with a constructed message; do not start a broker.
- Batch jobs: test logic units in isolation; do not invoke the scheduler.

## STEP 5 — Final report

When the loop completes, produce:
- Total coverage % (line, branch)
- Per-file coverage for HIGH and MEDIUM files
- All exclusions added, with justification for each
- Any production code issues discovered (guardrail #4b)
- Any places you stopped and asked, with the resolution
- Command used to upload to Sonar (do not run the upload — I will run it)

## STOP AND ASK before:

- Adding any production dependency beyond test/coverage libraries
- Excluding a class that contains business logic
- Modifying production code (even for testability seams)
- Skipping or disabling any test
- Mocking anything that isn't a clear external boundary
- Hitting a third consecutive failed-test iteration on the same file — report it instead of guessing further

Begin with STEP 1.
