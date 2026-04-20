# CR Homie 架构分析 & 对标报告

> 分析日期：2026-04-17

---

## 一、项目架构总览

```text
SKILL.md (主编排器 — 3 阶段工作流)
  ├── Phase 1: Preflight (收集 diff、检测语言/前端/API/死代码信号)
  ├── Phase 2: 并行 Review Agents (8 个审查 agent + 各自的 checklist)
  └── Phase 3: Aggregation (去重 → 对抗共识 → confidence-scorer → 自检 → 输出)

agents/           — 9 个 agent 定义 (prompt-only, 无代码)
references/       — 8 个 checklist/参考文档
agent.yaml        — 仅有接口元数据
```

---

## 二、自身架构问题诊断

### P0 — 架构级问题

#### 1. Confidence Scorer 用 Haiku 审判 Opus 的发现 — 能力倒挂

`security-reviewer` 和 `solid-reviewer` 指定用 Opus（最强模型），但 Phase 3 的 `confidence-scorer` 用 Haiku（最弱模型）来打分过滤它们的发现。

- Haiku 缺乏对复杂安全攻击链的理解深度，可能错误地给低分
- 虽然有 "P0 safety override"，但 P1/P2 的安全发现没有保护
- 本质上是让实习生审核高级工程师的安全审计报告

**建议**: confidence-scorer 至少用 inherit，或改为二次验证机制（见下文对标分析）。

#### 2. 纯 Prompt 架构 — 没有执行保障

所有 agent 都是 markdown 文件，没有实际代码编排。整个工作流依赖 LLM 读懂 SKILL.md 后自觉执行。

- agent 的 model 指定 (`opus`, `haiku`, `inherit`) 没有强制执行机制
- Phase 3 的去重、共识提升、过滤等复杂逻辑全靠自然语言描述
- 两步 review（大 diff 的 Pass 1/Pass 2）没有结构化输出定义

#### 3. agent.yaml 形同虚设

仅 5 行元数据，不包含任何 agent 配置、路由或编排逻辑。所有 agent 的配置散落在 SKILL.md 的自然语言中。

---

### P1 — 设计问题

#### 4. Adversarial Consensus 逻辑有缺陷

2+ agent 标记同一 `file:line` 时提升严重级别：

- `file:line` 粒度太粗（注入风险 P1 + 缺少测试 P2 = 不同问题，不应触发共识提升）
- 与 Anti-Pattern "不要膨胀严重级别" 自相矛盾
- 导致严重级别通胀

#### 5. Agent 文件大量重复（DRY 违反）

Iron Law / Anti-Patterns / Severity 表格在 9 个 agent 文件中重复（~190 行冗余），更新共享规则需要同步修改 9 个文件。

#### 6. `--focus performance` 是死参数

声明了但没有对应 agent 或映射规则，Agent Launch Decision Matrix 中无 performance 行。

#### 7. Smart Detection 优先级违反直觉

unstaged → staged → branch 顺序意味着：2 行未保存修改会遮蔽 20 个 commit 的 branch 工作。

#### 8. security/testing "永远启动" 过于绝对

`--focus frontend` 时仍启动 security 和 testing agent，增加时间和噪音。

---

### P2 — 实现细节问题

- **Two-Pass 定义模糊**: "skim" 和 "hotspot" 无具体标准，Pass 1→Pass 2 交接格式未定义
- **Checklist 覆盖重叠无交叉引用**: error handling / performance / race conditions 在多个 checklist 中重复
- **语言覆盖有限**: 仅 JS/TS、Go、Python、Java，无 Rust/C++/Swift 等
- **Project Scan 缺少硬限制**: 大项目可能超出 context window 但无降级策略
- **page-verifier 无 MCP 可用性检测**: `--verify` 时 MCP 不可用则静默失败

---

## 三、对标对象总览

