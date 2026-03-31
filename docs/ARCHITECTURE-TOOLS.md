# Claude Code 工具系统架构分析

> 源码路径: `/src/tools/`
> 总计 **43 个工具目录** + 2 个辅助目录 (`shared/`, `testing/`)

---

## 1. 工具系统基础架构

### 1.1 `buildTool()` — 工具构建模式

所有工具通过 `buildTool()` 函数（定义在 `src/Tool.ts`）构建。这是一个工厂函数，接收 `ToolDef` 部分定义，自动填充安全默认值：

```ts
// Tool.ts 中的 TOOL_DEFAULTS
{
  isEnabled: () => true,
  isConcurrencySafe: (_input?: unknown) => false,  // 默认不安全
  isReadOnly: (_input?: unknown) => false,          // 默认可写
  isDestructive: (_input?: unknown) => false,
  checkPermissions: () => ({ behavior: 'allow' }),  // 默认允许
  toAutoClassifierInput: () => '',                   // 默认跳过分类器
  userFacingName: () => def.name,
}
```

### 1.2 标准工具结构

每个工具目录通常包含：

| 文件 | 用途 |
|------|------|
| `*Tool.ts(x)` | 主工具定义（调用 `buildTool()`） |
| `prompt.ts` | 工具描述、系统提示文本、Schema 导出名 |
| `constants.ts` | 工具名常量、错误消息常量 |
| `UI.tsx` | React 渲染组件（tool use 消息、结果、错误、进度） |
| `types.ts` | Zod Schema 定义（input/output 类型） |
| `utils.ts` | 辅助函数 |

### 1.3 权限模型（Permission System）

#### PermissionResult / PermissionDecision

```ts
// 权限行为：'allow' | 'ask' | 'deny' | 'passthrough'
type PermissionResult = {
  behavior: 'allow'   // 自动放行
  updatedInput?: any   // 可修改 input
} | {
  behavior: 'ask'     // 询问用户
  message?: string
} | {
  behavior: 'deny'    // 直接拒绝
  message: string
} | {
  behavior: 'passthrough'  // 交给下一层处理
  message?: string
}
```

#### 权限模式（PermissionMode）

五种外部模式 + 两种内部模式：

| 模式 | 行为 |
|------|------|
| `default` | 每次操作都询问 |
| `acceptEdits` | 文件系统操作自动放行（mkdir/touch/rm/mv/cp/sed） |
| `bypassPermissions` | 全部自动放行 |
| `dontAsk` | 不询问，直接执行 |
| `plan` | 需要计划审批 |
| `auto` | 内部模式，transcript classifier 驱动 |
| `bubble` | 内部模式 |

#### 多层权限检查链

每个工具的 `checkPermissions()` 是工具级检查，之后还有：
1. **Mode validation** (`modeValidation.ts`) — 基于当前模式
2. **Path validation** (`pathValidation.ts`) — 路径约束
3. **Read-only validation** (`readOnlyValidation.ts`) — 只读约束
4. **Sed validation** (`sedValidation.ts`) — sed 编辑约束
5. **Security checks** (`bashSecurity.ts`) — 命令安全分析
6. **Sandbox** (`shouldUseSandbox.ts`) — 沙箱执行判定

---

## 2. 核心工具详细分析

### 2.1 BashTool ⭐

**文件**: `BashTool/BashTool.tsx` (~160KB, 最大工具)
**名称**: `Bash`
**用途**: 执行 bash shell 命令

#### 内部结构（21 个文件）

