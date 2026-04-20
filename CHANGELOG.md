# Changelog

## v3.1.0 — 2026-04-20

> 主题：Preflight 强化 —— 分支感知探测、Project Scan 硬限制、Linter 检测、文档同步

### 行为变更（用户可见）

- **Smart Detection 不再是固定优先级链** — 改为分支感知：
  - 在 `main` / `master` / `trunk`：默认 unstaged，回退到 staged
  - 在其他分支：默认 branch-vs-main，回退到 unstaged/staged
  - 多个信号都有内容时展示摘要让用户覆盖（之前会静默选第一个）
- **Project Scan 硬限制** — 超过 1,000 文件或 150,000 行时，"Scan all" 选项被移除，强制用户选 "缩小范围 / hotspot-only / 取消"。防止 context window 溢出。300 文件 / 50,000 行为软警告。
- **HIGH SIGNAL linter-catchable 规则收紧** — 只有当项目实际配置了对应 linter（`.eslintrc*` / `tsconfig.json` / `ruff.toml` / `.golangci.yml` 等）时才 drop；无 linter 项目保留为 P3 而非丢弃。

### 新增

- **Preflight Step 11 — Linter 检测** — 探测 ESLint / tsc / Prettier / Ruff / mypy / Flake8 / Pylint / golangci-lint / Clippy 配置文件，结果写入 Preflight Context Block 的 `Linters configured` 字段。
- **Preflight Context Block 新字段** — `Scope mode: diff | project` 显式告知 agent 当前是 diff 审查还是 project 全扫描，`_base-reviewer.md` 的 anti-pattern 据此决定 "Add findings about unchanged code" 是否翻转。
- **Two-pass mode 分流**：Phase 2 agent 收到 hotspot-filtered diff（节省 context window），Phase 3 finding-verifier 永远收完整原始 diff（用于验证 file:line 和攻击链）。orchestrator 根据接收方构造不同的 Diff Content。

### 修复

- **Smart Detection 遮蔽陷阱** — 之前 unstaged 优先会让 2 行未保存改动遮蔽一条 20 个 commit 的 feature 分支工作
- **Two-pass + verifier 误 REFUTE** — 之前 verifier 也拿 hotspot-filtered diff，当 finding 的 `file:line` 在过滤切片外时会错误 REFUTE。现在 verifier 始终拿完整 diff
- **`--focus performance` 和 `--focus api` 死参数** — 明确为 `quality` 的别名（`api` 还会激活 API 子域）
- **Preflight Step 1 重复跑 `git diff --stat`** — 修改为复用 Smart Detection Step 1 采集的 per-file 数据

### 变更

- **agent.yaml** — `short_description` / `default_prompt` 改为反映 v3 证据验证 + 6 reviewer + 1 verifier 架构
- **README.md / README.zh-CN.md** — 全文同步到 v3（架构图、工作流、参数、输出示例、"Verification > Scoring" 说明、v3.1 的新行为）

### 修改文件

- `SKILL.md` — Smart Detection 重写、Project Scan 硬限制、Linter 检测、Scope mode 字段、Two-pass 分流
- `agents/_base-reviewer.md` — HIGH SIGNAL 规则 #1 引用 `Linters configured`、unchanged code anti-pattern 引用 `Scope mode`
- `agents/agent.yaml` — 描述更新到 v3
- `README.md`、`README.zh-CN.md` — 全文同步
- `ANALYSIS.md` — 进度日志追加

---

## v3.0.0 — 2026-04-17

> 主题：Verification > Scoring — 从打分过滤升级到证据验证

### 架构动因

对标 Anthropic 官方 `code-review` plugin、Cursor BugBot V11、CodeRabbit、Qodo Judge 的 SOTA 实现，行业共识是：**Verification（验证）优于 Scoring（打分）**。v2 的 Haiku confidence-scorer 只读 finding 文本打 0-100 分，无法识别"听起来合理但代码里已被 framework 拦截"的误报。v3 用证据驱动的 verifier 取代打分器，显著降低 false positive。

### 破坏性变更

- **删除 `confidence-scorer` agent** — 改由 `finding-verifier` 做证据核查（REFUTED 的 finding 直接丢弃，DOWNGRADED 降级保留，CONFIRMED 保留，NEEDS-MANUAL-REVIEW 带标签保留）
- **删除 `api-reviewer` agent** — 合并进 `quality-reviewer` 的 API 子域（finding ID 使用 `QUAL-API-NNN` 子前缀）
- **删除 `removal-reviewer` agent** — 合并进 `quality-reviewer` 的 removal 子域（finding ID 使用 `QUAL-REM-NNN` 子前缀）
- **Agent 总数从 8 → 6**：security / quality / solid / testing / frontend / page-verifier，另加 `finding-verifier` 在 Phase 3 运行
- **移除 Adversarial Consensus 机制** — 改为 "Consensus Lock" 安全覆盖：2+ agent 独立命中同一 `file:line` 时，verifier 至少必须保留一条（不允许全部 REFUTE）。不再做机械化 severity +1 提级。

