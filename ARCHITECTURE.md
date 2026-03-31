# Claude Code — 架构全景

> 项目规模：~1,900 源文件，512,000+ 行 TypeScript/TSX
> 运行时：Bun | 终端 UI：React + Ink (自定义渲染器) | CLI：Commander.js

---

## 1. 整体架构分层

```
┌─────────────────────────────────────────────────────────┐
│                    CLI 入口 (main.tsx)                   │
│  Commander.js 参数解析 → 会话初始化 → 渲染上下文         │
├─────────────────────────────────────────────────────────┤
│                    REPL 屏幕 (REPL.tsx)                  │
│  主交互循环：用户输入 → LLM 查询 → 工具执行 → UI 渲染    │
├──────────┬──────────┬──────────┬────────────────────────┤
│ Commands │  Tools   │ Services │    Bridge/Remote       │
│ (斜杠命令)│ (工具系统)│ (服务层)  │    (IDE/远程集成)      │
├──────────┴──────────┴──────────┴────────────────────────┤
│                    State Management                     │
│  Zustand store + onChangeAppState + hooks               │
├─────────────────────────────────────────────────────────┤
│                    Ink 渲染器 (ink/)                     │
│  自定义 React 渲染器 → 终端 ANSI 输出                    │
├─────────────────────────────────────────────────────────┤
│                    组件层 (components/)                   │
│  346 个 React 组件：消息渲染、权限对话框、导航等          │
├─────────────────────────────────────────────────────────┤
│                    Hooks 层 (hooks/)                     │
│  104 个自定义 hooks：输入处理、权限、IDE集成、通知等      │
├─────────────────────────────────────────────────────────┤
│                    工具函数层 (utils/)                    │
│  ~300 个工具文件：git、shell、权限、插件、模型等          │
└─────────────────────────────────────────────────────────┘
```

---

## 2. 入口与初始化流程

### main.tsx (4,683 行)

程序的唯一入口。初始化顺序：

```
1. 启动优化：profileCheckpoint + MDM 子进程 + Keychain 预取 (并行)
2. 导入权重模块 (~135ms)
3. 检测调试模式 → 拦截调试器
4. main() 函数:
   ├─ 安全设置 (Windows PATH 安全)
   ├─ URL 处理 (cc://, deep link, SSH, assistant)
   ├─ 检测 -p/--print (非交互模式) vs 交互模式
   ├─ Commander.js 程序定义 (~100 个 CLI 选项)
   ├─ preAction hook:
   │   ├─ init() - 配置、认证、特性开关初始化
   │   ├─ 运行迁移 (11 个版本迁移)
   │   ├─ 加载远程管理设置
   │   └─ 加载策略限制
   └─ 主命令 action:
       ├─ initializeToolPermissionContext()
       ├─ setup() - 工作目录、工作树
       ├─ getCommands() + getAgentDefinitions() (并行)
       ├─ showSetupScreens() - 信任对话框、OAuth、引导
       ├─ MCP 配置加载和连接
       ├─ 构建初始 AppState
       └─ 分支:
           ├─ --continue → 加载最近对话 → launchRepl()
           ├─ --resume <id> → 恢复指定会话 → launchRepl()
           ├─ --teleport → 远程恢复 → launchRepl()
           ├─ --remote → 远程会话 → launchRepl()
           ├─ -p/--print → runHeadless() (非交互)
           └─ 默认 → launchRepl() (新会话)
```

### 初始化优化策略

- **并行预取**：MDM 读取、Keychain 读取、API 预连接在导入前并行启动
- **延迟加载**：OpenTelemetry (~400KB)、gRPC (~700KB) 等通过 `import()` 延迟
- **Feature Flag 死码消除**：`bun:bundle` 的 `feature()` 在构建时裁剪未启用的功能
- **Memoize 缓存**：`getCommands()`、`getTools()` 等昂贵操作通过 lodash memoize 缓存

### Feature Flags (关键)

| Flag | 功能 |
|------|------|
| `PROACTIVE` / `KAIROS` | 主动模式 / 助手模式 |
| `BRIDGE_MODE` | 远程控制 (Remote Control) |
| `DIRECT_CONNECT` | cc:// URL 直连 |
| `SSH_REMOTE` | SSH 远程会话 |
| `COORDINATOR_MODE` | 多 Agent 协调模式 |
| `TRANSCRIPT_CLASSIFIER` | 自动模式 (auto-mode) |
| `VOICE_MODE` | 语音输入 |
| `AGENT_TRIGGERS` | Cron 定时触发 |
| `WORKFLOW_SCRIPTS` | 工作流脚本 |
| `TERMINAL_PANEL` | 终端面板捕获 |
| `WEB_BROWSER_TOOL` | 内嵌浏览器 |