| 文件 | 行数 | 用途 |
|------|------|------|
| `BashTool.tsx` | ~3600 | 主工具定义、命令分类、执行逻辑 |
| `bashPermissions.ts` | ~2600 | 权限规则匹配、通配符、前缀规则 |
| `bashSecurity.ts` | ~2800 | 安全分析：命令替换检测、危险模式、AST 解析 |
| `readOnlyValidation.ts` | ~1900 | 只读命令验证（git/rg/fd 等安全标志） |
| `pathValidation.ts` | ~1200 | 路径约束检查 |
| `sedValidation.ts` | ~600 | sed 编辑命令安全验证 |
| `prompt.ts` | ~500 | 系统提示：git 操作指引、沙箱说明、sleep 规范 |
| `UI.tsx` | ~700 | React 渲染：命令输出、搜索结果折叠 |
| `bashCommandHelpers.ts` | ~250 | 命令操作符权限检查 |
| `commandSemantics.ts` | ~100 | 命令结果语义解释 |
| `destructiveCommandWarning.ts` | ~80 | 破坏性命令警告 |
| `modeValidation.ts` | ~170 | 模式级权限（acceptEdits 自动放行 fs 命令） |
| `shouldUseSandbox.ts` | ~150 | 沙箱使用判定 |
| `sedEditParser.ts` | ~280 | sed 编辑命令解析为 FileEditTool 格式 |
| `commentLabel.ts` | ~20 | 注释标签提取 |
| `toolName.ts` | ~3 | 工具名常量 |
| `utils.ts` | ~200 | 图像输出处理、路径重置等 |

#### Input Schema

```ts
{
  command: string                    // 要执行的命令
  timeout?: number                   // 可选超时 (ms, max 600000)
  description?: string               // 命令描述（活跃语态）
  run_in_background?: boolean        // 后台运行
  dangerouslyDisableSandbox?: boolean // 禁用沙箱
  _simulatedSedEdit?: {              // 内部字段，模型不可见
    filePath: string
    newString: string
  }
}
```

#### Output Schema

```ts
{
  stdout: string                     // 标准输出
  stderr: string                     // 标准错误
  interrupted: boolean               // 是否被中断
  isImage?: boolean                  // 输出是否为图像
  backgroundTaskId?: string          // 后台任务 ID
  returnCodeInterpretation?: string  // 退出码语义解释
  noOutputExpected?: boolean         // 命令是否预期无输出
  structuredContent?: any[]          // 结构化内容块
  persistedOutputPath?: string       // 大输出持久化路径
}
```

#### 权限模型（最复杂）

BashTool 拥有整个工具系统中最复杂的权限链：

1. **`checkPermissionMode()`** — acceptEdits 模式下自动放行 fs 命令
2. **`bashCommandIsSafeAsync()`** — AST 级安全分析（tree-sitter 解析）
3. **`checkReadOnlyConstraints()`** — 只读命令验证（68KB 代码）
4. **`checkPathConstraints()`** — 路径约束（43KB 代码）
5. **`checkSedConstraints()`** — sed 编辑约束
6. **`shouldUseSandbox()`** — 沙箱模式判定
7. **`bashToolHasPermission()`** — 总权限判定（98KB 代码）
8. **Classifier** — `classifyBashCommand()` 用于 AI 驱动的权限分类

**安全特性**：
- Tree-sitter AST 解析，检测命令替换 (`$()`, `<()`, 反引号)
- 阻止 Zsh 特定危险命令（zmodload, emulate, sysopen 等）
- 阻止设备文件（/dev/zero, /dev/random 等无限输出设备）
- 阻止 PowerShell 语法（`<#` 注释）
- 破坏性命令警告（git reset --hard, git push --force 等）

---

### 2.2 FileEditTool ⭐

**文件**: `FileEditTool/FileEditTool.ts` (~630KB)
**名称**: `Edit`
**用途**: 原地编辑文件内容

#### 内部结构

| 文件 | 用途 |
|------|------|
| `FileEditTool.ts` | 主工具：验证、权限、执行、Git diff 追踪 |
| `types.ts` | Zod Schema（input/output） |
| `constants.ts` | 工具名、权限模式常量 |
| `prompt.ts` | 工具描述文本 |
| `UI.tsx` | React 渲染 |
| `utils.ts` | 字符串匹配、diff 生成、引号保留 |

