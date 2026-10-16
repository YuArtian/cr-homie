---
description: Published TS library; the feature branch renames the exported formatDate to format with no alias and ships it as a minor (breaking, real bug), and adds an optional parameter to parseDate (non-breaking, trap).
tags: [public, api-contract, trap]
max_turns: 200
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Skill, Agent, TodoWrite]
---
/cr-homie:cr-homie branch:feature --format json --out review.json
