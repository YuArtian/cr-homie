---
type: llm
focus: { source: file, path: review.json }
---

The file is a code review report in JSON. Look only at the `findings` array.

PASS if `findings` contains an entry whose `file` is `src/routes/users.js`, whose `line` is between 7 and 13, whose title or risk describes SQL injection (user input from the `name` query parameter interpolated into the SQL string), and whose `severity` is `P0` or `P1`.

FAIL if there is no such entry, if it has severity `P2` or `P3`, or if the file is not valid JSON.