#### Input Schema

```ts
{
  file_path: string       // 绝对路径
  old_string: string      // 要替换的文本
  new_string: string      // 替换后的文本
  replace_all?: boolean   // 替换所有匹配（默认 false）
}
```

#### Output Schema

```ts
{
  filePath: string                    // 文件路径
  oldString: string                   // 原始文本
  newString: string                   // 新文本
  originalFile: string                // 编辑前文件内容
  structuredPatch: Hunk[]             // Diff patch
  userModified: boolean               // 用户是否修改了提议
  replaceAll: boolean                 // 是否全部替换
  gitDiff?: GitDiff                   // Git diff 信息
}
```

#### 权限检查

```ts
checkPermissions(input, context):
  → checkWritePermissionForTool(FileEditTool, input, permissionContext)
```

- 路径展开（`~` → 绝对路径）
- 团队记忆文件秘密检测（`checkTeamMemSecrets`）
- `old_string !== new_string` 验证
- 文件大小限制（1 GiB）
- 文件未修改验证（防止覆盖他人更改）
- LSP 诊断清理
- 技能目录自动发现和激活

---

### 2.3 FileReadTool ⭐

**文件**: `FileReadTool/FileReadTool.ts` (~1034KB)
**名称**: `Read`
**用途**: 读取文件内容

#### 内部结构

| 文件 | 用途 |
|------|------|
| `FileReadTool.ts` | 主工具：文件读取、PDF 处理、图像处理、notebook 支持 |
| `prompt.ts` | 工具描述、提示模板、常量（MAX_LINES=2000） |
| `limits.ts` | 文件读取限制配置 |
| `imageProcessor.ts` | 图像处理管线 |
| `UI.tsx` | React 渲染 |

#### Input Schema

```ts
{
  file_path: string       // 绝对路径
  offset?: number         // 起始行号（可选）
  limit?: number          // 读取行数（可选，max 2000）
}
```

#### Output Schema

```ts
// 结构化内容块数组，支持：
// - 文本内容（带行号）
// - 图像（Base64 PNG/JPG）
// - PDF 页面
// - Jupyter notebook 单元格
```

#### 特殊能力

- **图像读取**: PNG, JPG, GIF, WebP → 直接展示
- **PDF 支持**: 分页读取，max 20 页/次
- **Notebook 支持**: .ipynb 文件解析
- **设备文件阻止**: /dev/zero, /dev/random, /dev/tty 等
- **macOS 截图路径**: 处理普通空格和窄空格（U+202F）差异
- **文件未变更缓存**: 返回 "File unchanged since last read" 避免重复传输

#### 权限检查

```ts
checkPermissions(input, context):
  → checkReadPermissionForTool(FileReadTool, input, permissionContext)
```

---

### 2.4 FileWriteTool ⭐

**文件**: `FileWriteTool/FileWriteTool.ts` (~435KB)
**名称**: `Write`
**用途**: 创建或覆写文件

#### Input Schema

```ts
{
  file_path: string       // 绝对路径
  content: string         // 文件内容
}
```

#### Output Schema

```ts
{
  type: 'create' | 'update'   // 创建或更新
  filePath: string             // 文件路径
  content: string              // 写入内容
  structuredPatch: Hunk[]      // Diff patch
  originalFile: string | null  // 原始内容（新文件为 null）
  gitDiff?: GitDiff            // Git diff 信息
}
```

#### 权限检查

```ts
checkPermissions(input, context):
  → checkWritePermissionForTool(FileWriteTool, input, permissionContext)
```

- 团队记忆秘密检测
- 文件修改时间追踪
- 技能目录发现和激活
- LSP 诊断清理

---

### 2.5 AgentTool ⭐

**文件**: `AgentTool/AgentTool.tsx` (~234KB)
**名称**: `Agent`
**用途**: 派生子代理执行任务

