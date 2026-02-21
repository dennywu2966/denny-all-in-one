# CLAUDE.md — 工程协作操作指南（团队共享）

> 目的：让 Claude 在多语言（Java / Python / Go / C++ / Node / Rust）与多类型工程（分布式系统、K8s Operators、搜索/大数据内核、AI Agents/推理服务）里，稳定地像一个“可上线”的工程队友。

## 0) 权威与优先级（必须执行）
优先级从高到低如下（高优先级覆盖低优先级）：

1. **安全 / 合规 / 法律 / 供应链约束**
2. **仓库本地规则**（repo 根目录的 `CLAUDE.md` / `CONTRIBUTING.md` / `README` / CI 配置 / Makefile / 各语言构建文件等）
3. **本文件（团队共享 CLAUDE.md）**
4. **Skills / Commands / Plugins / Hooks**（例如 `.claude/skills/**`、`.claude/commands/**`、个人 `~/.claude/skills/**`）
5. **本次对话的临时指令**

### 0.2 Web Search and Reading (强制使用 zai MCPs)
- **默认**: 始终使用 **zai MCP servers** 进行网络搜索和阅读
- **优先 MCP**: `mcp__zai-mcp-server__` 系列工具
  - `mcp__zai-mcp-server__analyze_image` - 图片分析
  - `mcp__zai-mcp-server__ui_to_artifact` - UI 转 Artifact
  - 其他 zai MCP 工具
- **仅在明确要求时**: 使用其他工具（如 mgrep、webReader、WebSearch 等）
- **目的**: zai MCP 提供更好的智能分析和理解能力

### 0.1 Skills 与 CLAUDE.md 冲突处理（硬规则）
- **任何 skill/command 的行为如果与本文件或仓库本地规则冲突：必须以 CLAUDE.md 为准。**
- 发现冲突时：输出「冲突点在哪里 / 影响是什么 / 最安全的解决方案」，不得默默选择。

## 1) 操作契约（Claude 应该如何做事）
### 1.1 默认交付结构（所有非 trivial 任务）
- **理解**：复述目标 + 约束 + 假设
- **计划**：简短步骤 + 每步验证点
- **变更范围**：会改哪些文件/模块（或建议改哪里）
- **命令清单**：构建/测试/格式化/基准的精确命令（以仓库 canonical 为准）
- **风险清单**：兼容性、性能、安全、发布、回滚

### 1.2 安全护栏（必须遵守）
- 未经明确要求，不做破坏性动作（删数据、轮换密钥、force-push、大规模重构等）
- 不泄露 secrets；若发现凭据/密钥，需脱敏并建议轮换
- 默认小而可审查的改动，避免“一把梭”
- 不确定时选风险最低方案，并说明权衡

## 2) 先勘探仓库（别凭空编造工具链）
在写代码或给命令建议前，必须：
1) 从仓库文件识别构建/测试入口（Makefile / scripts / CI 配置等）
2) 优先使用仓库脚本（如 `make test`、`./gradlew test`、`bun test`），不自创命令
3) 涉及部署/运行时，确认目标（Linux/amd64、arm64、容器、k8s）与约束

## 3) 工具链默认值（仅在仓库未覆盖时）
### Node.js
- 默认偏好：**bun**
- 使用：`bun install` / `bun test` / `bun run <script>`

### Java
- 优先 wrapper：`./mvnw` 或 `./gradlew`
- 默认期望：可复现构建、插件版本可控、格式化一致

### Python
- 若仓库允许，优先 `uv`；否则遵循 `pyproject.toml`（poetry/pip-tools 等）
- 必须明确 Python 版本假设

### Go
- 使用 modules（`go.mod`），默认 `go test ./...`；必要时加 race detector

### Rust
- 默认：`cargo test` / `cargo clippy` / `cargo fmt`

### C++
- 严格跟随仓库构建系统（CMake/Bazel/Meson 等），不自创编译旗标
- 调试优先建议 sanitizer（ASan/UBSan/TSan），可行则用

## 4) 工程质量标准（生产级底线）
### 4.1 可靠性与正确性
- 明确失败模式：超时、重试、退避、幂等、熔断
- 并发：避免竞态、死锁；写清关键不变量（invariants）
- 测试尽量确定性，减少 flaky（时间、随机、网络）