| 类别 | 工具 | F1/Resolution | 架构特点 |
|------|------|--------------|----------|
| **Anthropic 官方** | `code-review` plugin | — | 4 agent 并行 + 二次验证过滤 |
| **Anthropic 官方** | `pr-review-toolkit` plugin | — | 6 个可组合模块化 agent |
| **Anthropic 官方** | Managed Code Review Service | — | 云端 agent 舰队 + REVIEW.md |
| **商业 SOTA** | CodeRabbit | 51.2% F1 | 40+ linter + LLM + 沙箱执行验证 |
| **商业 SOTA** | Qodo 2.0 | **60.1% F1** | 15+ expert agent + Judge agent |
| **商业 SOTA** | Cursor BugBot | **70% resolution** | 8-pass 投票 → 进化为全 agentic |
| **商业 SOTA** | Greptile | — | 代码图索引 + agent swarm |
| **商业 SOTA** | DeepSource | **<5% FP** | 确定性分析 + AI 双层 |
| **社区 SOTA** | ClaudeMonetFullStack | — | 状态枚举 bug 检测 + 意图提取 |
| **社区 SOTA** | awesome-skills/code-review-skill | — | 9500+ 行 / 11 语言 / 渐进加载 |
| **本项目** | **cr-homie** | — | 8 agent 并行 + confidence scorer |

---

## 四、核心维度对比

### 1. 误报过滤 — cr-homie 最弱的环节

所有 SOTA 工具的核心竞争力都在于降低误报率。

| 工具 | 策略 | 效果 |
|------|------|------|
| **DeepSource** | 7 层处理器流水线 + 确定性静态分析 + Relevance Engine | **<5% FP** |
| **BugBot V1** | 8-pass 随机 diff 顺序 + 多数投票 + 验证模型 | 52% resolution |
| **BugBot V11** | 全 agentic 自验证（agent 自主调用工具验证发现） | **70% resolution** |
| **Qodo 2.0** | Judge agent 仲裁 + 团队校准 + 历史模式匹配 | **60.1% F1** |
| **Greptile** | 向量嵌入反馈循环（开发者 upvote/downvote → 余弦相似度过滤） | 19%→**55%+** |
| **CodeRabbit** | 验证 agent + AST 语法树校验 + 团队学习记录 | 51.2% F1 |
| **Anthropic code-review** | 发现后二次子 agent 验证（每个发现单独验证） | — |
| **Anthropic Managed** | 云端 agent 舰队对每个候选发现做行为级验证 | — |
| **cr-homie** | Haiku confidence scorer（0-100 打分） | 未经验证 |

**关键差距**:

- cr-homie 的 confidence scorer 用 **Haiku 打分** — Anthropic 官方用的是 **独立子 agent 二次验证**
- 业界最佳实践是 **Verification（验证）而非 Scoring（打分）**：CodeRabbit 在沙箱中运行 AI 生成的验证脚本，BugBot V11 让 agent 自主用工具验证
- 打分是廉价但不可靠的；验证是昂贵但有效的

### 2. 架构模式 — 固定流水线 vs 动态 Agentic

| 工具 | 模式 | 趋势 |
|------|------|------|
| **BugBot V1→V11** | 固定 8-pass → **全 agentic**（agent 自主决定调查深度） | 流水线→agentic |
| **Copilot** | 固定分析 → **agentic tool-calling**（agent 动态读关联文件） | 固定→动态 |
| **Qodo 2.0** | Orchestrator 根据 PR 特征**动态选择** 15+ expert 子集 | 动态激活 |
| **CodeRabbit** | 固定流水线 + **agentic 验证**（AI 写脚本在沙箱验证） | 混合 |
| **cr-homie** | 固定 3 阶段流水线，Phase 3 有 6 个串行步骤 | 静态 |

**关键差距**: BugBot 演进历史（V1→V11, 52%→70%）实证了 **固定流水线不如动态 agentic**。

### 3. Agent 设计哲学 — 少而精 vs 多而浅

