---
description: React app; the feature branch adds a Billing page that fetches from a hard-coded localhost mock URL and falls back to demo invoices on error (real bugs), with a test-only fixture JSON (trap).
tags: [public, frontend, production-readiness, trap]
max_turns: 200
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Skill, Agent, TodoWrite]
---
/cr-homie:cr-homie branch:feature --format json --out review.json