#### 内部结构（16 个文件）

| 文件 | 行数 | 用途 |
|------|------|------|
| `AgentTool.tsx` | ~6800 | 主工具定义、schema、执行逻辑 |
| `UI.tsx` | ~3700 | React 渲染（多代理进度、分组显示） |
| `runAgent.ts` | ~973 | 代理运行时：query 调度、消息传递、MCP 连接 |
| `agentToolUtils.ts` | ~686 | 工具过滤、异步生命周期、结果处理 |
| `loadAgentsDir.ts` | ~755 | 从 .claude/agents/ 加载代理定义 |
| `prompt.ts` | ~287 | 代理列表格式化、工具描述生成 |
| `forkSubagent.ts` | ~210 | Fork 子代理（worktree 隔离） |
| `resumeAgent.ts` | ~265 | 恢复代理执行 |
| `agentMemory.ts` | ~177 | 代理记忆管理 |
| `agentMemorySnapshot.ts` | ~197 | 记忆快照 |
| `agentDisplay.ts` | ~104 | 显示名称格式化 |
| `builtInAgents.ts` | ~72 | 内置代理注册 |
| `agentColorManager.ts` | ~66 | 代理颜色管理 |
| `constants.ts` | ~12 | 常量定义 |

#### 内置代理类型

| 代理类型 | 文件 | 用途 |
|----------|------|------|
| `general-purpose` | `generalPurposeAgent.ts` | 通用代理 |
| `Explore` | `exploreAgent.ts` | 代码探索 |
| `Plan` | `planAgent.ts` | 规划代理 |
| `Claude Code Guide` | `claudeCodeGuideAgent.ts` | 使用指南 |
| `Statusline Setup` | `statuslineSetup.ts` | 状态栏配置 |
| `verification` | `verificationAgent.ts` | 验证代理 |

#### Input Schema

```ts
{
  description: string              // 简短描述 (3-5 词)
  prompt: string                   // 任务指令
  subagent_type?: string           // 代理类型
  model?: 'sonnet' | 'opus' | 'haiku'  // 模型覆盖
  run_in_background?: boolean      // 后台运行
  // 以下为多代理功能（feature gate）
  name?: string                    // 代理名称
  team_name?: string              // 团队名称
  mode?: PermissionMode           // 权限模式
  isolation?: 'worktree' | 'remote'  // 隔离模式
  cwd?: string                    // 工作目录覆盖
}
```

#### Output Schema

```ts
{
  result: string           // 代理执行结果
  agentId: string          // 代理 ID
  // 可能包含 structured content
}
```

#### 权限检查

- `filterDeniedAgents()` — 检查代理类型是否被允许
- `isSourceAdminTrusted()` — 信任来源检查
- `isRestrictedToPluginOnly()` — 插件限制

#### 工具过滤

AgentTool 会根据代理类型过滤可用工具：
- `ALL_AGENT_DISALLOWED_TOOLS` — 所有代理都禁用的工具
- `CUSTOM_AGENT_DISALLOWED_TOOLS` — 自定义代理禁用的工具
- `ASYNC_AGENT_ALLOWED_TOOLS` — 异步代理允许的工具
- `IN_PROCESS_TEAMMATE_ALLOWED_TOOLS` — 进程内伙伴允许的工具

---

### 2.6 MCPTool ⭐

**文件**: `MCPTool/MCPTool.ts` (~100 行)
**名称**: `mcp`（动态覆盖）
**用途**: MCP（Model Context Protocol）工具桥接

#### 设计哲学

MCPTool 是一个 **模板工具**。真正的工具名、Schema、描述都在 `mcpClient.ts` 运行时覆盖。每个 MCP 服务器注册的工具都会动态创建 MCPTool 实例。

#### 核心定义

