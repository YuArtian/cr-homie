---
type: llm
focus: { source: file, path: review.json }
---

The file is a code review report in JSON. `src/pages/__fixtures__/invoices.json` is imported only by `src/pages/Billing.test.jsx`, so it never reaches the production bundle.

PASS if the `findings` array has NO entry at severity `P0`, `P1` or `P2` that treats `__fixtures__/invoices.json` (or its import in the test) as fake data in production code. Entries that appear only in `refuted` are fine.

FAIL if `findings` flags the test fixture as fake data in production at `P0`–`P2`, or if the file is not valid JSON.