| 工具 | Agent 数量 | 分组策略 |
|------|-----------|----------|
| **Anthropic code-review** | 4 个并行 | 2x 合规 + 1x bug + 1x 安全 |
| **Anthropic pr-review-toolkit** | 6 个可选 | 按审查维度（error/type/test/comment/code/simplify） |
| **Qodo 2.0** | 15+ expert | 由 Orchestrator 动态选择子集 |
| **CodeProbe** | 9 个 grouped 为 4 | Structural / Safety / Quality / Runtime |
| **BugBot V11** | 1 个 agentic | agent 自主决定分析路径 |
| **cr-homie** | 8 + 1 scorer | security / testing / quality / solid / frontend / api / removal / page-verifier |

**关键差距**:

- Anthropic 官方只用 **4 个 agent** + **二次验证**
- cr-homie 用 **8 个 agent** 但验证环节弱 — 数量多不代表质量高
- CodeProbe 的做法值得借鉴：9 个 expert **分组为 4 个 agent**，减少并行开销

### 4. HIGH SIGNAL 哲学

Anthropic 官方 `code-review` 插件的核心设计原则：

> "We only want **HIGH SIGNAL** issues"

**明确列出不应报告的内容**：

- Pre-existing issues（已存在的问题）
- Something that appears to be a bug but is actually correct
- Pedantic nitpicks that a senior engineer would not flag
- Issues that a linter will catch
- General code quality concerns unless explicitly required in CLAUDE.md

**cr-homie 的差距**:

- Anti-Patterns 列表方向正确但不够精确
- 缺少 "linter 能抓到的不报" 这条关键规则
- 缺少 "看起来像 bug 但实际正确" 的判断指导
- 缺少与项目 CLAUDE.md / REVIEW.md 的集成

### 5. 大 Diff 处理

| 工具 | 策略 |
|------|------|
| **CodeRabbit** | splitPrompt + 混合模式（关键文件原始 diff，其他用摘要） |
| **BugBot V11** | 动态上下文（agent 按需拉取文件，非预加载） |
| **Greptile** | 代码图结构提供上下文（无需完整 diff） |
| **Qodo 2.0** | 按 PR 类型选择性激活 agent |
| **DeepSource** | 确定性分析先跑，LLM 只处理剩余问题 |
| **cr-homie** | Two-pass（快速扫描 → hotspot 过滤）但定义模糊 |

### 6. 独特创新技术（cr-homie 完全缺失）

| 技术 | 来源 | cr-homie |
|------|------|----------|
| **随机 diff 顺序** — 不同顺序引导不同推理路径 | BugBot V1 | 无 |
| **向量嵌入反馈循环** — 开发者反馈训练过滤器 | Greptile | 无 |
| **Judge agent** — 专门仲裁 agent 间冲突 | Qodo 2.0 | 无（用 Adversarial Consensus 代替，但有缺陷） |
| **沙箱执行验证** — AI 写脚本验证发现 | CodeRabbit | 无 |
| **收敛检测** — 发现稳定后停止审查 | Calimero | 无 |
| **状态枚举 bug 检测** — 建状态表 + 追踪执行路径 | ClaudeMonetFullStack | 无 |
| **意图提取** — 专门分析 PR 意图，影响置信度 | ClaudeMonetFullStack | 无 |
| **测试基线** — review 前先跑测试 | ClaudeMonetFullStack | 无 |
| **REVIEW.md 支持** — 项目级审查定制 | Anthropic Managed | 无 |
| **Git 历史回归检测** — git blame + 历史 PR comment | ClaudeMonetFullStack | 无 |
| **AST + 确定性分析 + LLM 混合** | DeepSource, Kodus | 无 |
| **渐进加载** — 核心 ~190 行，语言引用按需加载 | awesome-skills | 无 |

---

## 五、cr-homie 的差异化优势

| 优势 | 对比 |
|------|------|
| **Iron Law**（每个发现必须有 file:line + 风险 + 修复） | 与 Anthropic 官方一致，优于多数社区 skill |
| **Attack chain verification**（安全发现追踪完整攻击链） | 超过大部分社区 skill，接近官方水平 |
| **条件激活**（frontend/api/removal 按需启动） | 方向正确，Qodo 2.0 做得更精细 |
| **Page verification**（Chrome DevTools MCP 运行时验证） | 独特功能，其他工具没有 |
| **Multi-scope**（staged/commit/pr/branch/project） | 比大部分 skill 灵活 |
| **Package manager 一致性检查** | 独特的供应链安全视角 |