---

## 3. REPL 交互循环 (REPL.tsx, 5,005 行)

核心交互界面。数据流：

```
用户输入 (PromptInput)
  │
  ├─ /命令 → processSlashCommand() → 命令处理
  │
  └─ 普通文本 → processUserInput()
       │
       ├─ fetchSystemPromptParts() → 系统提示
       ├─ loadMemoryPrompt() → 记忆
       ├─ buildEffectiveSystemPrompt() → 合成最终系统提示
       │
       └─ query() [QueryEngine.ts, 1,295 行]
            │
            ├─ API 调用 (Anthropic SDK, 流式)
            ├─ 思考模式 (thinking config)
            ├─ Token 预算管理
            │
            └─ 工具调用循环:
                 │
                 ├─ 工具使用块 → 权限检查
                 │   ├─ 通过 → 执行工具
                 │   └─ 拒绝 → 提示用户批准/拒绝
                 │
                 └─ 继续 API 调用直到完成
```

### QueryEngine.ts 核心职责

1. 构建 API 请求（消息、系统提示、工具定义）
2. 处理流式响应（thinking、工具使用、文本）
3. Token 计数和预算管理
4. 重试逻辑和错误处理
5. 紧凑/压缩触发
6. 副本记录 (transcript recording)

---

## 4. 状态管理

### AppStateStore.ts (569 行)

使用自定义的 `createStore()` 实现（非 Redux，非 Zustand），类型安全。

核心状态字段：

```typescript
AppState {
  // 核心
  verbose: boolean
  mainLoopModel: ModelSetting
  toolPermissionContext: ToolPermissionContext
  isBriefOnly: boolean

  // MCP
  mcp: { clients, tools, commands, resources }

  // 插件
  plugins: { enabled, disabled, commands, errors }

  // 远程控制
  replBridgeEnabled: boolean
  replBridgeConnected: boolean

  // 任务
  tasks: Record<string, TaskState>
  todos: Record<string, TodoList>

  // 团队
  teamContext: TeamContext

  // 通知
  notifications: { current, queue }

  // 会话
  inbox: { messages }
  speculation: SpeculationState
  attribution: AttributionState
  sessionHooks: Map
}
```

### onChangeAppState

状态变更时触发的副作用集合。`store.setState()` 后会执行 `onChangeAppState` 中注册的所有回调。

---

## 5. 工具系统 (tools/, 42 个工具)

### 工具接口 (Tool.ts, 792 行)

每个工具实现 `Tool` 接口：

```typescript
Tool {
  name: string                    // 工具名称
  description: string             // 描述 (用于系统提示)
  inputSchema: JSONSchema         // 输入 JSON Schema
  userFacingName(): string        // 用户显示名
  isEnabled(): boolean            // 是否启用
  needsPermissions(input): boolean // 是否需要权限
  call(input, context): Result    // 执行函数
  renderToolUseMessage(input): UI // UI 渲染
  renderToolResultMessage(): UI   // 结果渲染
}
```

### 核心工具分类

**文件操作**: FileReadTool, FileEditTool, FileWriteTool, GlobTool, GrepTool
**执行**: BashTool, PowerShellTool (Windows)
**AI**: AgentTool (子 Agent), SkillTool (技能执行)
**外部**: WebFetchTool, WebSearchTool
**MCP**: MCPTool, ListMcpResourcesTool, ReadMcpResourceTool
**规划**: EnterPlanModeTool, ExitPlanModeV2Tool
**任务**: TaskCreateTool, TaskGetTool, TaskUpdateTool, TaskListTool, TaskStopTool
**团队**: TeamCreateTool, TeamDeleteTool, SendMessageTool
**其他**: TodoWriteTool, BriefTool, AskUserQuestionTool, ConfigTool

### 工具执行流程

```
1. QueryEngine 产出 ToolUseBlock
2. useCanUseTool hook → 权限检查
3. 工具 handler 执行
4. 结果 → ToolResultBlock → 回到 QueryEngine
```

### 权限系统

`ToolPermissionContext` 定义权限模式：
- `default` — 每次询问用户
- `plan` — 只读，编辑需批准
- `bypassPermissions` — 跳过所有检查（危险）
- `auto` — 基于分类器自动决策

