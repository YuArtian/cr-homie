# Testing Quality Checklist

## Coverage Assessment

### Changed Code Coverage
- Are new functions/methods covered by at least one test?
- Are new branches (if/else, switch cases) covered?
- Are error paths tested (not just happy path)?
- If fixing a bug — is there a regression test that would have caught it?

### Critical Path Coverage
- Auth/authz changes have corresponding permission tests
- Data mutation paths have before/after state assertions
- Payment/financial logic has precision and edge case tests
- API endpoints have request validation and response shape tests

### Questions to Ask
- "If I break this code, which test fails?"
- "Does this test verify the bug is fixed, or just that the code runs?"

---

## Test Quality

### Behavior vs Implementation
- **Good**: Tests verify observable behavior and outputs
- **Bad**: Tests assert on internal state, private methods, or call counts
- **Red flag**: Test breaks when refactoring without changing behavior

### Assertion Quality
- Assertions are specific (not just "no error thrown")
- Error cases assert on error type/message, not just "throws"
- Async operations properly awaited before assertions
- Snapshot tests are intentional, not lazy (review snapshot content)

### Test Isolation
- Tests don't depend on execution order
- Tests don't share mutable state
- Each test sets up its own preconditions
- Database tests use transactions or clean up after themselves

### Questions to Ask
- "Does this test break if I refactor the implementation but keep the same behavior?"
- "Can I understand the expected behavior just by reading this test?"

---

## Test Anti-Patterns

### Over-Mocking
- Mocking the thing being tested (test proves nothing)
- Mocking so much that the test only verifies mock wiring
- Mocking standard library or language primitives
- **Guideline**: If > 50% of the test is mock setup, reconsider the approach

### Flaky Tests
- Tests that depend on timing (`setTimeout`, `sleep`)
- Tests that depend on external services without stubs
- Tests that depend on specific system state (time, locale, env)
- Non-deterministic assertions (random data, unordered collections)

### Weak Tests
- Tests that only verify "no exception thrown"
- Tests with no assertions (`expect` / `assert`)
- Tests that duplicate production logic in assertions
- Boolean trap: `expect(result).toBe(true)` — what is `result`?

### Test Naming
- Name describes the scenario, not the implementation
- **Good**: `should reject expired tokens`, `returns empty list when no matches`
- **Bad**: `test1`, `testMethod`, `it works`

---

## Language-Specific Testing Flags

### JavaScript/TypeScript
- Missing `await` in async test (test passes vacuously)
- `jest.mock` at module level leaking across tests
- Timer-dependent tests without `jest.useFakeTimers`
- React component tests asserting on DOM structure instead of behavior

### Go
- Table-driven tests without clear subtest names
- `t.Fatal` / `t.Error` confusion (Fatal stops, Error continues)
- Missing `t.Helper()` in test helper functions
- Testing unexported functions when exported API is sufficient

### Python
- `unittest.mock.patch` on wrong import path
- Missing `pytest.raises` context manager for exception tests
- Fixtures with broad scope (`session`) causing state leakage
- `assert` statements that are always true due to operator precedence

### Java
- `@MockBean` overuse in Spring tests (slow context reload)
- Missing `@Transactional` in integration tests (dirty database)
- PowerMock usage (sign of untestable design)
- `assertEquals` argument order confusion (expected, actual)
