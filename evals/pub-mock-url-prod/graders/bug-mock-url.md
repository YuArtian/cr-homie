---
type: llm
focus: { source: file, path: review.json }
---

The file is a code review report in JSON. Look only at the `findings` array. (labeled severity P1)

PASS if `findings` contains an entry for `src/pages/Billing.jsx` with `line` between 3 and 15 that reports the hard-coded `http://localhost:4000/mock/...` billing URL being used in production code (instead of the app's configured API client / `VITE_API_URL`), at severity `P0` or `P1`.

FAIL if there is no such entry, if it is `P2` or `P3`, or if the file is not valid JSON.