---

## 六、改进优先级建议

### 第一梯队 — 高收益、可立即实施

| # | 改进项 | 参考来源 | 工作量 |
|---|--------|---------|--------|
| 1 | **用二次验证替代 confidence scorer** — 每个发现派独立子 agent 验证，而非 Haiku 打分 | Anthropic code-review | 中 |
| 2 | **添加 HIGH SIGNAL 过滤清单** — 明确列出不应报告的类型（linter 能抓的、已存在的、看起来像 bug 但正确的） | Anthropic code-review | 小 |
| 3 | **简化 Phase 3** — 移除 Adversarial Consensus，用 Judge 逻辑或内联处理 | Qodo 2.0 | 中 |
| 4 | **Agent 合并精简** — 8 agent → 4-5 个（Security / Quality+Perf / SOLID / Testing / Frontend(条件)） | Anthropic code-review, CodeProbe | 中 |

### 第二梯队 — 中等收益

| # | 改进项 | 参考来源 | 工作量 |
|---|--------|---------|--------|
| 5 | **支持 REVIEW.md** — 项目级审查定制 | Anthropic Managed | 中 |
| 6 | **意图提取** — Phase 1 增加 PR/commit 意图分析 | ClaudeMonetFullStack | 中 |
| 7 | **渐进加载 references** — 核心 SKILL.md 精简，checklist 按需加载 | awesome-skills | 中 |
| 8 | **测试基线** — review 前先跑项目测试套件 | ClaudeMonetFullStack | 中 |
| 9 | **修复已知 bug** — `--focus performance` 死参数、Smart Detection 优先级等 | 自身诊断 | 小 |

### 第三梯队 — 探索性

| # | 改进项 | 参考来源 | 工作量 |
|---|--------|---------|--------|
| 10 | **Git 历史回归检测** | ClaudeMonetFullStack | 大 |
| 11 | **GitHub 内联评论输出** | Anthropic code-review | 大 |
| 12 | **向 agentic 模式演进** — agent 动态决定调查深度 | BugBot V11 | 大 |

---

## 七、总结

**cr-homie 的 agent 数量和 checklist 覆盖度超过了大部分社区 skill，但在最关键的维度 — 误报过滤 — 上远落后于官方和 SOTA 工具。**

当前行业三大共识：

1. **Verification > Scoring** — 验证优于打分
2. **Dynamic > Fixed pipeline** — 动态优于固定流水线
3. **Fewer high-quality agents > Many shallow agents** — 少量高质量 agent 优于大量浅层 agent

最紧迫的改进：将 Haiku confidence scorer 替换为二次验证机制，添加 HIGH SIGNAL 过滤清单，精简 agent 数量。

---

## 八、实施进度（v3.0.0 — 2026-04-17）

> 本节记录重构执行状态，随 git 同步，用于跨设备/跨对话续接工作。

### 已完成：P0 架构改造 + 12 条 self-review 修复

提交：`c85761e Upgrade to v3.0.0, transitioning from scoring to evidence-based verification...`

**P0 架构改造：**

- 新增 `agents/_base-reviewer.md` — 公共元规则单一真相源（Iron Law / HIGH SIGNAL 9 条 / Verify Before Reporting / Severity 表 / Anti-Patterns / 输出格式）
- 新增 `agents/finding-verifier.md` — 证据验证 agent，四态判决 `CONFIRMED / DOWNGRADED / REFUTED / NEEDS-MANUAL-REVIEW`，取代 Haiku 打分器
- 合并 `api-reviewer` + `removal-reviewer` → `quality-reviewer` 子域（`QUAL-API-NNN` / `QUAL-REM-NNN`）
- Agent 数 8 → 6（security / quality / solid / testing / frontend / page-verifier）+ 1 个 verifier
- 6 个 reviewer 瘦身为 `[inherits _base-reviewer rules]` + 领域特定内容
- SKILL.md 重写 Phase 3（Collect → Dedup → Verification → Self-Check → Format → Confirm）、决策矩阵、HIGH SIGNAL 小节、Resources 表

