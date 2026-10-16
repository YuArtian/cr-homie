# cr-homie v4 改进方案：先建评测，再改架构

- 状态：草案，待确认
- 负责人：xueyu.zhao（本仓库全部任务）
- 范围：cr-homie 仓库；评测用的私有用例另存（见 §3.1）
- 上一轮分析：[ANALYSIS.md](../../ANALYSIS.md)（v3 架构对标）、[CHANGELOG.md](../../CHANGELOG.md) v3.1.1（与内置 `/code-review` 的 3 MR 对比）

## 1. 背景

v3 把"打分"换成了"证据核实"，v3.1.1 收窄了触发词，把 cr-homie 定位为按需调用的重型审查。但目前有三个问题，导致它的价值说不清，也没法安全地继续改：

1. **没有评测**。唯一的一手数据是 3 个 MR：已知 bug 命中率与内置 `/code-review` 相同（各 1/4），成本约 8 倍（$8–12 / 12–17 分钟 对 $1 / 3–4 分钟）。README 和 `finding-verifier.md` 引用的"打分约 50% / 核实 60–70%"是别家产品的数字，而且把 F1 和 resolution rate 两种不同指标混在一起比。没有基线，后面任何改动都无法判断是变好还是变坏。
2. **设计意图没有执行保障**。`agents/*.md` 写了 `model: opus` 和 `tools:`，但 SKILL.md 从没说明这些 agent 怎么被启动（详见 §2 第 2 项）。ANALYSIS.md 自己列为 P0 的「纯 prompt，没有执行保障」至今没解决。
3. **和实际使用场景脱节**。实际使用者在 GitLab 上工作，还把 cr-homie 接进了无人值守的定时审查循环（发现待审 MR → 审查 → 写 digest）。但 cr-homie 只支持 `pr:<n>`（gh），输出只有给人看的 markdown，不读项目规则文件。另外，团队仓库里 vendored 的 cr-homie 拷贝已经和当前版本差了 16–22 个文件，报告里也看不出是哪个版本审的。

现在做，是因为 cr-homie 已经在真实 MR 上用起来了，审出过阻塞合并的问题，并在后续 MR 里修复。这些审查结论已经被后续修复证实或否定，是现成的、带真实标注的评测用例，越早收集越不容易丢。

## 2. 根因与改动层

cr-homie 没有运行时代码，所有改动层都是「prompt / 打包 / 评测脚本」。