```ts
export const MCPTool = buildTool({
  isMcp: true,
  name: 'mcp',                      // 运行时被覆盖
  maxResultSizeChars: 100_000,
  // 所有关键方法都在 mcpClient.ts 中覆盖
  inputSchema: z.object({}).passthrough(),   // 接受任意输入
  outputSchema: z.string(),                   // 字符串输出
  async checkPermissions() {
    return { behavior: 'passthrough', message: 'MCPTool requires permission.' }
  },
})
```

#### 相关工具

| 工具 | 用途 |
|------|------|
| `MCPTool` | 执行 MCP 工具 |
| `ListMcpResourcesTool` | 列出 MCP 资源 |
| `ReadMcpResourceTool` | 读取 MCP 资源 |
| `McpAuthTool` | MCP 认证管理 |

---

## 3. 其他工具一览

### 3.1 文件系统工具

| 工具 | 名称 | Input | Output | 说明 |
|------|------|-------|--------|------|
| `GlobTool` | `Glob` | `{pattern, path?}` | `{durationMs, numFiles, filenames}` | 文件模式匹配 |
| `GrepTool` | `Grep` | `{pattern, path?, include?, -A?, -B?, context?, output_mode?}` | `{durationMs, numMatches, matches}` | 内容搜索 |
| `NotebookEditTool` | `NotebookEdit` | `{notebook_path, cell_number?, new_source, cell_type?, edit_mode?}` | 结构化 | Jupyter 编辑 |

### 3.2 网络工具

| 工具 | 名称 | Input | Output | 说明 |
|------|------|-------|--------|------|
| `WebFetchTool` | `WebFetch` | `{url, prompt}` | `{bytes, code, codeText, result}` | URL 获取+处理 |
| `WebSearchTool` | `WebSearch` | `{query, allowed_domains?, blocked_domains?}` | `{hits[], total_results}` | 网络搜索 |
| `RemoteTriggerTool` | `RemoteTrigger` | `{action, trigger_id?, ...}` | 结构化 | 远程触发器管理 |

### 3.3 代码智能

| 工具 | 名称 | Input | Output | 说明 |
|------|------|-------|--------|------|
| `LSPTool` | `LSP` | `{operation, filePath, line, column}` | 结构化 | LSP 操作（定义、引用、hover） |

### 3.4 任务管理

| 工具 | 名称 | Input | Output | 说明 |
|------|------|-------|--------|------|
| `TaskCreateTool` | `TaskCreate` | `{title, description?, priority?}` | `{id, ...}` | 创建任务 |
| `TaskGetTool` | `TaskGet` | `{id}` | `{task}` | 获取任务 |
| `TaskListTool` | `TaskList` | `{status?, limit?}` | `{tasks[]}` | 列出任务 |
| `TaskUpdateTool` | `TaskUpdate` | `{id, ...}` | `{task}` | 更新任务 |
| `TaskStopTool` | `TaskStop` | `{id, reason?}` | `{task}` | 停止任务 |
| `TaskOutputTool` | `TaskOutput` | `{id}` | 结构化 | 获取任务输出 |

### 3.5 多代理/团队

| 工具 | 名称 | Input | Output | 说明 |
|------|------|-------|--------|------|
| `SendMessageTool` | `SendMessage` | `{to, content}` | 结构化 | 代理间通信 |
| `TeamCreateTool` | `TeamCreate` | `{name, ...}` | 结构化 | 创建团队 |
| `TeamDeleteTool` | `TeamDelete` | `{name}` | 结构化 | 删除团队 |

### 3.6 规划与工作流

