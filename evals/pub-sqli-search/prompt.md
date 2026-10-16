---
description: Express app; the feature branch adds a user search route that interpolates req.query.name into SQL (real bug) and a report listing whose ORDER BY comes from an allowlist (safe, trap).
tags: [public, security, trap, smoke]
max_turns: 200
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Skill, Agent, TodoWrite]
---
/cr-homie:cr-homie branch:feature --format json --out review.json
