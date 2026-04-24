# CR Homie

面向 AI Agent 的证据驱动代码审查技能。6 个专项 reviewer 并行审查，再由独立的 verifier agent 用代码证据证实或证伪每条发现 —— 用事实核查取代数字打分。

## 安装

```bash
npx skills add YuArtian/cr-homie
```

## 检查项

- **安全** — XSS、注入（SQL/NoSQL/命令/GraphQL）、SSRF、路径遍历、认证授权缺陷、密钥泄露、竞态条件、供应链、包管理器一致性。每条声称可利用的发现都附带完整攻击链追溯（入口 → 框架/中间件 → 漏洞代码）与置信度标签：`Confirmed exploitable` / `Defense-in-depth gap` / `Needs verification`。
- **质量**（一个 agent 覆盖三个子域）
  - 运行时质量 — 错误处理、性能（N+1、热路径 CPU、缺失缓存）、边界条件、并发、可观测性
  - API 契约 — REST/GraphQL/导出/Schema 的 breaking change、向后兼容、类型安全回归、版本化
  - 死代码移除 — 未用导出、废弃路径、陈旧特性开关，带"可安全删除"与"带计划延迟"两档建议
- **SOLID** — SRP/OCP/LSP/ISP/DIP 违反、代码坏味道，重构方案尺寸不超过当前 diff
- **测试** — 覆盖缺口、行为测试 vs 实现细节测试、反模式（脆弱、过度 mock、测试私有内部）、针对 JS/TS/Go/Python/Java 的语言特定检查
- **前端** — 7 条编码原则（KISS、组件 SRP、FP、DRY、整洁架构、YAGNI、生产就绪）、a11y、渲染性能、bundle、CSS、状态、i18n。生产代码里的假数据/mock URL 一律 P0/P1。
- **页面验证**（可选）— 通过 Chrome DevTools MCP 做运行时验证：控制台错误、网络请求中的假数据、Lighthouse 审计、a11y 树、视觉布局、暗黑模式、性能 trace。

## 工作原理

### 设计理念

- **Verification > Scoring（验证优于打分）** — 由独立的 verifier agent 用 `grep`、`Read`、`Bash` 去核查每条发现的攻击链、调用方、测试、消费者。取代了原来的 Haiku 打分过滤器。
- **HIGH SIGNAL（只报高信号）** — 9 类发现静默丢弃（linter 能抓的、预存问题、看起来像 bug 但实际正确的、琐碎 nitpick、投机性重构、已有测试的、泛泛建议、跨 agent 重复、假想的未来需求）。
- **Iron Law（铁律）** — 每条发现必须给出精确的 `file:line`、具体风险场景、具体修复方案。不允许"考虑改进错误处理"这种泛泛建议。
- **Review-first** — 技能只产出发现，必须经过你确认才会实施修复。
- **共享元规则** — Iron Law、HIGH SIGNAL 过滤、Severity 校准、Verify Before Reporting、Anti-Patterns 集中在 [agents/_base-reviewer.md](agents/_base-reviewer.md)，每个 reviewer 继承，规则不会在 agent 间漂移。
- **多 Agent 并行** — 领域 reviewer 并发处理同一份 Preflight Context Block，降低 token 压力、提高覆盖。
- **按需激活** — 前端、页面验证，以及 quality reviewer 的 API 子域和死代码子域，只有在 Preflight 检测到相关信号时才启用。

### 架构

```text
Phase 1: 预检（编排器）
    ├─→ 智能 scope 探测（感知当前分支 —— 在 feature 分支默认走 branch diff；在默认分支回退到 unstaged/staged）
    ├─→ 大 diff（>2000 行或 >15 文件）走 two-pass
    ├─→ 探测语言、前端、API 表面、死代码、linter 配置、包管理器
    └─→ 组装 Preflight Context Block
    ↓
Phase 2: 并行 Review Agents
    ├─→ security-reviewer   [opus]    ← 必选
    ├─→ testing-reviewer    [inherit] ← 必选
    ├─→ quality-reviewer    [inherit] ← 运行时质量 + API（若检测到）+ 死代码（若检测到）
    ├─→ solid-reviewer      [opus]    ← 除非 --quick 或 --focus 排除
    ├─→ frontend-reviewer   [inherit] ← 检测到前端文件或 --focus frontend
    └─→ page-verifier       [inherit] ← --verify + --url + MCP 可达
    ↓ 各 agent 返回 findings
Phase 3: 聚合（编排器）
    ├─→ Collect + Deduplicate
    ├─→ finding-verifier    [inherit] ← CONFIRMED / DOWNGRADED / REFUTED / NEEDS-MANUAL-REVIEW
    ├─→ 安全覆盖（SEC-P0 强证据门槛、生产就绪、共识锁）
    ├─→ Self-check + HIGH SIGNAL 再过滤
    ├─→ 格式化输出（file:line 转 markdown 链接、合并验证证据）
    └─→ 下一步确认 ⚠️
```