### 新增

- **`agents/_base-reviewer.md`** — 所有 review agent 的公共元规则单一真相源：Iron Law、HIGH SIGNAL 过滤清单、Verify Before Reporting、Severity 表、Anti-Patterns、Finding 输出格式。agent 只维护领域特定内容，约 130 行基础规则不再在 8 个文件中重复。
- **`agents/finding-verifier.md`** — 新的证据验证 agent。对每条 finding 用 `Grep`/`Read`/`Bash` 追溯调用链、消费者、已有测试，产出四态判决：`CONFIRMED` / `DOWNGRADED` / `REFUTED` / `NEEDS-MANUAL-REVIEW`。
- **HIGH SIGNAL 过滤清单**（9 条）— 对标 Anthropic 官方 `code-review` 原则，明确 agent **不应** 报告的类型：linter 能抓的、预存问题、看起来像 bug 实际正确的、琐碎 nitpick、投机性重构、已有测试、泛泛之谈、跨 agent 重复、假想的未来需求。
- **Agent 工具权限显式声明** — 每个 agent frontmatter 增加 `tools:` 字段，避免因继承链导致 verifier 降级为纯文本 scoring。
- **Phase 3 Step 5 输出转换** — orchestrator 在格式化阶段统一做：(1) `file:line` → markdown 链接，(2) 合并 agent 的 `Verified` 与 verifier 的 `Evidence`，(3) 附加 verifier tag（如 `[defense-in-depth gap]`）。
- **Agent 失败降级策略** — 任一 agent 超时或 MCP 不可用时写入 `Not Covered`，不阻塞流程。
- **page-verifier 前置检查** — 运行前验证 Chrome DevTools MCP 连通性与 URL 可达性，失败时 fail-fast 而非静默跑半截。

### 变更

- **Phase 3 流程简化**：Collect → Deduplicate → **Evidence-Based Verification (替代 Scoring+Consensus 两步)** → Self-Check → Format → Confirm（从 7 步压缩为 6 步）
- **`--focus` 参数修复**：`performance` 现在明确是 `quality` 的别名；`api` 是 `quality` 的别名且激活 API 子域
- **`--quick` 模式**：只跑 security / testing / quality（P0/P1 only），跳过 solid / frontend / page-verifier
- **Severity 单一真相源**：校准规则在 `_base-reviewer.md` 唯一定义，SKILL.md 只做用户面向摘要，agent 不再各自重写
- **Two-pass + verifier 兼容**：verifier 即使在 two-pass 模式下也永远接收完整原始 diff，避免因 hotspot-filtered 切片导致误 REFUTE
- **Blast radius 明确阈值**：删除 export 的严重级按 consumer 数量显式定档（5+/跨模块=P0，1-4 同模块=P1，仅测试=P2），不再模糊"按 blast radius"
- **Linter-catchable 规则收紧**：只有当项目实际配置了对应 linter（存在 `.eslintrc*` / `tsconfig.json` / `ruff.toml` 等）时才可 drop，否则仍按 P3 保留
- **Markdown 链接输出**：`file:line` 在最终报告统一转为 IDE 可点击链接 `[src/x.ts:42](src/x.ts#L42)`

### 新增文件

- `agents/_base-reviewer.md`
- `agents/finding-verifier.md`

### 删除文件

- `agents/confidence-scorer.md`
- `agents/api-reviewer.md`
- `agents/removal-reviewer.md`

### 修改文件

- `SKILL.md` — Phase 3 重写、决策矩阵、HIGH SIGNAL 小节、Resources 表、输出模板
- `agents/security-reviewer.md`、`agents/quality-reviewer.md`、`agents/solid-reviewer.md`、`agents/testing-reviewer.md`、`agents/frontend-reviewer.md`、`agents/page-verifier.md` — 全部瘦身引用 `_base-reviewer.md`，增加 `tools:` 声明

### 迁移指引

从 v2 升级：

- 若有脚本依赖 finding ID 前缀 `API-NNN` 或 `REM-NNN`，改为 `QUAL-API-NNN` / `QUAL-REM-NNN`
- 若有工作流依赖 `confidence-scorer` 的 0-100 分输出，改为读 `finding-verifier` 的 `Outcome` 字段
- `--focus api` 和 `--focus performance` 现在会 route 到 `quality-reviewer`，不再启动独立 agent

---

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
