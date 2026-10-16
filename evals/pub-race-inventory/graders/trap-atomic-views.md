---
type: llm
focus: { source: file, path: review.json }
---

The file is a code review report in JSON. In `app/stock.py`, `record_view` runs a single `UPDATE stock SET views = views + 1 WHERE sku = :sku`. A single UPDATE that increments in place is atomic in Postgres, so there is no race in it.

PASS if the `findings` array has NO entry claiming a race condition / lost update in `record_view` or the views counter at severity `P0`, `P1` or `P2`. Entries that appear only in `refuted` are fine.

FAIL if `findings` reports a race in the views increment at `P0`–`P2`, or if the file is not valid JSON.
