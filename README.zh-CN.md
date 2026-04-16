# CR Homie

面向 AI Agent 的专业代码审查技能。以资深工程师视角进行结构化审查，覆盖架构设计、安全、性能、测试、前端质量、API 契约和代码质量。

## 安装

```bash
npx skills add YuArtian/cr-homie
```

## 功能特性

- **SOLID 原则** — 检测 SRP、OCP、LSP、ISP、DIP 违反，提供重构建议
- **安全扫描** — XSS、注入攻击、SSRF、竞态条件、认证缺陷、密钥泄露、包管理器一致性。**攻击链验证**：追溯入口点 → 框架/中间件 → 漏洞代码，确认可利用性后再报告
- **性能检查** — N+1 查询、CPU 热点、缺失缓存、内存问题
- **错误处理** — 吞异常、异步错误未捕获、缺失错误边界
- **边界条件** — 空值处理、空集合、off-by-one、数值越界
- **测试质量** — 覆盖率不足、测试反模式、过度 mock、不稳定测试
- **前端质量** — 编码原则（KISS、函数式、DRY、YAGNI、整洁架构）、无障碍、渲染性能、Bundle 体积、CSS、状态管理、国际化
- **假数据检测** — 硬编码 mock 数据、占位内容、假功能标记为 P0/P1
- **API 契约** — Breaking Change 检测、向后兼容、版本策略
- **移除计划** — 识别死代码，提供安全删除方案
- **可观测性** — 日志缺失、监控指标不足、告警盲区
- **页面验证** — 通过 Chrome DevTools MCP 运行时验证：Lighthouse、控制台错误、网络请求检查、视觉检查

## 工作原理

### 设计理念

- **审查优先** — 仅输出发现，不自动修改代码，直到你明确确认
- **铁律（Iron Law）** — 每条发现必须标注 `file:line`，解释具体风险，提出明确修复方案。不允许模糊建议
- **验证后报告** — 每条发现必须验证上下文（调用方、路由定义、配置等）后才能纳入报告。仅匹配模式不足以成为 finding
- **渐进加载** — 参考清单按工作流步骤按需加载，不会一次性全部占用上下文
- **条件步骤** — 前端质量、API 契约检查、移除计划仅在 diff 涉及相关代码时激活
- **反模式防护** — 明确规则防止严重程度膨胀、重复发现和超范围建议

### 工作流

```
git diff → 预检 → 审查步骤 → 自检 → 页面验证? → 输出 → 用户确认
              │                          │              │
              ├─ 检测范围、语言、关键路径    │              ├─ Lighthouse 审计
              │                          │              ├─ 控制台错误
              │     ┌──────────────────┐  │              ├─ 假数据检测
              │     │    审查步骤       │  │              ├─ 无障碍树检查
              │     ├──────────────────┤  │              └─ 视觉 + 响应式
              │     │ SOLID + 架构      │  │
              │     │ 安全扫描 ⚠️       │  ├─ 验证每条发现有 file:line
              │     │ 代码质量          │  ├─ 验证严重程度合理
              │     │ 测试质量 ⚠️       │  └─ 验证无重复
              │     │ 前端质量 (条件)    │
              │     │ API 契约 (条件)    │
              │     │ 移除计划 (条件)    │
              │     └──────────────────┘
```

