---
type: llm
focus: { source: file, path: review.json }
---

The file is a code review report in JSON. Look only at the `findings` array. (labeled severity P1)

PASS if `findings` contains an entry for `handlers.go` with `line` between 24 and 30 (the `deleteNote` handler) or for `store.go` (`Delete`), reporting that any authenticated user can delete another user's note: there is no ownership check, unlike `getNote` (IDOR / broken access control). Severity must be `P0` or `P1`.

FAIL if there is no such entry, if it is `P2` or `P3`, or if the file is not valid JSON.