| # | 问题 | 根因 | 改动层 |
| - | ---- | ---- | ------ |
| 1 | 质量无法量化 | 没有带标注的用例集，也没有可重复跑的评测框架 | 新增 `evals/` + 私有用例库 |
| 2 | `model` / `tools` / 继承规则不一定生效 | 官方文档列出的子 agent 来源只有 5 处（managed settings、`--agents`、`.claude/agents/`、`~/.claude/agents/`、plugin 的 `agents/`），**skill 目录下的 `agents/` 不在其中**（[sub-agents 文档](https://code.claude.com/docs/en/sub-agents.md)）。所以现在 frontmatter 里的 `model: opus`、`tools:` 都不生效；SKILL.md 也没写调用方式，全靠编排的模型自己领会 | 打包方式（plugin）+ SKILL.md Phase 2 |
| 3 | verifier 独立性不足 | 一个 verifier 批量核实全部发现，上下文压力大、容易被前面的结论带偏；和 reviewer 用同一模型，犯的错往往是同一类 | `finding-verifier.md` + SKILL.md Phase 3 |
| 4 | 不支持 GitLab，结果没法给机器读 | scope 只认 gh；输出只有 markdown | SKILL.md Phase 1 / Step 5 |
| 5 | 不遵守项目自己的审查规则 | Preflight 不读 CLAUDE.md / AGENTS.md / REVIEW.md | SKILL.md Phase 1 + `_base-reviewer.md` |
| 6 | 大 diff 的两轮模式省不了上下文 | 第一轮由编排者自己通读整个 diff | SKILL.md Phase 1 Step 3 |
| 7 | 版本漂移、文档过时 | 没有版本标识；`SKILL.md:6` 标题仍是 "Code Review Master"；remote 仍指向 `code-review-master`；ANALYSIS.md 写着"P1 未 commit" | 文档 / 元数据 |

## 3. 方案与取舍

总体原则：**先测量，再改动**。W0 建好评测基线之后，W1–W5 每一项都必须拿评测数据证明有效才能合并。

### 3.1 W0：评测基线（前置，阻塞其余所有工作项）

**用例来源**（目标 ≥ 30 个，真实用例 ≥ 24 个）：

| 来源 | 数量 | 标注依据 | 存放位置 |
| ---- | ---- | -------- | -------- |
| v3.1.1 对比的 3 个用例（已从 2026-10-13 的会话记录还原） | 3 | 当时的标准答案文件，已知 bug 4 个 | 本地私有 |
| 4 个内部私有仓库（后端、Web、小程序及其后端）近 6 个月的提交：从修复提交反查引入它的 MR，按维度和规模挑选 | 合计约 21 个 | 修复提交即标准答案 | 本地私有 |
| 一个被 cr-homie 审出阻塞项、后续逐项修复的真实 MR | 1 | 逐项修复记录 | 本地私有 |
| 无问题用例：合并后改动行长期没有被修过的中等 MR | 6 | 用来统计误报 | 本地私有 |
| 误报陷阱：在真实用例里额外标注「看着危险其实安全」的位置（不单独成用例，不额外花钱） | 若干 | 应被推翻、降级或不报 | 本地私有 |
| 公开陷阱用例：框架已拦截的路径遍历等，改写成脱敏的最小复现 | 3–4 | 应被推翻或降级 | 公开 |
| 合成用例：在小型示例仓库里注入已知 bug（SQL 注入、竞态、mock URL 进生产、breaking export 等） | 4–6 | 注入时即标注 | 公开 |

真实用例要覆盖这些维度：安全 / 权限、隐私（PHI 暴露）、数据写入 / 事务 / 并发、跨端接口契约、错误处理与超时、性能、前端状态与渲染、i18n、测试缺口、迁移。规模上要有小（< 200 行）、中、大（> 2000 行或 > 15 个文件，用来测两轮模式）。

**私有用例只放本地，不发布到任何地方**（公司代码保密）：

- 私有用例放在本地 cr-homie 仓库里的 `evals-private/` 目录。这个目录在 `.gitignore` 里，永远不提交、不推送；目录本身可以 `git init` 成一个没有 remote 的本地仓库，方便追踪标注改动。plugin eval 的 `--eval-dir` 只接受插件目录下的相对路径，并且文档没说支持软链接，所以不用软链接方案。
- 用例里只记录仓库路径和 sha，不拷贝代码。scaffold 时从本地克隆 `git worktree add` 出指定 sha 到 eval 的临时目录。
- **关掉 plugin eval 的默认发布**：在订阅账号下，plugin eval 默认会把 `report.html`（包含 prompt、评分规则、被评判的代码片段）发布为 claude.ai 上的私有 artifact。每次运行都必须同时加 `--no-publish` 和环境变量 `CLAUDE_CODE_DISABLE_ARTIFACT=1`，并封装进 `evals/run-private.sh`，不允许直接手敲命令。
- 结果目录 `evals-private/results/` 同样留在本地。
- 说明：评测运行时代码会发给模型 API，这和平时在这些仓库里用 Claude Code 是一样的，不算"发布"。
- 待验证：eval 子进程用的是临时配置目录，本机的会话同步工具应该不会采集到这些运行，W0.4 要确认这一点。
- **本公开方案里不出现任何内部仓库名、commit sha、MR / Jira 编号。** 具体的用例清单和标准答案只放在 `evals-private/CASES.md`。
- 2026-10-13 那次对比留下的 `GROUND_TRUTH.md` 和报告目前在 `/private/tmp` 下，随时可能被系统清理，W0.2 第一步就把它们转存到 `evals-private/`。

**每个用例记录的内容**：仓库地址、base/head sha、期望发现列表（文件、行范围、类别、最低严重级别），以及「不得报告 / 必须降级」的陷阱列表。

**指标**：

- **P0/P1 召回率**（主指标）：标注中的 P0/P1 问题被报出来的比例。
- **精确率**：报出的发现中真实成立的比例。没有标注的发现由 LLM 判定是否与标注吻合，再由人工抽检 20%。
- **陷阱通过率**：陷阱用例被正确推翻或降级的比例。
- **单次成本与耗时**：取会话的 token 计费与墙钟时间。
- **verifier 判定分布**：CONFIRMED / DOWNGRADED / REFUTED / NEEDS-MANUAL-REVIEW 各占多少。

每个用例跑 3 次，报告均值和波动。

**对照组**：内置 `/code-review high`（同一批用例、同一模型）。

**评测框架：`claude plugin eval`**（[文档](https://code.claude.com/docs/en/plugin-evals)，要求 Claude Code ≥ v2.1.269）。选它而不是自己写 `claude -p` 脚本，是因为它已经提供了需要的全部能力：

| 需要的能力 | plugin eval 怎么提供 |
| ---------- | -------------------- |
| 在指定 sha 上审查 | `case.yaml` 的 `context.scaffold_script` 检出用例仓库（需加 `--scaffold`，限时 120 秒） |
| 按标注判定是否报出 | 每条期望发现一个 `llm` grader（三次投票取两票），目标指向 cr-homie 写出的 JSON 文件（`{source: file, path}`） |
| 陷阱用例 | `llm` grader：「该位置的发现不存在，或被标为 REFUTED / DOWNGRADED」 |
| 重复跑 | `runs: 3` |
| 成本和耗时 | `--json` 结果里有 `costUsd`、`durationSeconds`、`claudeVersion` |
| 防止超支 | `--max-cost-usd` |

用例格式：`evals/<case>/prompt.md`（正文是 `/cr-homie branch:... --format json --out review.json`；frontmatter 里 `max_turns` 设到 200，`timeout_seconds` 设到 1800，因为实测单次 12–17 分钟，默认的 10 轮 / 300 秒远远不够）+ `evals/<case>/graders/*.md` + `case.yaml`。

几处需要注意：

- **对照组要单独设一组用例**。plugin eval 默认的对照组是"不装插件"，但 cr-homie 只在被点名时触发，同一句 prompt 在不装插件的那一组里跑不起来，所以两组都用 `--ablation none`：cr-homie 一组，`/code-review high` 一组（prompt 不同、grader 相同）。这样还能省下默认对照组的一半成本。
- **精确率 plugin eval 算不了**。grader 只判断通过 / 不通过，算不出"报出的发现里有多少成立"。需要另写一个小脚本，读每次运行产出的 `review.json`，用 LLM 判断每条发现是否与标注吻合，再由人工抽检。运行产物是否会保留、保留在哪里，文档没写，W0.4 先确认；不保留的话，就让 prompt 把结果写到 `EVAL_*` 环境变量指定的目录。
- **私有用例怎么接入**：用 `--eval-dir evals-private` 指向插件目录下被 gitignore 的目录，见上文。
- **scaffold 限时 120 秒**：私有仓库不现场克隆，而是从本地克隆 `git worktree add` 出指定 sha。
- **运行产物**：`results/<时间戳>/aggregate-result.json` 会保留，里面有每条 grader 的结论和证据；每次运行的沙箱默认会被删掉，要加 `--keep-temp` 才保留（精确率脚本需要读 `review.json`，所以要加）。

**配套改动：结构化输出**。评分需要机器可读的发现列表，所以 W0 包含给 cr-homie 加 `--format json`（`--out <path>` 指定写到哪里）。JSON 字段与现有 markdown 一一对应：id、file、line、severity、title、risk、fix、verified、verifier_outcome。W3 的 digest 循环也会复用这个格式。

**配套改动：最小 plugin manifest**。plugin eval 要求被测目录是一个带 manifest 的 plugin，所以 W0 要先加 `.claude-plugin/plugin.json`。这一步只加 manifest，不动其他结构；它本身也会让 `agents/` 被注册，所以要和 W1 的第一步合并做，见 §3.2。

**成本预估**（依据 2026-10-13 三次 cr-homie 运行的实测 token，按 Opus 5.5 标价折算：输入 $4 / 输出 $20 / 1 小时缓存写入 $8 / 缓存读取 $0.20，单位都是每百万 token）：

| 实测 | 缓存读取 | 缓存写入 | 输出 | 合计 token | 折算 | 耗时 |
| ---- | -------- | -------- | ---- | ---------- | ---- | ---- |
| 用例 A | 15.6M | 0.76M | 24k | 16.4M | $9.7 | 12 分钟 |
| 用例 B | 20.3M | 0.87M | 43k | 21.2M | $11.9 | 17 分钟 |
| 用例 C | 12.1M | 0.63M | 28k | 12.7M | $8.0 | 14 分钟 |

单次 cr-homie 平均约 **1700 万 token、$10**，其中 95% 是缓存读取：6 个子 agent 加编排者每一轮工具调用，都要把各自的上下文从缓存里重新读一遍。

| 运行 | 次数 | token | 标价折算 |
| ---- | ---- | ----- | -------- |
| 完整一轮：cr-homie，30 用例 × 3 次 | 90 | ≈ 15 亿 | ≈ $900 |
| 完整一轮：`/code-review high` 对照组（单次按 cr-homie 的 1/8 估） | 90 | ≈ 2 亿 | ≈ $110 |
| 冒烟一轮：6 用例 × 1 次，只跑 cr-homie | 6 | ≈ 1 亿 | ≈ $60 |

账号是 Team 订阅（`claude_team`），所以上面的美元只是标价折算，实际消耗的是订阅额度，不直接付费。完整一轮约 17 亿 token，很可能超出单个 5 小时窗口的额度，所以：

- 冒烟一轮在订阅额度内跑；
- 完整一轮拆到 2–3 天，按仓库分批跑，每批之前先用 `/usage` 看剩余额度。

如果额度不够，或者不希望占用日常开发的额度，另一个选择是用 API key 计费跑完整一轮，约 $1000。API key 认证本身也不会触发发布。

每次运行都设 `--max-cost-usd`（按标价折算计）作为上限。

### 3.2 W1：让 agent 真正被注册、被调用

**已核实的事实**（来自 Claude Code 官方文档，2026-10-16）：

- plugin 根目录下 `agents/<file>.md` 注册为 `<plugin>:<name>`，frontmatter 的 `model`、`tools`、`effort`、`maxTurns` 等都生效（[components 文档](https://code.claude.com/docs/en/plugins/components.md)）。
- 没有 `skills/` 目录时，**根目录的 SKILL.md 算作这个 plugin 唯一的 skill**，前提是 frontmatter 写了 `name`（cr-homie 已经写了）。
- 通用子 agent 调用时可以按次传 `model`，优先级最高。
- `npx skills add` 先找根目录的 SKILL.md，同时也会读 `.claude-plugin/` 下的 manifest。两者同时存在时它怎么处理，README 没写，需要实测。

**方案**：**不搬目录**，在现有结构上加 manifest。现在的「根目录 SKILL.md + `agents/`」本身就是合法的 plugin 结构。

1. 新增 `.claude-plugin/plugin.json`（含 `version`）和 `.claude-plugin/marketplace.json`（`source: "."`），安装方式变成：

   ```bash
   /plugin marketplace add YuArtian/cr-homie
   /plugin install cr-homie@cr-homie
   ```

2. 把 `agents/_base-reviewer.md` 移到 `references/base-reviewer-rules.md`。否则它会被注册成一个可调用的 agent，但它不是 agent。
3. 公共规则改为由编排者在启动每个 reviewer 时显式放进 prompt（与 Preflight Context Block 放在一起），各 agent 正文里的 `[inherits _base-reviewer rules]` 改成"公共规则已随 prompt 提供"。这样 plugin 和纯 skill 两条路径的行为一致。
4. SKILL.md Phase 2 写清楚怎么调用：
   - **plugin 安装**：用 `subagent_type: "cr-homie:<agent>"` 启动，模型和工具由 frontmatter 决定。
   - **纯 skill 安装**（`npx skills add`、vendored 拷贝、其他宿主）：读取 `agents/<agent>.md`，加上公共规则，用通用子 agent 启动，并按 frontmatter 显式传入 `model`。
   - 编排者先看 `cr-homie:security-reviewer` 是否可用，再决定走哪条路径，并在报告的 `Agents launched` 里写明。
5. 「skill 指示主 agent 按名字调用 plugin agent」在文档里没有明确保证（只是从 skill 正文运行在主上下文里推断出来的），所以 W1 验收必须实测：用 `/agents` 确认已注册，并在会话记录里确认 `subagent_type` 和模型确实是预期值。

**放弃的方案**：

- 只改 SKILL.md、不打 plugin 包：仍然完全依赖模型自觉，正是要解决的问题本身。
- 改成标准的 `skills/cr-homie/SKILL.md` 结构：会挪动所有路径，`npx skills add` 和已有的 vendored 拷贝都要跟着调整，没有收益。
- 用一个构建步骤把公共规则拼进每个 agent 文件：会多出一份生成文件，又回到规则在多个文件之间漂移的老问题。

**和 W0 的关系**：第 1 步（manifest）是 W0 评测的前提；而第 1 步一做，`agents/` 就会被注册，所以第 2 步（移走 `_base-reviewer.md`）必须一起做，否则会多出一个错误的 agent。因此第 1、2 步并入 W0（W0.0），第 3–5 步留在 W1。基线评测跑的是「v3.1.1 的 prompt + 能被注册的 agent」，和现状有一点差别，基线报告里要写明。不再单独跑一组纯 v3.1.1 对照（2026-10-16 确认）：W0.0 只让 agent 能被注册，不改审查逻辑，这点差别不影响关口决策。

### 3.3 W2：提高 verifier 的独立性

在评测上做 A/B，用数据决定：

- **A（现状）**：一个 verifier 批量核实全部发现。
- **B**：按领域分组，每组一个 verifier 并行核实（安全一组、其余按 agent 分组）。
- **C**：每条 P0/P1 发现单独一个 verifier，P2/P3 批量核实。

另外加一个变量：verifier 用的模型与 reviewer 不同（例如 reviewer 用 opus，verifier 用 sonnet，或反过来）。

**选择标准**：精确率提升，P0/P1 召回率不下降，单次成本增幅 ≤ 30%。都达不到就保留 A。

### 3.4 W3：GitLab 支持与输出模式

- 新增 scope `mr:<iid>`：用 `glab mr diff`，并检出 MR 的 head 供 verifier 读取上下文。没装 glab 时给出安装提示，与 `pr:` 的处理一致。
- 新增 `--post`：在用户确认后用 `glab mr note` / `gh pr comment` 把结论发到 MR。**默认不发**，先展示、确认后才发，与现有 Step 6 的确认关口一致。
- 报告头部写上 cr-homie 版本号（读 `plugin.json` / SKILL.md frontmatter 的 `version`），方便 digest 循环和多份拷贝追溯是哪个版本审的。
- `--format json` 已在 W0 完成，这里只做 digest 循环的对接说明。

### 3.5 W4：读取项目审查规则

Preflight 读取仓库根目录与改动所在目录的 `REVIEW.md`、`CLAUDE.md`、`AGENTS.md`，抽出与审查相关的规则（例如"兼容降级必须写移除计划""跨端接口必须读后端代码确认"），作为 `Project rules` 字段放进 Preflight Context Block。违反项目规则的发现在 `Verified` 里引用规则出处。

**放弃的方案**：把整份 CLAUDE.md 原样塞给每个 agent，太占上下文，也会混进与审查无关的流程规则。

### 3.6 W5：大 diff 改为由 agent 按需拉取

第一轮不再由编排者通读 diff，改为：编排者只看 `--stat` 和改动文件路径，按关键路径（auth / 支付 / 数据写入 / 迁移 / 公开 API）和改动规模排出热点；各 reviewer 拿到的是「获取 diff 的命令 + 热点列表」，自己按需拉取。

是否合并取决于评测：在 ≥ 3 个大 diff 用例上，召回率不下降、编排者上下文明显缩小，才合并。

### 3.7 W6：清理过时内容（无需评测，可随时做）

- `SKILL.md:6` 标题改为 "CR Homie"；frontmatter 增加 `version`。
- git remote 改为 `YuArtian/cr-homie`（需要在 GitHub 上确认仓库已改名，旧名会自动重定向）。
- ANALYSIS.md 第八节更新实施状态。README 中别家产品的数字注明出处，并改成「各产品自报指标，口径不同，不可直接比较」。
- 用 Conventional Commits 写提交信息。

### 3.8 决策关口

指标定义：

- **召回率** = 报出的已知真 bug 数 ÷ 标注的已知真 bug 总数。衡量"漏没漏"。2026-10-13 的对比中有 4 个已知 bug，两边各找到 1 个，召回率都是 25%。
- **精确率** = 报出的发现里真实成立的条数 ÷ 报出的总条数。衡量"报得准不准"。

W0 基线出来后，如果 cr-homie 相对 `/code-review high` 的 **P0/P1 召回率领先不到 15 个百分点**，同时精确率也不领先，就说明 8 倍成本换不来对应收益。

为什么是 15 个百分点：按 30 个用例、约 40 个已标注的 P0/P1 bug 估算，每个 bug 约占 2.5 个百分点。同一个工具重复跑 3 次，召回率本身就会有约 ±5–8 个百分点的波动，15 个百分点（约多找出 6 个 bug）才明显超出波动。这个阈值等基线出来、看到实际波动后再复核。这种情况下不继续做 W1–W5 的编排改造，而是调整方向：把 cr-homie 里经过验证有效的规则（攻击链追溯、生产可达判定、只报高价值问题的过滤、严重级别校准）沉淀成可以挂在内置审查上的 `REVIEW.md` 规则集，停止维护多 agent 编排。

## 4. 任务拆分

每个工作项 = 一个分支 = 一个 MR（PR），分支名与工作项对应。本文档所在的 `chore/v4-improvement-plan` 只提交方案本身。

| # | 任务 | 分支 | 依赖 | 能否并行 | 验证方式 |
| - | ---- | ---- | ---- | -------- | -------- |
| W0.0 | 加 `plugin.json` + `marketplace.json`；`_base-reviewer.md` 移到 `references/`（§3.2 第 1、2 步） | `feat/eval-harness` | — | 否（最先做） | `claude --plugin-dir .` 下 `/agents` 能看到 6 个 reviewer 和 verifier，且没有 `_base-reviewer`；`npx skills add` 到临时目录仍然能装上 |
| W0.1 | 用例格式定义 + 公开合成用例 4–6 个 + 陷阱用例 3–4 个 | `feat/eval-harness` | W0.0 | 可与 W0.2 并行 | `claude plugin eval . --dry-run` 或冒烟跑能加载 |
| W0.2 | 转存 2026-10-13 的标准答案；从 3 个仓库挑选并标注私有真实用例 ≥ 24 个（本地 `evals-private/`） | 本地，不提交 | — | 可与 W0.1 并行 | 每个用例有 sha 和标注，你逐个确认标注；`git check-ignore evals-private` 通过 |
| W0.3 | `--format json` 输出 | `feat/eval-harness` | — | 与 W0.1 同分支串行 | 在 1 个用例上产出合法 JSON |
| W0.4 | `claude plugin eval` 接入：grader、私有用例软链接、精确率脚本；验证运行产物保留方式 | `feat/eval-harness` | W0.1、W0.3 | 否 | 冒烟子集能跑通，输出召回率、陷阱通过率、精确率、成本 |
| W0.5 | 跑基线：cr-homie v3.1.1 vs `/code-review high`，完整一轮 | — | W0.2、W0.4 | 否 | 基线报告写入 `evals/reports/` |
| 关口 | 按 §3.8 决定是否继续 | — | W0.5 | — | 你确认 |
| W1 | 公共规则显式传入 + Phase 2 双路径调用（§3.2 第 3–5 步） | `refactor/explicit-agent-dispatch` | 关口 | 否（改动所有 agent 文件，必须先于 W2–W4 合并） | 冒烟子集不退化；plugin 和纯 skill 两种安装各跑一次，会话记录里 `subagent_type` 和模型符合预期 |
| W2 | verifier A/B/C 实验，选优合并 | `feat/verifier-independence` | W1 | 与 W3、W4 开发可并行，合并须串行 | 完整一轮，满足 §3.3 标准 |
| W3 | `mr:<iid>` + `--post` + 版本号 | `feat/gitlab-mr` | W1 | 同上 | 在 1 个 GitLab 测试 MR 上跑通 scope 和发帖 |
| W4 | 读取项目规则 | `feat/project-rules` | W1 | 同上 | 构造违反 REVIEW.md 规则的用例，能报出并引用规则 |
| W5 | 大 diff 按需拉取 | `feat/agentic-large-diff` | W2 | 否 | 大 diff 用例 ≥ 3 个，满足 §3.6 标准 |
| W6 | 清理过时内容 | `chore/docs-hygiene` | — | 随时可做 | 人工检查 |

W2、W3、W4 都要改 SKILL.md，所以开发可以并行，但合并要串行：按 W3 → W4 → W2 的顺序合并，后合并的先 rebase。W3、W4 改动小，先合并能减少冲突。

## 5. 验收标准与验证方法

- **W0**：基线报告包含 §3.1 的全部指标，cr-homie 与对照组各跑 3 次；报告中的数字可以用一条命令复现。
- **W1–W5**：各自满足 §4 表中的验证方式；需要跑评测的项，评测报告附在 MR 描述里。
- **整体**：v4 发版时 README 用自己的评测数据替换别家的引用数字，并写明用例数、跑了几次、对照组是什么。

## 6. 风险与回滚

| 风险 | 应对 |
| ---- | ---- |
| 评测成本超预期 | 日常迭代只跑冒烟子集；完整一轮只在关口和各工作项合并前跑；每次运行都设 `--max-cost-usd` |
| plugin eval 的限制（scaffold 120 秒、默认 10 轮 / 300 秒、运行产物是否保留未知） | 用本地镜像加 `git worktree` 做 scaffold；用例里显式调高 `max_turns` / `timeout_seconds`；产物保留方式在 W0.4 先验证，不满足就让 prompt 写到 `EVAL_*` 指定的目录 |
| 加 manifest 后 `npx skills add` 的行为变化（README 没写两种 manifest 同时存在时怎么处理） | W0.0 验收时实测 `npx skills add` 安装到临时目录 |
| 真实用例标注有偏差（例如修复提交不等于审查时就该发现的问题） | 每个真实用例由你确认标注；LLM 判定的匹配结果人工抽检 20% |
| 私有代码泄漏到开源仓库或外部 | 私有用例只在本地被 gitignore 的 `evals-private/`；用例里只存路径和 sha，不存代码；只能通过 `run-private.sh` 运行（强制 `--no-publish` + `CLAUDE_CODE_DISABLE_ARTIFACT=1`）；每次提交前检查 diff 里没有内部仓库名、路径、sha 或代码片段 |
| 评测占满订阅额度、影响日常开发 | 完整一轮分 2–3 天分批跑；每批前先看 `/usage`；必要时改用 API key 计费 |
| plugin 改造破坏现有安装方式（`npx skills add`、vendored 拷贝） | 保留根目录可直接用的 SKILL.md 和兼容路径；W1 验收要求两种安装方式都测过 |
| LLM 输出波动导致 A/B 结论不可靠 | 每个用例跑 3 次；差异小于波动范围时视为无差异，保留现状 |

**回滚**：每个工作项是独立 MR，回滚就是 revert 对应的合并提交；用户可以按 tag 固定在 v3.1.1。评测框架和用例与 skill 本体解耦，不影响已安装的使用者。

## 7. 决策记录

2026-10-16 确认：

- v3.1.1 那 3 个用例已从会话记录还原，见 §3.1。新用例从多个内部仓库按维度挑选。
- 公司代码不发布到任何地方：私有用例只放本地，见 §3.1。
- 不跑纯 v3.1.1 对照组。
- 用例清单已认可：31 个用例（25 个有已知 bug，6 个无问题），约 40 个已标注 bug。清单与标准答案只存本地 `~/cr-homie-evals-private/`（不在任何 git 仓库里）；W0 把 `evals-private/` 加进 `.gitignore` 后再挪进插件目录。
- 完整一轮用订阅额度，按仓库分 2–3 天分批跑，每批前先看 `/usage`。

待确认：

1. 召回率领先 15 个百分点的阈值，等基线出来、看到实际波动后再复核。

## 8. 实际结果

（实施完成后补充）
