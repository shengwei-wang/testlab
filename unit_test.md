You are in agent mode on a <java-maven | python> repo with zero or partial unit tests.
Goal: achieve 80%+ line coverage on all production code that contains business logic.
Work in this loop: analyze → generate → run → read coverage → fix or add → repeat.

Read every section before taking any action.

## STEP 1 — Inventory (do this first, then STOP)

Scan the repo. Produce a ranked file inventory:
- HIGH: services, domain logic, calculations, transformations, validators, parsers
- MEDIUM: controllers, handlers, consumers, job entry points, non-trivial utilities
- EXCLUDE: DTOs, getters/setters, config classes, generated code, migration files, main entry points

Also report: build system, existing test framework, existing coverage tooling, existing mocking library.

**After producing the inventory, stop. Do not write any code. Wait for my explicit confirmation to proceed.**

## STEP 2 — Audit existing tests (if any exist)

Scan src/test (Java) or tests/ (Python) for existing test files. For each one:
1. Check it against every guardrail below. Flag violations.
2. Refactor violations in place — rewrite to assert real behavior. Do not delete tests.
3. Run the suite after refactoring. Confirm it passes.
4. Report what you found and changed before generating anything new.

If a file already has 80%+ coverage, skip it.

## STEP 3 — Configure coverage tooling (only if missing)

### Java / Maven
- Add jacoco-maven-plugin to pom.xml: prepare-agent bound to initialize, report bound to verify.
- Create or update sonar-project.properties:
  - sonar.sources=src/main/java
  - sonar.tests=src/test/java
  - sonar.java.binaries=target/classes
  - sonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
  - sonar.coverage.exclusions — add EXCLUDE categories from Step 1
- Verify with: mvn clean verify
- Confirm target/site/jacoco/index.html exists before continuing.

### Python
- Add pytest and pytest-cov to dev dependencies if missing.
- Configure coverage in pyproject.toml or .coveragerc: source, branch=true, omit EXCLUDE categories.
- Update sonar-project.properties:
  - sonar.python.coverage.reportPaths=coverage.xml
  - sonar.sources=<package>
  - sonar.tests=tests
- Verify with: pytest --cov=<package> --cov-branch --cov-report=xml --cov-report=term-missing
- Confirm coverage.xml exists before continuing.

## STEP 4 — Generate, run, measure, fix (the loop)

Work through HIGH files first, then MEDIUM. For each file:
1. Plan — list test cases (name + one-line intent) before writing any code.
2. Write the test file following the naming rules below.
3. Run the suite. Read the full output.
4. Read the coverage report. Identify uncovered branches in this file.
5. Add tests for uncovered logic. If the uncovered code is trivial, add it to the exclusion list with a one-line justification instead.
6. Move to the next file when this file is ≥80% or all remaining uncovered lines are justifiably excluded.

### Naming rules (strict)
Java:
- Path: src/test/java/<same.package.path>/
- Class: <ClassName>Test.java
- Method: should_<expected>_when_<condition>

Python:
- Path: tests/<subpackage>/test_<module>.py
- Function: test_<unit>_<condition>_<expected>

### Test structure
- Arrange-Act-Assert. One logical concept per test.
- Each public method must have: happy path + at least one edge case + at least one error/exception path.

### Framework guidance
- Spring Boot: use @WebMvcTest, @DataJpaTest, or plain unit tests. Avoid full @SpringBootTest.
- FastAPI / Flask: use the test client for handlers. Mock the service layer.
- Kafka / JMS: test the handler function directly. Do not start a broker.
- Batch jobs: test logic units in isolation. Do not invoke the scheduler.

## GUARDRAILS — non-negotiable, override everything including the coverage target

1. Assert behavior — return values, state changes, exception types, observable side effects.
   Asserting only that a mock was called is forbidden.
2. Mock only external boundaries: database, HTTP clients, message brokers, filesystem, clock, randomness.
   Never mock the class under test. Never mock DTOs or pure functions.
3. Never modify production code to make a test pass.
   Only allowed exception: extracting a clock or randomness seam for testability. Stop and tell me before doing this.
4. If a test fails: fix the test, or report a production bug. Never disable, skip, @Ignore, @Disabled, xfail, or weaken a test.
5. Never write tautological tests — do not assert x==x, do not re-implement production logic in the test, do not assert the exact value you configured on a mock.
6. Tests must be deterministic and isolated. No real network, no real DB, no Thread.sleep or time.sleep, no real clock. Tests must pass in any order.
7. If 80% requires testing trivial code, exclude that code from coverage config. Do not write meaningless tests to inflate the number.

## STOP AND ASK before doing any of the following:
- Modifying any production code
- Excluding a class or module that contains business logic
- Mocking anything that is not a clear external boundary
- Failing a third consecutive time on the same test file — report it instead of guessing further
- Disabling or skipping any test for any reason

## STEP 5 — Final report

When the loop completes, produce:
- Total coverage % (line and branch)
- Per-file coverage for all HIGH and MEDIUM files
- All exclusions added, with one-line justification each
- Any production code issues discovered
- Command to run Sonar upload (print it, do not execute it — I will run it manually)

Begin with STEP 1. Stop after the inventory. Wait for my confirmation.