**Self-review 12 条修复：**

1. 删除 SKILL.md `[source]` tag 断链
2. 所有 agent frontmatter 加 `tools:` 声明
3. finding-verifier SEC-P0 refute 逻辑改为"强证据允许 REFUTE，弱证据用 NEEDS-MANUAL-REVIEW"
4. page-verifier HTTP 4xx 分档（5xx=P0、公开 4xx=P1、受保护 401/403=P3）
5. 删除 verifier Recommended action 冗余
6. Verified 双来源合并格式明确
7. `file:line` → markdown link 转换由 orchestrator 做
8. Two-pass 模式下 verifier 始终收完整原始 diff
9. `_base-reviewer.md` unchanged-code 规则加 page-verifier 例外
10. HIGH SIGNAL linter-catchable 改为"仅当项目配置了对应 linter 才 drop"
11. quality-reviewer blast radius 显式阈值（5+/跨模块=P0，1-4 同模块=P1，仅测试=P2）
12. CHANGELOG.md 新增 v3.0.0 条目

### 已完成：P1 批次（2026-04-20）

5 项全部落地，未 commit 的工作区文件：`SKILL.md`、`agents/_base-reviewer.md`、`agents/agent.yaml`、`README.md`、`README.zh-CN.md`。

- [x] **Smart Detection 优先级调整** — 改为三路信号并行采集 + 分支上下文决策：`main` 分支回退到 unstaged/staged，feature 分支默认 branch diff；多信号都有内容时展示摘要让用户覆盖。消除"2 行未保存遮蔽 20 个 commit branch"陷阱。
- [x] **Project Scan 硬限制** — 新增软/硬限制表（300 文件/50k 行软警告，1k 文件/150k 行硬门槛）。硬门槛下 "Scan all" 被替换为"缩小范围 / hotspot-only / 取消"三选一，杜绝 context window 溢出。
- [x] **Project 模式 prompt 冲突** — Preflight Context Block 新增 `Scope mode: diff | project` 字段；`_base-reviewer.md` 的 "Add findings about unchanged code" anti-pattern 显式引用该字段来决定是否翻转。
- [x] **Linter 检测**（顺便修复）— Preflight 新增 Step 11 探测 ESLint / tsc / Prettier / Ruff / mypy / Flake8 / Pylint / golangci-lint / Clippy 配置；`Linters configured` 写入 Preflight Context Block。HIGH SIGNAL 规则 #1 改为引用该字段。
- [x] **agent.yaml 更新** — `short_description` 和 `default_prompt` 重写以反映 v3 证据验证 + 6 agent 并行架构。
- [x] **README.md / README.zh-CN.md 同步** — 全文重写反映 v3：架构图、workflow、参数、输出示例、组件列表、"Verification > Scoring" 说明。

### 待办：P2 批次（润色）

- [ ] 语言覆盖扩展：Rust / C++ / Swift
- [ ] Phase 1 意图提取（对标 ClaudeMonetFullStack）
- [ ] 渐进加载 references（checklist 按需加载，对标 awesome-skills）
- [ ] REVIEW.md 项目级定制支持（对标 Anthropic Managed）

### 关键决策记录（供下次对话续接）

- **Agent 合并方案**：api 和 removal 都并入 quality-reviewer 作为子域（已落地）
- **执行节奏**：分批推进，每批完成后暂停让用户 review（用户明确偏好）
- **下一步**：P1 已完成，用户可 review 当前工作区 diff 后决定是否 commit + push，或继续 P2
- **P2 注意事项**：P2 都是 nice-to-have，没有 P1/P0 的紧迫性。启动前建议先评估 cr-homie 在真实项目上的使用体验，再决定哪一项最优先