| 工具 | 名称 | Input | Output | 说明 |
|------|------|-------|--------|------|
| `EnterPlanModeTool` | `EnterPlanMode` | `{}` | `{message}` | 进入计划模式 |
| `ExitPlanModeTool` | `ExitPlanMode` | `{plan, allowedPrompts?}` | `{plan, isAgent}` | 退出计划模式 |
| `EnterWorktreeTool` | `EnterWorktree` | `{name}` | `{worktreePath, ...}` | 进入 worktree |
| `ExitWorktreeTool` | `ExitWorktree` | `{action}` | 结构化 | 退出 worktree |
| `TodoWriteTool` | `TodoWrite` | `{todos}` | `{oldTodos, newTodos}` | 待办列表管理 |

### 3.7 杂项

| 工具 | 名称 | Input | Output | 说明 |
|------|------|-------|--------|------|
| `AskUserQuestionTool` | `AskUserQuestion` | `{questions[]}` | `{answers[]}` | 交互式问答 |
| `BriefTool` | `SendUserMessage` | `{message, attachments?, status?}` | `{message, attachments}` | 向用户发消息 |
| `ConfigTool` | `Config` | `{setting, value?}` | 结构化 | 读写配置 |
| `SkillTool` | `Skill` | `{skill, args?}` | 结构化 | 执行技能命令 |
| `ScheduleCronTool` | `CronCreate` | `{cron, prompt, recurring?, durable?}` | 结构化 | 定时任务 |
| `SleepTool` | `Sleep` | — | — | 延迟（简单工具） |
| `ToolSearchTool` | `ToolSearch` | `{query}` | `{matches, query, total_deferred_tools}` | 搜索延迟加载工具 |
| `SyntheticOutputTool` | `StructuredOutput` | `{}` (passthrough) | `string` | 结构化输出 |
| `TungstenTool` | — | — | — | Stub（内部 Anthropic 工具，`null`） |
| `REPLTool` | — | — | — | 交互式 REPL 包装 |
| `PowerShellTool` | — | — | — | Windows PowerShell（类似 BashTool 的 Windows 版） |

---

## 4. 工具间依赖关系

### 4.1 导入依赖图

```
BashTool
  ├── FileEditTool (sed 编辑时调用)
  ├── shared/gitOperationTracking (Git 操作追踪)
  └── SandboxManager (沙箱执行)

FileEditTool
  ├── FileReadTool (常量引用)
  ├── NotebookEditTool (notebook 文件检测)
  └── shared (技能发现)

FileReadTool
  └── BashTool (常量引用，只读约束)

FileWriteTool
  ├── FileEditTool (常量引用、diff schema)
  └── shared (技能发现)

AgentTool
  ├── BashTool (工具名引用)
  ├── FileReadTool (工具名引用)
  ├── SendMessageTool (代理间通信)
  ├── shared/spawnMultiAgent (多代理启动)
  ├── loadAgentsDir (代理定义加载)
  ├── builtInAgents (内置代理)
  └── runAgent (代理执行引擎)

MCPTool
  ├── mcpClient.ts (运行时覆盖：name, schema, call, description)
  └── ListMcpResourcesTool / ReadMcpResourceTool (MCP 资源)

PowerShellTool
  └── 类似 BashTool 的 Windows 版本（共享结构，独立实现）

REPLTool
  ├── AgentTool
  └── BashTool (作为可调用子工具)
```

### 4.2 共享基础设施

| 模块 | 路径 | 用途 |
|------|------|------|
| `spawnMultiAgent.ts` | `tools/shared/` | 多代理启动（tmux、in-process、remote） |
| `gitOperationTracking.ts` | `tools/shared/` | Git 操作性能追踪 |
| `TestingPermissionTool.tsx` | `tools/testing/` | 测试专用权限工具 |
| `utils.ts` | `tools/` | 消息标签、工具 ID 提取 |
| `SandboxManager` | `utils/sandbox/` | 沙箱执行管理 |
| `PermissionResult` | `types/permissions.ts` | 权限类型定义 |

---

## 5. 工具注册与发现

### 5.1 静态注册

大多数工具在 `src/tools.ts` 中静态导入和注册。

### 5.2 动态发现