### 工作流

1. **Phase 1 — 预检** ⛔ — 先做 repo 探测（通过 `git symbolic-ref refs/remotes/origin/HEAD` 自动识别默认分支，fallback 依次探测 `main` / `master` / `develop` / `trunk`；detached HEAD 和无 remote 的仓库优雅降级）。再并行采集适用的 scope 信号（unstaged / staged / branch-vs-default），按当前分支决定默认 scope：在默认分支上回退到未提交改动；在 feature 分支上以 branch diff 为默认（避免 2 行未保存改动遮蔽一条 20 个 commit 的分支工作）。多个信号都有内容时会展示一页摘要让你覆盖。检测语言、前端、API 表面、死代码、linter 配置（ESLint/tsc/Prettier/Ruff/golangci-lint 等 —— 决定 HIGH SIGNAL linter-catchable 过滤是否生效）、包管理器一致性。大 diff 走 two-pass（Pass 1 由 orchestrator 内联执行识别热点，不派独立 agent；Pass 2 把过滤后切片传给 Phase 2 agent，verifier 始终收完整 diff）。`project` 模式有硬限制（300 文件 / 50k 行软警告；1k 文件 / 150k 行硬门槛，超出会强制你缩小范围或切到 hotspot-only 模式）。

2. **Phase 2 — 并行 agent** — security 和 testing 始终运行；quality 默认运行（除非 focus 排除）；solid 默认运行（除非 --quick）；frontend、page-verifier 条件激活。所有 agent 继承 `agents/_base-reviewer.md` 的共享规则。每条发现报告前必须带 `Verified:` 字段，说明核查了哪些调用方、测试、框架行为。

3. **Phase 3 — 聚合** ⛔ — 跨 agent 去重。`finding-verifier` 拿到**完整原始 diff**（即使 Phase 2 用了 two-pass 过滤切片）加上每条 finding 的上下文，对每条返回四态之一。安全覆盖保护 SEC-P0（REFUTE 需要强且无歧义的证据）、生产假数据、多 agent 共同命中的位置（至少保留一条）。最后 orchestrator 把 agent 的 `Verified:` 和 verifier 的 `Evidence:` 合并为单字段、把 `file:line` 转成 IDE 可点击的 markdown 链接、应用 `--min-severity`、跑一遍 HIGH SIGNAL 终检，然后询问你下一步。

> ⛔ = BLOCKING（必须完成才能推进）· ⚠️ = REQUIRED（不得跳过）

## 用法

```bash
/cr-homie                        # 基于当前分支的智能 scope 探测
/cr-homie unstaged               # 显式审查未暂存改动
/cr-homie staged                 # 审查 staged 改动
/cr-homie commit:abc123          # 审查指定 commit
/cr-homie pr:42                  # 审查指定 PR（需要 gh CLI）
/cr-homie branch:feat/login      # 审查指定分支 vs 探测到的默认分支
/cr-homie project                # 全项目扫描（受硬限制约束）
/cr-homie project:src/           # 仅扫描 src/ 目录
/cr-homie --focus security       # 只聚焦安全
/cr-homie --focus quality        # 聚焦质量（含 API + 死代码子域）
/cr-homie --focus frontend       # 聚焦前端质量
/cr-homie --quick                # 只报 P0/P1，跳过 SOLID 和前端
/cr-homie --verify --url http://localhost:3000   # 代码审查 + 运行时页面验证
```

### 参数

