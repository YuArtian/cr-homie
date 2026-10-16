---
type: llm
focus: { source: file, path: review.json }
---

The file is a code review report in JSON. Look only at the `findings` array. (labeled severity P1)

PASS if `findings` contains an entry for `app/stock.py` with `line` between 4 and 15 (the `reserve_stock` function) whose title or risk describes a race condition / lost update / oversell: the available stock is read with a plain SELECT and written back with a computed value, so two concurrent orders can both pass the check. Severity must be `P0` or `P1`.

FAIL if there is no such entry, if it is `P2` or `P3`, or if the file is not valid JSON.