- **MCP 工具**: 通过 `mcpClient.ts` 动态创建，每个 MCP 服务器注册独立工具
- **Agent 定义**: 从 `.claude/agents/` 目录加载（`loadAgentsDir.ts`）
  - 支持 Markdown frontmatter 定义工具白名单/黑名单
  - 支持 MCP 服务器需求声明
- **Skill 工具**: `SkillTool` 通过 `Skill` 名称动态调用
- **ToolSearchTool**: 延迟加载机制，支持 `select:<name>` 直接选择

### 5.3 Feature Gates

工具功能通过 `feature()` 函数控制（Bun bundler 常量折叠）：

| Feature | 影响 |
|---------|------|
| `KAIROS` | AgentTool `cwd` 参数 |
| `PROACTIVE` | AgentTool 主动式模块 |
| `COORDINATOR_MODE` | 协调器模式代理 |
| `BUILTIN_EXPLORE_PLAN_AGENTS` | 内置 Explore/Plan 代理 |
| `VERIFICATION_AGENT` | 验证代理 |
| `TRANSCRIPT_CLASSIFIER` | `auto` 权限模式 |
| `BASH_CLASSIFIER` | Bash 命令 AI 分类权限 |
| `MONITOR_TOOL` | 监控工具（替代 sleep 轮询） |
| `AGENT_SUMMARIZATION` | 代理结果摘要 |

---

## 6. 安全架构总结

### 6.1 防御层级（以 BashTool 为例）

```
用户请求 → tool call
    ↓
1. Input Schema 验证 (Zod)
    ↓
2. Tool.checkPermissions()  — 工具级
    ↓
3. checkPermissionMode()     — 模式级
    ↓
4. bashCommandIsSafeAsync()  — AST 安全分析
    ↓
5. checkReadOnlyConstraints() — 只读约束
    ↓
6. checkPathConstraints()    — 路径约束
    ↓
7. checkSedConstraints()     — sed 约束
    ↓
8. shouldUseSandbox()        — 沙箱判定
    ↓
9. bashToolHasPermission()   — 权限规则匹配
    ↓
10. classifyBashCommand()    — AI 分类器（可选）
    ↓
    allow / ask / deny
```

### 6.2 写入工具安全共性

`FileEditTool`、`FileWriteTool`、`NotebookEditTool` 共享：
- 路径展开和规范化
- 写权限检查 (`checkWritePermissionForTool`)
- 团队记忆秘密检测
- 文件修改时间一致性验证
- Git diff 追踪
- 技能目录自动发现

### 6.3 沙箱机制

`SandboxManager` 提供：
- 文件系统读/写白名单/黑名单
- 网络访问控制（允许/拒绝主机列表）
- Unix socket 控制
- 违规忽略规则
- `dangerouslyDisableSandbox` 逃生口（需用户确认）

---

## 7. 关键设计模式

### 7.1 Lazy Schema

所有 Schema 使用 `lazySchema()` 包装，延迟求值以避免循环依赖和模块初始化问题：

```ts
const inputSchema = lazySchema(() => z.strictObject({ ... }))
```

### 7.2 UI 组件分离

每个工具的 React 渲染组件分离到 `UI.tsx`：
- `renderToolUseMessage()` — 工具调用显示
- `renderToolResultMessage()` — 结果显示
- `renderToolUseErrorMessage()` — 错误显示
- `renderToolUseProgressMessage()` — 进度显示
- `renderToolUseRejectedMessage()` — 拒绝显示
- `userFacingName()` — 用户可见名称

### 7.3 Semantic Boolean/Number

`semanticBoolean()` 和 `semanticNumber()` 是 Zod 扩展，用于在 schema 层面标记布尔值和数字，使 AI 模型更容易理解参数类型：

```ts
run_in_background: semanticBoolean(z.boolean().optional())
timeout: semanticNumber(z.number().optional())
```

---

*文档生成时间: 2026-03-31*
