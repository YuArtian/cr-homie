# Changelog

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