1. **预检** ⛔ — **智能探测**：未指定范围时，自动按 unstaged → staged → 分支 diff 优先级探测（使用第一个有内容的）。收集变更文件，检测语言，识别关键路径（认证、支付、数据写入）。diff 为空则建议使用 `project` 模式。超过 2000 行或 15 个文件时，采用**两轮扫描**（第一轮：快扫标记热点；第二轮：聚焦深度 review + 上下文扩展）。`project` 模式同样采用两轮策略——先快扫所有模块，再逐个热点深度审查。
2. **SOLID + 架构** — 加载 `solid-checklist.md`。检查 SRP/OCP/LSP/ISP/DIP 违反，提出渐进式重构方案。
3. **安全扫描** ⚠️ — 加载 `security-checklist.md`。检查 XSS、注入、SSRF、认证缺陷、竞态条件、密钥泄露、包管理器一致性。**验证攻击链**：每个安全发现追溯外部入口 → 框架层处理 → 漏洞代码，标注置信度为 `已确认可利用`、`防御纵深缺失` 或 `需进一步验证`。
4. **代码质量** — 加载 `code-quality-checklist.md`。检查错误处理反模式、N+1 查询、热路径 CPU、边界条件（null、空集合、off-by-one）、可观测性缺失。
5. **测试质量** ⚠️ — 加载 `testing-checklist.md`。检查变更代码是否有测试覆盖，测试是否验证行为（而非实现细节），标记过度 mock 和不稳定测试。
6. **前端质量** _(条件)_ — 加载 `frontend-checklist.md`，当 diff 包含前端文件时激活。应用编码原则（KISS、函数式、DRY、YAGNI、整洁架构）。检查假数据（P0/P1）、无障碍、渲染性能、Bundle 体积、CSS、状态管理、国际化。
7. **API 契约** _(条件)_ — 加载 `api-contract-checklist.md`，仅当 diff 涉及公共接口、端点或导出类型时激活。检查 Breaking Change 和向后兼容性。
8. **移除候选** _(条件)_ — 加载 `removal-plan.md`，仅当 diff 暴露死代码或过期 feature flag 时激活。区分"可立即安全删除"和"需制定计划延后删除"。
9. **自检** ⛔ — 输出前验证所有发现：每条有 `file:line`、严重程度合理、无重复、无模糊建议。
10. **页面验证** _(条件)_ — 加载 `page-verification-guide.md`，仅当设置 `--verify` 时激活。导航到 `--url`，运行 Lighthouse，检查控制台错误，通过网络请求/运行时检测假数据，截图检查桌面 + 移动端 + 暗色模式。
11. **输出** — 按严重程度（P0–P3）分组的结构化报告，如有页面验证结果则附加。
12. **确认** ⚠️ — 提供选项：全部修复 / 仅修 P0-P1 / 选择性修复 / 不修改。用户确认前不做任何改动。

> ⛔ = 阻塞（必须完成才能继续）· ⚠️ = 必需（不可跳过）

## 使用方法

```bash
/cr-homie                        # 智能探测：unstaged → staged → 分支 diff
/cr-homie staged                 # 审查已暂存的变更
/cr-homie commit:abc123          # 审查指定 commit
/cr-homie pr:42                  # 审查 PR
/cr-homie project                # 全项目扫描（所有源文件）
/cr-homie project:src/           # 仅扫描 src/ 目录
/cr-homie --focus security       # 仅关注安全
/cr-homie --focus frontend       # 仅关注前端质量
/cr-homie --quick                # 快速扫描（仅 P0/P1）
/cr-homie --verify --url http://localhost:3000  # 代码审查 + 页面验证
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `<scope>` | 审查范围：`staged`、`commit:<hash>`、`pr:<number>`、`branch:<name>`、`project[:<path>]` 或文件路径 | 智能探测 |
| `--focus <area>` | 聚焦领域：`security`、`solid`、`performance`、`quality`、`testing`、`frontend`、`api`、`all` | `all` |
| `--min-severity <level>` | 最低报告级别：`P0`、`P1`、`P2`、`P3` | `P3` |
| `--quick` | 仅报告 P0/P1，跳过 SOLID 和移除分析 | 关闭 |
| `--verify` | 启用页面级验证（需配合 `--url`，依赖 Chrome DevTools MCP） | 关闭 |
| `--url <url>` | 开发服务器地址，用于页面验证 | — |

## 输出示例

```markdown
## 代码审查摘要

**范围**: 未暂存变更
**审查文件**: 3 个文件，87 行变更
**主要语言**: TypeScript
**总体评估**: REQUEST_CHANGES

---

## 发现

### P0 - 严重
（无）

### P1 - 高危
1. **src/auth/login.ts:42** SQL 注入 — 字符串拼接构造查询
   - **攻击路径**: `POST /api/login` → Express 路由 `req.body.username` → `login()` → 原始 SQL 拼接
   - **风险**: 攻击者可通过构造用户名输入提取/篡改数据库
   - **置信度**: 已确认可利用
   - **修复**: 使用参数化查询：`db.query('SELECT * FROM users WHERE name = ?', [username])`

### P2 - 中等
2. **src/services/file.ts:73** 路径拼接未校验
   - **攻击路径**: `GET /files/{name}` → Express `req.params.name` 仅匹配单路径段（不含 `/`）→ 路由层拦截 `../`
   - **风险**: 代码自身缺少路径校验，依赖框架路由行为
   - **置信度**: 防御纵深缺失
   - **修复**: 添加 `path.resolve()` + 前缀检查，与 `deleteFile()` 对齐