权限规则通过 `PermissionRule` 配置，支持 allow/deny 规则匹配。

---

## 6. 命令系统 (commands/, 80+ 命令)

### 命令类型

- **`prompt` 型** — 扩展为文本发送给 LLM（如 `/commit`）
- **`local` 型** — 本地执行并显示结果（如 `/cost`）
- **`local-jsx` 型** — 渲染 JSX UI（如 `/config`）

### 命令来源

1. **内置命令** — `commands.ts` 中的 `COMMANDS()` (memoize)
2. **技能命令** — `skills/` 目录中的 `.md` 文件
3. **插件命令** — 插件注册的命令
4. **Bundled 技能** — `skills/bundled/` 中的内置技能
5. **MCP 命令** — MCP 服务器提供的 prompt 资源

### 加载优先级

```
Bundled Skills → Plugin Skills → Skill Dir → Workflows → Plugin Commands → Built-in
```

---

## 7. 服务层 (services/)

### 核心服务

| 服务 | 职责 |
|------|------|
| `api/` | Anthropic API 客户端、使用量跟踪、bootstrap |
| `mcp/` | MCP 协议：服务器连接、工具发现、认证 |
| `oauth/` | OAuth 2.0 认证流程 |
| `lsp/` | LSP 语言服务器管理 |
| `analytics/` | GrowthBook 特性开关 + 遥测 |
| `compact/` | 上下文压缩（microcompact、auto-compact） |
| `plugins/` | 插件安装、加载、版本管理 |
| `extractMemories/` | 自动记忆提取 |
| `tokenEstimation.ts` | Token 计数估算 |
| `teamMemorySync/` | 团队记忆同步 |
| `tips/` | 提示系统 |
| `policyLimits/` | 组织策略限制 |

---

## 8. Bridge / 远程系统 (bridge/, remote/, server/)

### Bridge (IDE 集成)

双向通信层，连接 VS Code / JetBrains 扩展与 CLI。

```
IDE Extension ←── JSON-RPC ──→ Bridge Manager ←── Session ──→ REPL
                   (ws/stdio)                     (权限桥接)
```

关键组件：
- `bridgeMain.ts` — 桥接主循环
- `bridgeMessaging.ts` — 消息协议
- `bridgePermissionCallbacks.ts` — 权限回调代理
- `replBridge.ts` — REPL 会话桥接
- `sessionRunner.ts` — 会话执行管理
- `trustedDevice.ts` — 可信设备认证

### Remote Control

用户从 claude.ai/web/mobile 控制本地会话：
- `bridge/bridgeMain.ts` — 服务器连接
- `remote/RemoteSessionManager.ts` — 远程会话管理
- `remote/SessionsWebSocket.ts` — WebSocket 连接

### Server 模式

独立的 HTTP 服务器模式（`server/`），支持多会话并发。

---

## 9. Ink 渲染器 (ink/, 96 个文件)

**自定义的 React 终端渲染器**，不是直接使用 npm ink 包，而是 fork 并深度定制。

核心模块：
- `reconciler.ts` — React reconciler 实现
- `renderer.ts` — 终端 ANSI 输出渲染
- `layout/` — Yoga 布局引擎集成
- `events/` — 键盘/鼠标/终端事件系统
- `screen.ts` — 屏幕管理
- `selection.ts` — 文本选择
- `searchHighlight.ts` — 搜索高亮
- `termio/` — 终端 I/O 解析（ANSI/CSI/OSC/SGR）

---

## 10. 钩子系统 (hooks/)

### 工具权限钩子

```
toolPermission/
├── PermissionContext.ts           — 权限上下文
├── handlers/
│   ├── interactiveHandler.ts      — 交互模式处理器
│   ├── coordinatorHandler.ts      — 协调器模式处理器
│   └── swarmWorkerHandler.ts      — Swarm 工作器处理器
└── permissionLogging.ts           — 权限日志
```

### 通知钩子

`hooks/notifs/` — 16 个通知钩子，处理各种状态通知（模型迁移、速率限制、IDE 状态等）。

### 关键 hooks

| Hook | 职责 |
|------|------|
| `useReplBridge.tsx` | 远程控制桥接 |
| `useCanUseTool.tsx` | 工具权限检查 |
| `useGlobalKeybindings.tsx` | 全局键盘快捷键 |
| `useVoice.ts` / `useVoiceIntegration.tsx` | 语音输入 |
| `useTasksV2.ts` | 任务管理 |
| `useSwarmInitialization.ts` | Swarm 团队初始化 |
| `useMergedTools.ts` | 工具池合并 (内置 + MCP) |
| `useMergedCommands.ts` | 命令池合并 |
| `useSettings.ts` | 设置管理 |

