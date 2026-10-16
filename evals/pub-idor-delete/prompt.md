---
description: Go notes service; the feature branch adds DELETE /notes/{id} without the ownership check that GET has (IDOR, real bug) and an admin purge handler that is protected by requireAdmin at mount time (trap).
tags: [public, security, authz, go, trap]
max_turns: 200
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Skill, Agent, TodoWrite]
---
/cr-homie:cr-homie branch:feature --format json --out review.json
