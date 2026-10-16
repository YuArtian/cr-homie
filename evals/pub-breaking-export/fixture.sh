#!/usr/bin/env bash
# Published TypeScript library @acme/date-utils (used by other repos). `feature`:
#   - renames the exported `formatDate` to `format` with no alias, ships as a minor (real bug: breaking change)
#   - adds an optional `opts` parameter to `parseDate` (trap: backward compatible)
set -euo pipefail

git init -q -b main
git config user.email eval@example.com
git config user.name eval
mkdir -p src

cat > package.json <<'EOF'
{
  "name": "@acme/date-utils",
  "version": "2.3.0",
  "description": "Date helpers shared by the web, admin and mobile-web apps.",
  "type": "module",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "exports": { ".": "./dist/index.js" },
  "files": ["dist"],
  "scripts": { "build": "tsc -p .", "test": "vitest" },
  "devDependencies": { "typescript": "^5.6.0", "vitest": "^3.0.0" }
}
EOF

cat > tsconfig.json <<'EOF'
{
  "compilerOptions": { "target": "ES2022", "module": "ES2022", "declaration": true, "outDir": "dist", "strict": true },
  "include": ["src"]
}
EOF

cat > src/index.ts <<'EOF'
export type DateFormat = "iso" | "short" | "long";

/** Format a Date for display. */
export function formatDate(date: Date, fmt: DateFormat = "short"): string {
  if (fmt === "iso") return date.toISOString();
  const opts: Intl.DateTimeFormatOptions =
    fmt === "long" ? { dateStyle: "long" } : { dateStyle: "short" };
  return new Intl.DateTimeFormat("en-US", opts).format(date);
}

/** Parse an ISO-8601 string. Throws on invalid input. */
export function parseDate(input: string): Date {
  const d = new Date(input);
  if (Number.isNaN(d.getTime())) throw new RangeError(`Invalid date: ${input}`);
  return d;
}
EOF

cat > CHANGELOG.md <<'EOF'
# Changelog

## 2.3.0
- Add `long` format to `formatDate`.
EOF

git add -A
git commit -qm "v2.3.0"

git checkout -qb feature

cat > src/index.ts <<'EOF'
export type DateFormat = "iso" | "short" | "long";

export interface ParseOptions {
  /** Treat date-only strings (YYYY-MM-DD) as local time instead of UTC. */
  localDateOnly?: boolean;
}

/** Format a Date for display. */
export function format(date: Date, fmt: DateFormat = "short"): string {
  if (fmt === "iso") return date.toISOString();
  const opts: Intl.DateTimeFormatOptions =
    fmt === "long" ? { dateStyle: "long" } : { dateStyle: "short" };
  return new Intl.DateTimeFormat("en-US", opts).format(date);
}

/** Parse an ISO-8601 string. Throws on invalid input. */
export function parseDate(input: string, opts: ParseOptions = {}): Date {
  const dateOnly = /^\d{4}-\d{2}-\d{2}$/.test(input);
  const d = opts.localDateOnly && dateOnly ? new Date(`${input}T00:00:00`) : new Date(input);
  if (Number.isNaN(d.getTime())) throw new RangeError(`Invalid date: ${input}`);
  return d;
}
EOF

cat > package.json <<'EOF'
{
  "name": "@acme/date-utils",
  "version": "2.4.0",
  "description": "Date helpers shared by the web, admin and mobile-web apps.",
  "type": "module",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "exports": { ".": "./dist/index.js" },
  "files": ["dist"],
  "scripts": { "build": "tsc -p .", "test": "vitest" },
  "devDependencies": { "typescript": "^5.6.0", "vitest": "^3.0.0" }
}
EOF

cat > CHANGELOG.md <<'EOF'
# Changelog

## 2.4.0
- Rename `formatDate` to `format` for brevity.
- `parseDate` accepts an optional `ParseOptions` (`localDateOnly`).

## 2.3.0
- Add `long` format to `formatDate`.
EOF

git add -A
git commit -qm "v2.4.0: shorter format name, local date-only parsing"
