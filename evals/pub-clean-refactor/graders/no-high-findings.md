---
type: llm
focus: { source: file, path: review.json }
---

The file is a code review report in JSON for a behavior-preserving refactor: two inline `email.strip().lower()` calls were replaced by a shared `normalize_email()` helper with the same behavior, plus tests.

PASS if the `findings` array contains NO entry with `severity` `P0` or `P1`. `P2` / `P3` entries, and anything in `refuted`, are fine.

FAIL if `findings` has any `P0` or `P1` entry, or if the file is not valid JSON.
