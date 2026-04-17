# Changelog

## v2.0.0 — 2026-04-17

**主题：多 Agent 并行架构 — 从串行单 Agent 到并行多 Agent 流水线**

### 架构变更

- **三阶段流水线**：将原有 12 步串行流程重构为 Phase 1（预检）→ Phase 2（并行 Agent）→ Phase 3（聚合）
- **8 个专项审查 Agent**：security-reviewer、testing-reviewer、solid-reviewer、quality-reviewer、frontend-reviewer、api-reviewer、removal-reviewer、page-verifier，各自独立运行、独立加载 checklist
- **Confidence Scorer**：新增 haiku 打分 Agent，对每条发现评分 0-100，过滤低置信度误报（<70 丢弃，70-79 标注 `[low confidence]`）

### 新增

- **多 Agent 共识机制**：2+ Agent 独立标记同一 `file:line` 时，最高 severity 自动提升一级（P2→P1），标注 `[Multi-agent consensus]`
- **Agent 来源标签**：每条 finding 附带 `[security]`/`[quality]`/`[solid]` 等来源标签，提升可追溯性
- **Preflight Context Block**：预检阶段汇总结构化上下文（scope、文件列表、语言、检测信号、diff 内容），统一传递给所有 Agent
- **Agent 启动决策矩阵**：基于 --focus、--quick、预检检测信号自动决定启动哪些 Agent
- **安全阀**：security-reviewer 的 P0 发现不可被 confidence scoring 丢弃，最多标注 `[needs verification]`

### 变更

- **模型分配策略**：security-reviewer 和 solid-reviewer 使用 opus（需要判断力），其余 Agent 使用 inherit（跟随用户当前模型），confidence-scorer 使用 haiku（轻量打分）
- **输出格式**：新增 `Agents launched` 字段、finding ID 前缀（SEC-/TEST-/SOLID-/QUAL-/FE-/API-/REM-/PAGE-）、来源标签
- **Resources 表格**：从"When to Load"改为"Used By"，标注每个 reference 被哪个 Agent 使用

### 新增文件

- `agents/security-reviewer.md` — 安全 + 可靠性 Agent
- `agents/testing-reviewer.md` — 测试质量 Agent
- `agents/solid-reviewer.md` — SOLID + 架构 Agent
- `agents/quality-reviewer.md` — 代码质量 Agent
- `agents/frontend-reviewer.md` — 前端质量 Agent
- `agents/api-reviewer.md` — API 契约 Agent
- `agents/removal-reviewer.md` — 移除计划 Agent
- `agents/page-verifier.md` — 页面验证 Agent
- `agents/confidence-scorer.md` — 置信度打分 Agent

### 修改文件

- `SKILL.md` — 从 12 步串行改为 3 阶段并行编排
- `README.md` — 更新架构图、工作流、项目结构、Agent 列表
- `README.zh-CN.md` — 同步更新中文文档

---

## v1.1.0 — 2026-04-16

**主题：CR 质量升级 — 从模式匹配到验证后报告**

起因：CR-Homie 审查 holyeval 项目时，将一个代码层面的路径遍历缺陷报告为"外部攻击者可通过 Web API 读取 .env"（P1）。实际验证发现 FastAPI 路由层已拦截攻击输入，外部不可利用。根因是 CR 只做了代码模式匹配，未验证攻击链是否可达。

### 新增

- **智能默认探测链**：`/cr-homie` 无参数时自动按优先级探测 unstaged → staged → branch diff，不再固定只跑 `git diff`
- **Finding 验证通用规则**（Universal Rule）：所有 finding 报告前必须用 grep/read 验证上下文（调用方、路由定义、配置等），未经验证的 finding 不允许出现在报告中
- **安全 checklist 攻击链验证**：Input/Output Safety 每个条目增加 Verify 指引，顶部新增攻击链验证流程（入口 → 框架层 → 漏洞代码）
- **报告模版 Attack Path + Confidence**：安全类 finding 必须附带攻击路径追溯和置信度标注（`Confirmed exploitable` / `Defense-in-depth gap` / `Needs verification`）
- **Checklist 后开放性审查**：Security、Code Quality、Testing 三个必选步骤末尾增加 "checklist 未覆盖的风险" 开放性提问，释放 LLM 推理能力发现未知问题

### 变更

- **大输入量两轮扫描**：触发阈值从 500 行调整为 2000 行或 15 个文件；超出阈值时采用两轮策略（Pass 1 快扫标记热点 → Pass 2 聚焦深度 review）。同时适用于大 diff 和 project 全量扫描

### 修改文件

- `SKILL.md` — Preflight 智能探测、Universal Rule、两轮扫描、输出模版、开放性审查
- `references/security-checklist.md` — 攻击链验证流程 + 条目级 Verify 指引
