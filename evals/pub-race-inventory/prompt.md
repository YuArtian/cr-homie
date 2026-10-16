---
description: FastAPI + SQLAlchemy on Postgres; the feature branch reserves stock with a read-then-write (oversell race, real bug) and counts views with an atomic `views = views + 1` (trap).
tags: [public, quality, concurrency, trap]
max_turns: 200
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Skill, Agent, TodoWrite]
---
/cr-homie:cr-homie branch:feature --format json --out review.json