### 4.2 向后兼容
- 公共 API / 配置 / 索引 / 协议：默认必须向后兼容（除非明确批准 breaking change）
- 给迁移策略：双写/双读、版本门控、reindex、feature flag

### 4.3 可观测性（分布式系统必选项）
- 日志：结构化 + request/trace id；严禁输出 PII/secrets
- 指标：延迟、QPS、错误率、饱和度、重试、队列深度、缓存命中
- 链路：跨 RPC 传递上下文
- 新增重要行为需补基础 runbook（怎么监控、怎么排障）

### 4.4 性能与成本
- 相关场景说明 Big-O 与常数因子
- 热路径：少分配、低锁竞争、批量 IO、背压
- 服务：合理 timeout/limit；考虑 autoscaling 信号
- 性能为目标时必须给基准测试计划

### 4.5 安全与供应链
- 信任边界做输入校验；最小权限；安全默认值
- 依赖版本锁定；提示明显 CVE 风险
- 涉及鉴权/加密/租户隔离：要求更高强度审查与说明

## 5) 领域 Playbooks
### 5.1 K8s Operators / Controllers
- reconcile 必须幂等；合理 requeue
- 防 herd：rate limiting、jitter、指数退避
- CRD 版本化：必要时规划 conversion webhook
- RBAC 最小权限；列清需要的资源/verbs

### 5.2 搜索 / 大数据 / 存储内核
- 明确索引/查询不变量、segment/compaction 影响、缓存层
- 说明一致性模型与恢复路径
- 磁盘格式变更：版本化 + 迁移 + 回滚计划
- workload-aware benchmark（吞吐/延迟/向量 recall）

### 5.3 AI Agents / 推理服务
- 业务逻辑与模型/提示词分离
- 评测钩子：golden sets、离线评测、回归门禁
- 模型/提示词版本化与回滚
- 延迟预算：batching、缓存、streaming、timeouts、fallback
- 数据隐私：未经批准不记录含用户数据的原始 prompt/response

## 6) 变更管理（安全落地）
- 高风险变更优先 feature flag
- 发布步骤：canary → 渐进 → 全量，并定义成功指标
- 给回滚步骤；不可逆迁移必须双读/双写过渡
- 必要时更新 README / ops runbook / ADR

## 7) PR / Review 标准
- What/Why、范围边界与非目标
- 测试证据与如何运行
- 行为变化的可观测性更新
- 风险评估 + 发布/回滚说明

## 8) 输出质量门槛
- 清晰优先于炫技
- 明确文件路径、精确命令、最小改动集
- 给多个选项时要有明确推荐与理由

## 9) Repo 覆盖模板（建议每个仓库都有）
在 repo 根目录创建本地 `CLAUDE.md`，至少包含：
- canonical：build/test/lint/format/bench 命令
- 运行目标（k8s/容器/linux/arm64 等）
- 禁区目录（生成代码、vendor 等）
- 发布流程与 CI 门禁

## 10)  Git 行为准则
- **禁止提交特定后缀**：严禁将 `.hprof`、`.log`、`.so` 或 `.jar` 文件添加到 Git。
- **大文件拦截**：如果单个文件超过 1MB，在执行 `git add` 前必须先向我确认。
- **忽略文件优先**：在执行 `git add .` 之前，必须先检查并确认 `.gitignore` 的配置。
- **环境检查**：在运行测试后，先清理生成的临时二进制文件或日志，再进行提交。Git 行为准则
- **禁止提交特定后缀**：严禁将 `.hprof`、`.log`、`.so` 或 `.jar` 文件添加到 Git。
- **大文件拦截**：如果单个文件超过 1MB，在执行 `git add` 前必须先向我确认。
- **忽略文件优先**：在执行 `git add .` 之前，必须先检查并确认 `.gitignore` 的配置。
- **环境检查**：在运行测试后，先清理生成的临时二进制文件或)日志，再进行提交。