| 参数 | 说明 | 默认值 |
| ---- | ---- | ------ |
| `<scope>` | `unstaged`、`staged`、`commit:<hash>`、`pr:<number>`（需要 [`gh` CLI](https://cli.github.com/)）、`branch:<name>`（与探测到的默认分支对比）、`project[:<path>]` 或文件路径 | 基于分支的智能探测 |
| `--focus <area>` | `security`、`quality`（含 `performance` 和 `api` 别名）、`solid`、`testing`、`frontend`、`all` | `all` |
| `--min-severity <level>` | 最低报告严重级：`P0`、`P1`、`P2`、`P3` | `P3` |
| `--quick` | 只报 P0/P1，跳过 SOLID 和前端 | off |
| `--verify` | 启用运行时页面验证（需要 `--url` 和 Chrome DevTools MCP） | off |
| `--url <url>` | 页面验证的开发服务器 URL | — |

### 仓库要求

- **Git 仓库，任意默认分支** —— cr-homie 自动识别 `main` / `master` / `develop` / `trunk`（或任何 `origin/HEAD` 指向的分支）。无硬编码分支名
- **Detached HEAD 与无 remote 仓库** —— 优雅降级：跳过 branch-vs-default 比较，回退到 `unstaged → staged`，或要求你指定显式 scope
- **`gh` CLI** —— 只在使用 `pr:<number>` 时需要。从 [cli.github.com](https://cli.github.com/) 安装
- **Chrome DevTools MCP 服务** —— 只在使用 `--verify` 时需要。`claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest` 安装；未连接时 `page-verifier` fail-fast 打印 skip 提示，其他 reviewer 照常运行

## 输出示例

```markdown
## Code Review Summary

**Scope**: branch diff vs main (feat/login)
**Files reviewed**: 3 files, 87 lines changed
**Primary language(s)**: TypeScript
**Agents launched**: security-reviewer, testing-reviewer, quality-reviewer, solid-reviewer
**Overall assessment**: REQUEST_CHANGES

---

## Findings

### P0 - Critical
(none)

### P1 - High
1. **[src/auth/login.ts:42](src/auth/login.ts#L42)** SQL injection via username `[SEC-001]`
   - **Risk**: 攻击者可通过构造的 username 读写 users 表（POST /api/login）
   - **Attack path**: POST /api/login → Express JSON body → login(req.body.username) → line 42 原始 SQL 拼接
   - **Confidence**: Confirmed exploitable
   - **Fix**: 改用参数化查询 `db.query('SELECT * FROM users WHERE name = ?', [username])`
   - **Verified**: grep `login()` 调用方 —— 只在 POST /api/login 处被调用且上游无校验；verifier: Confirmed —— 输入从 JSON body 未过滤流入拼接。

### P2 - Medium
2. **[src/services/file.ts:73](src/services/file.ts#L73)** 路径拼接未校验 `[SEC-002]` `[defense-in-depth gap]`
   - **Risk**: 代码自身没有路径校验，依赖 Express 路由行为
   - **Attack path**: GET /files/{name} → Express `req.params.name` 只匹配单段 → `../` 被框架层拦截
   - **Confidence**: Defense-in-depth gap
   - **Fix**: 像 `deleteFile()` 一样加 `path.resolve()` + 前缀检查
   - **Verified**: grep 路由定义；verifier: Downgraded —— 框架拦截，但代码层校验缺失。

3. **[src/services/order.ts:118](src/services/order.ts#L118)** 读-改-写无事务 `[QUAL-001]`
   - **Risk**: 高并发下订单可能超卖
   - **Fix**: 用事务包起来 `SELECT ... FOR UPDATE`
   - **Verified**: grep 调用方，无外层事务；verifier: Confirmed —— 并发下订单确实有竞态窗口。

### P3 - Low
4. **[src/utils/format.ts:7](src/utils/format.ts#L7)** 魔法数 86400 `[SOLID-001]`
   - **Risk**: 可读性 —— 86400 的含义不清晰
   - **Fix**: 提取为 `const SECONDS_PER_DAY = 86400`

---

## Not Covered
- 数据库迁移文件未在 diff 内
- 无集成测试环境，查询改动无法运行验证
```

## 严重级

| 级别 | 行动 |
| ---- | ---- |
| **P0** | 阻止合并 —— 外部可利用的安全问题、数据丢失、正确性 bug、生产路径上的假数据 |
| **P1** | 合并前必修 —— 重大漏洞、关键路径逻辑错误、缺失关键测试、无迁移方案的 API breaking change |
| **P2** | 本 PR 内修复或建 follow-up —— 纵深防御缺口、代码坏味道、缺失边界测试 |
| **P3** | 可选 —— 风格、命名、微优化 |

完整校准规则与示例：[agents/_base-reviewer.md](agents/_base-reviewer.md)。

## Review Agent 列表

| Agent | 领域 | 模型 | 激活条件 |
| ----- | ---- | ---- | -------- |
| `security-reviewer` | 安全、可靠性、竞态、供应链、包管理器一致性 | opus | 必选 |
| `testing-reviewer` | 测试覆盖、质量、反模式 | inherit | 必选 |
| `quality-reviewer` | 运行时质量 + API 契约 + 死代码移除（三子域，一个 agent） | inherit | 除非 `--focus` 排除 |
| `solid-reviewer` | SOLID 原则、架构坏味道 | opus | 除非 `--quick` 或 `--focus` 排除 |
| `frontend-reviewer` | 7 条前端原则、a11y、性能、bundle、CSS、状态、i18n、生产就绪 | inherit | 检测到前端或 `--focus frontend` |
| `page-verifier` | 通过 Chrome DevTools MCP 做运行时页面验证 | inherit | `--verify` + `--url` + MCP 可达 |
| `finding-verifier` | 基于证据的发现验证（取代 confidence scoring） | inherit | Phase 3 始终运行 |

各 reviewer 的共享元规则在 [agents/_base-reviewer.md](agents/_base-reviewer.md)。

## 目录结构

```text
cr-homie/
├── SKILL.md                             # 三阶段编排工作流
├── agents/
│   ├── agent.yaml                       # 技能接口元数据
│   ├── _base-reviewer.md                # 共享元规则（Iron Law、HIGH SIGNAL、Severity、Verify、Anti-Patterns、输出格式）
│   ├── security-reviewer.md             # 安全 + 可靠性 + 包管理器一致性
│   ├── quality-reviewer.md              # 运行时质量 + API 契约 + 死代码移除
│   ├── solid-reviewer.md                # SOLID + 架构坏味道
│   ├── testing-reviewer.md              # 测试质量与覆盖
│   ├── frontend-reviewer.md             # 前端质量（条件激活）
│   ├── page-verifier.md                 # 运行时页面验证（条件激活）
│   └── finding-verifier.md              # Phase 3 证据验证 agent
└── references/                          # 知识库（各 agent 按需加载）
    ├── security-checklist.md            # OWASP 风险、竞态、加密、供应链、攻击链验证流程
    ├── code-quality-checklist.md        # 错误处理、N+1、缓存、边界、可观测性
    ├── api-contract-checklist.md        # Breaking change、向后兼容、版本化
    ├── removal-plan.md                  # 可删除 vs 带计划延迟的模板
    ├── solid-checklist.md               # SOLID 坏味道提示 + 语言特定标记
    ├── testing-checklist.md             # 覆盖、测试质量、反模式
    ├── frontend-checklist.md            # 7 条原则 + a11y、性能、bundle、CSS、状态、i18n
    └── page-verification-guide.md       # Chrome DevTools MCP 验证流程
```

每个 agent 只加载与自己领域相关的 checklist，控制单 agent 上下文开销。

## 页面验证（Chrome DevTools MCP）

提供 `--verify --url <url>` 时，CR Homie 会在静态审查基础上再验证运行态页面：

```bash
/cr-homie --verify --url http://localhost:5173
```

**前置条件**：安装 Chrome DevTools MCP 服务：

```bash
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

MCP 未连接时，page-verifier 会 fail-fast 打印 skip 提示，其他 reviewer 照常运行。

**检查项**：

| 项目 | 手段 | 严重级 |
| ---- | ---- | ------ |
| HTTP 状态 | navigate + status | 5xx = P0；公开 URL 4xx = P1；需要鉴权的 401/403 = P3 |
| 控制台错误 | `list_console_messages` 过滤 error/warn | 未捕获错误 = P0，框架 warning = P1 |
| 假数据 | `list_network_requests` + `evaluate_script` | 生产构建中的 mock URL = P0，占位文本 = P1 |
| 无障碍 | `lighthouse_audit` + `take_snapshot` | 分数 <50 = P1，缺失 label = P2 |
| 视觉布局 | `take_screenshot` 桌面 + 移动（375px） | 溢出/布局损坏 = P2 |
| 暗黑模式 | `emulate` colorScheme: dark | 隐形文字/硬编码颜色 = P2 |
| 性能 | `performance_start_trace`（可选） | LCP > 2.5s = P1，CLS > 0.25 = P1 |

## 前端编码原则

审查前端代码时，CR Homie 应用以下 7 条原则（详见 [references/frontend-checklist.md](references/frontend-checklist.md)）：

1. **KISS** — 能删的都删。最直接的实现胜出。
2. **组件 SRP** — 一个组件 = 一个变更原因。适度拆分，不过度拆。
3. **函数式编程** — 业务逻辑保持纯；副作用放在边界（hooks、事件处理器）。
4. **DRY** — 第三次重复时再抽。两次是巧合，三次是模式。
5. **整洁架构** — 命名即文档。读代码应看出意图，无需注释。
6. **YAGNI** — 为今天的需求建造，不做投机抽象。
7. **生产就绪** ⚠️ — 生产代码不允许假数据、mock URL、未完成功能（P0/P1）。

## 为什么是 Verification 而非 Scoring

Scoring 问的是"*这条 finding 听起来对吗*" —— 容易保留"听起来合理的误报"。

Verification 问的是"*我能不能证明这条 finding 走到了它描述的失败路径*" —— 需要证据，能识别幻觉。

代码审查的误报几乎总是同一种形状：pattern 匹配上去了危险模式，但上下文已经消除风险（框架自动转义、上游中间件拦截、已有事务、已有测试）。只读 finding 文本的打分器看不到这些上下文；能 grep/read 的 verifier 可以看到。这和 Anthropic 官方 `code-review` 插件、Cursor BugBot V11、CodeRabbit 沙箱验证走的是同一条路 —— 各家纯打分流水线在 50% 左右精度达到天花板后做的架构迁移。

完整行业基准和 v3 架构推导见 [ANALYSIS.md](ANALYSIS.md)。

## License

MIT