3. **src/services/order.ts:118** 读-改-写操作未使用事务
   - **风险**: 并发订单在高负载下可能导致超卖
   - **修复**: 用事务包裹，使用 `SELECT ... FOR UPDATE`

### P3 - 低
4. **src/utils/format.ts:7** 魔法数字 86400
   - **风险**: 可读性差 — 不清楚 86400 代表什么
   - **修复**: 提取为常量 `const SECONDS_PER_DAY = 86400`

---

## 未覆盖
- 数据库迁移文件不在 diff 范围内
- 无集成测试环境可用于验证查询变更
```

## 严重程度

| 级别 | 名称 | 描述 | 行动 |
|------|------|------|------|
| P0 | 严重 | 安全漏洞、数据丢失风险、正确性 Bug | 必须阻止合并 |
| P1 | 高危 | 逻辑错误、严重 SOLID 违反、性能退化、关键测试缺失 | 合并前应修复 |
| P2 | 中等 | 代码坏味道、轻微 SOLID 违反、测试缺口 | 当前 PR 修复或创建跟踪项 |
| P3 | 低 | 风格、命名、小建议 | 可选改进 |

## 项目结构

```
cr-homie/
├── SKILL.md                             # 工作流定义 + 铁律 + 反模式
├── agents/
│   └── agent.yaml                       # Agent 接口 + 触发关键词
└── references/                          # 知识库（按步骤按需加载）
    ├── solid-checklist.md               # SOLID 检查提示 + 语言特定红旗
    ├── security-checklist.md            # OWASP 风险、竞态条件、加密、供应链
    ├── code-quality-checklist.md        # 错误处理、N+1、缓存、边界条件、可观测性
    ├── testing-checklist.md             # 覆盖率、测试质量、反模式
    ├── frontend-checklist.md            # 编码原则 + 无障碍、性能、Bundle、CSS、状态、i18n
    ├── api-contract-checklist.md        # Breaking Change、向后兼容、版本控制
    ├── removal-plan.md                  # 安全删除 vs 延后删除模板
    └── page-verification-guide.md       # Chrome DevTools MCP 验证流程
```

`references/` 目录作为**渐进式知识库** — 每个文件仅在对应工作流步骤执行时加载到上下文中，保持 token 使用高效。

## 页面验证（Chrome DevTools MCP）

当提供 `--verify --url <url>` 时，CR Homie 在静态代码审查之外，还会验证运行中的页面：

```bash
/cr-homie --verify --url http://localhost:5173
```

**前提条件**：安装 Chrome DevTools MCP 服务器：

```bash
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

**验证项目**：

| 检查项 | 使用工具 | 严重程度 |
|--------|----------|----------|
| 控制台错误 | `list_console_messages` 过滤 error/warn | 未捕获错误 = P0，框架警告 = P1 |
| 假数据检测 | `list_network_requests` + `evaluate_script` | Mock URL / 占位文本 = P1 |
| 无障碍 | `lighthouse_audit` + `take_snapshot`（无障碍树） | 评分 < 50 = P1，缺失 label = P2 |
| 视觉布局 | `take_screenshot` 桌面 + 移动端（375px） | 溢出 / 布局错乱 = P2 |
| 暗色模式 | `emulate` colorScheme: dark | 不可见文字 / 硬编码颜色 = P2 |
| 性能 | `performance_start_trace`（可选） | LCP > 2.5s = P1，CLS > 0.25 = P1 |

## 前端编码原则

审查前端代码时，CR Homie 应用以下原则（详细检查项见 `frontend-checklist.md`）：

1. **KISS** — 删掉能删的代码，用最直接的方式实现。
2. **组件单一职责** — 一个组件 = 一个变更理由。充分组件化，但不过度拆分。
3. **函数式编程** — 业务逻辑保持纯净，副作用放在边界（hooks、事件处理器）。
4. **DRY** — 第三次出现时提取。两次是巧合，三次是模式。
5. **整洁架构** — 命名即文档，读代码即懂意图，无需注释解释。
6. **YAGNI** — 只为当前需求编码，不做投机性抽象。
7. **生产就绪** ⚠️ — 不允许假数据、mock URL、假功能出现在生产代码中（P0/P1）。

## 许可证

MIT
