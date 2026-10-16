---
type: llm
focus: { source: file, path: review.json }
---

The file is a code review report in JSON. Look only at the `findings` array. (labeled severity P1)

The library `@acme/date-utils` is published and consumed by other apps. The change removes the exported `formatDate` (renamed to `format`) without keeping an alias or deprecation, and releases it as a minor version (2.3.0 → 2.4.0).

PASS if `findings` contains an entry that reports this as a breaking API change: the removed / renamed `formatDate` export breaks existing consumers, and/or a minor version bump for a breaking change. The entry may cite `src/index.ts`, `package.json` or `CHANGELOG.md`. Severity must be `P0` or `P1`.

FAIL if there is no such entry, if it is `P2` or `P3`, or if the file is not valid JSON.