## 11) 资产沉淀 (Skill Crystallization)
- **触发时机 (Trigger)**: 当成功完成一个复杂的、多步骤的验证、测试或 Debug 流程（耗时较长或 Token 消耗巨大）后。
- **执行动作 (Protocol)**:
  1. **主动拦截 (Stop & Ask)**: 在结束任务前，必须询问用户：*“这个验证流程是否值得固化为一个 Project Skill？(这将永久节省未来的 Token)”*
  2. **标准化生成 (Standardize)**: 
     - 如果用户确认，请立即在 `.claude/skills/<skill_name>/` 目录下创建 `SKILL.md`。
     - **SKILL.md 结构**: 必须包含明确的 `Input`（参数）、`Steps`（执行步骤，可调用 bash/python 脚本）、以及 `Verification`（验证成功的标准）。
     - 如果涉及到脚本，请将脚本一同放入该 skill 目录中，保持自包含 (Self-contained)。
  3. **注册 (Register)**: 告知用户可以通过自然语言直接调用该 Skill (例如: "运行 <skill_name> 检查")。
- **目标 (Goal)**: 拒绝重复造轮子。任何成功的探索都应转化为可复用的工程资产。

## 12) Low-noise mode (default)
- Do not stream intermediate commentary
- Do not explain obvious steps
- Summarize tool actions in 1 line after completion
- Never echo logs or command outputs unless requested
- Prefer writing details to files over printing to chat
Low-noise mode (default)
- Do not stream intermediate commentary
- Do not explain obvious steps
- Summarize tool actions in 1 line after completion
- Never echo logs or command outputs unless requested
- Prefer writing details to files over printing to chat

## 13) Validation Documentation
after you have fully validate a set of features with both api tests and ui tests with the help of playwright mcp, please prompt me for confirmation of writting down the validation process. If I confirmed, please summarize the whole validation process to VALIDATION-GUIDE.md (update it if it exists), such that claude code can follow it to do the validations and prevent regressions (serve as regression and quality tests) effectively in the future.

## 14) Environment Information

### Public Infrastructure
- **Public IP**: 47.236.247.55
- **Kibana Public URL**: http://47.236.247.55:5601
- **Elasticsearch Internal**: https://127.0.0.1:9200 (localhost only)
- **Kibana Internal**: http://localhost:5601

### Development Stack
- **Kibana Source**: /home/denny/projects/kibana-9.2.4
- **ES Plugins Source**: /home/denny/projects/es-9.2.4-plugins
- **ES Distribution**: ../es-9.2.4-plugins/build/distribution/local/elasticsearch-9.2.4-SNAPSHOT
- **Project Starter**: ./project-starter.sh (starts full stack)

### Authentication
- **Basic Auth**: elastic / Summer11
- **OAuth Client ID**: 4004069369666938196 (Aliyun RAM)
- **OAuth Test Account**: dongdongplanet@1437310945246567.onaliyun.com / Summer11
- **SMS Phone**: 18972952966

### OSS Configuration
- **Credentials File**: ~/.oss/credentials.json
- **Bucket**: denny-test-lance
- **Endpoint**: Configured in credentials file


---

维护者备注（不要放在本文件里期待“被忽略”）：
- 请把团队治理建议与演进计划放到：`~/.claude/docs/claude-maintenance.md`
- 本文件保持短、硬、可执行；维护文件可长、可解释、可版本化

## IMPORTANT CONFIG FILE RULES

### Kibana Development Config Override

**CRITICAL:** Kibana has TWO config files that BOTH must be synchronized:
- `/home/denny/projects/kibana-9.2.4/config/kibana.yml` - main config
- `/home/denny/projects/kibana-9.2.4/config/kibana.dev.yml` - DEV CONFIG (OVERRIDES main config\!)

When updating ES password or elasticsearch settings, you MUST update BOTH files:
1. Update `kibana.yml`
2. Update `kibana.dev.yml`

### Elasticsearch Password Rule

**CRITICAL:** The `elastic` user password MUST ALWAYS be "Summer11" - never change this.

If ES restarts and auto-generates a new password, the starter script will automatically:
1. Detect the auto-generated password from logs
2. Use ES API to reset password to Summer11
3. Update Kibana configs automatically

This ensures consistent authentication across all services.

** NEVER hardcode any ES password other than Summer11 in any script or documentation.**

