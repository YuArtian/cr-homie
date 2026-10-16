---
description: Clean case. The feature branch extracts duplicated email normalization into normalize_email() with identical behavior and adds tests. Nothing should be reported at P0/P1.
tags: [public, clean, false-positive]
max_turns: 200
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Skill, Agent, TodoWrite]
---
/cr-homie:cr-homie branch:feature --format json --out review.json
