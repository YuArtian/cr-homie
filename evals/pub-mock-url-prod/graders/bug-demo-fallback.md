---
type: llm
focus: { source: file, path: review.json }
---

The file is a code review report in JSON. Look only at the `findings` array. (labeled severity P2)

In `src/pages/Billing.jsx`, when the fetch fails the page calls `setInvoices(DEMO_INVOICES)` and shows hard-coded demo invoices as if they were the user's real invoices.

PASS if some entry in `findings` for `src/pages/Billing.jsx` identifies this problem: fake / demo invoice data shown to real users on failure, or errors silently replaced by fake data. It may be its own entry or be explicitly covered in the risk / fix text of the mock-URL entry. Severity must be `P0`, `P1` or `P2`.

FAIL if no finding mentions the demo-data fallback, or if the file is not valid JSON.