---

## 11. 插件系统 (plugins/)

### 架构

```
plugins/
├── builtinPlugins.ts      — 内置插件列表
├── bundled/
│   └── index.ts           — 捆绑插件初始化
utils/plugins/
├── pluginLoader.ts        — 插件加载器
├── installedPluginsManager.ts — 已安装插件管理
├── marketplaceManager.ts  — 市场管理
├── validatePlugin.ts      — 插件验证
├── loadPluginCommands.ts  — 加载插件命令
├── loadPluginHooks.ts     — 加载插件钩子
├── loadPluginAgents.ts    — 加载插件 Agent
└── loadPluginOutputStyles.ts — 加载输出样式
```

插件可以提供：命令、工具、钩子、Agent 定义、输出样式。

---

## 12. 配置系统

### 多层级配置

```
1. 远程管理设置 (enterprise MDM)
2. 策略设置 (organization policy)
3. 用户设置 (~/.claude/settings.json)
4. 项目设置 (.claude/settings.json)
5. 本地设置 (.claude/settings.local.json)
6. CLI 标志 (--model, --permission-mode 等)
7. 环境变量 (ANTHROPIC_API_KEY, CLAUDE_CODE_* 等)
```

### 设置验证

`utils/settings/validation.ts` — Zod schema 验证，支持类型检查和错误报告。

### 迁移系统

`migrations/` — 11 个版本迁移脚本，按序号执行（模型名称迁移、配置迁移等）。

---

## 13. 记忆系统 (memdir/)

```
memdir/
├── memdir.ts             — 记忆目录操作
├── paths.ts              — 路径解析
├── memoryScan.ts         — 记忆扫描
├── memoryAge.ts          — 记忆年龄管理
├── memoryTypes.ts        — 类型定义
├── findRelevantMemories.ts — 相关记忆查找
├── teamMemPaths.ts       — 团队记忆路径
└── teamMemPrompts.ts     — 团队记忆提示
```

记忆存储在 `~/.claude/memory/` 目录，自动从对话中提取。

---

## 14. 性能优化

### 启动优化

1. **并行子进程**：MDM 读取 + Keychain 预取 + 导入并行 (~135ms)
2. **延迟加载**：重型模块动态导入（OpenTelemetry, gRPC, print.ts）
3. **Feature Flag DCE**：未启用的功能在构建时完全裁剪
4. **Memoize**：`getCommands()`, `getTools()`, `getSkills()` 等结果缓存
5. **预连接**：API 预连接在用户输入前完成

### 运行时优化

1. **Token 预算**：上下文压缩触发管理
2. **文件历史快照**：高效的文件变更追踪
3. **虚拟滚动**：`VirtualMessageList` 支持大量消息
4. **流式渲染**：增量 ANSI 输出

---

## 15. 关键数据流总结

```
用户输入
  │
  ├→ /command → processSlashCommand → 命令执行 → 可能触发 query()
  │
  └→ 文本输入 → processUserInput
       │
       ├→ processBashCommand (以 ! 开头)
       └→ processTextPrompt
            │
            └→ QueryEngine.query()
                 │
                 ├→ 构建 system prompt (fetchSystemPromptParts + buildEffectiveSystemPrompt)
                 ├→ 构建 messages (对话历史)
                 ├→ 构建 tools (getTools + MCP tools)
                 │
                 ├→ API 调用 (Anthropic SDK, streaming)
                 │
                 └→ 循环处理响应:
                      │
                      ├→ text block → 显示消息
                      ├→ thinking block → 显示思考过程
                      └→ tool_use block → 权限检查 → 执行 → 结果回传 API
```

---

## 附录：详细模块文档

- [Tools 详细分析](./ARCHITECTURE-TOOLS.md)
- [Services 详细分析](./ARCHITECTURE-SERVICES.md)
- [Components 详细分析](./ARCHITECTURE-COMPONENTS.md)
- [Bridge/Remote 详细分析](./ARCHITECTURE-BRIDGE-REMOTE.md)
- [Utils 详细分析](./ARCHITECTURE-UTILS.md)
- [Commands/Skills/Plugins 详细分析](./ARCHITECTURE-COMMANDS.md)
