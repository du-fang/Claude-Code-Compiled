# Bridge / Remote / Coordinator 架构详细文档

---

## Bridge 系统 (src/bridge/, 31 文件)

### 概述

Bridge 是 Claude Code 的 **远程控制核心**，实现本地 CLI 与 claude.ai/web/mobile 之间的双向通信。核心场景：用户通过手机上的 Claude 应用控制本地终端中的 Claude Code 会话。

### 文件清单与职责

#### 核心会话管理

| 文件 | 行数(估) | 职责 |
|------|---------|------|
| `bridgeMain.ts` | ~3000 | 桥接主循环。连接 claude.ai bridge API、轮询 work、生成 session、管理生命周期 |
| `sessionRunner.ts` | ~400 | 会话执行器：生成子进程执行 work item，管理 worktree 隔离 |
| `createSession.ts` | ~200 | 会话创建辅助 |
| `replBridge.ts` | ~2400 | REPL 与远程的桥接核心。处理 SDK 消息的 ingress/egress、权限转发 |
| `replBridgeHandle.ts` | ~200 | Bridge handle 管理 |
| `replBridgeTransport.ts` | ~300 | 传输层抽象：v1 (WebSocket) 和 v2 (HybridTransport) |

#### 消息与控制

| 文件 | 职责 |
|------|------|
| `bridgeMessaging.ts` | 共享传输层：SDK 消息解析、控制请求处理、echo 去重、结果消息构建 |
| `inboundMessages.ts` | 入站消息处理 |
| `inboundAttachments.ts` | 入站附件处理 |
| `bridgeApi.ts` | Bridge API 客户端：环境发现、work 轮询、session 报告 |
| `bridgePermissionCallbacks.ts` | 权限回调代理：将远程权限请求转发到本地 REPL |

#### 安全与认证

| 文件 | 职责 |
|------|------|
| `jwtUtils.ts` | JWT token 管理：创建、刷新调度、过期检测 |
| `trustedDevice.ts` | 可信设备认证：注册设备 token，用于 Remote Control 安全验证 |
| `workSecret.ts` | Work secret 解码/构建：解析 server 下发的 session ingress token、API base URL 等 |
| `sessionIdCompat.ts` | Session ID 兼容层：infra session ID 与 compat session ID 转换 |

#### 配置与控制

| 文件 | 职责 |
|------|------|
| `bridgeConfig.ts` | Bridge 配置：token、org UUID、environment ID |
| `envLessBridgeConfig.ts` | 无环境变量的 Bridge 配置 |
| `bridgeEnabled.ts` | 功能开关检查：是否启用 Remote Control |
| `initReplBridge.ts` | REPL Bridge 初始化 |
| `pollConfig.ts` / `pollConfigDefaults.ts` | 轮询间隔配置（指数退避） |
| `flushGate.ts` | 消息刷新门控 |

#### 其他

| 文件 | 职责 |
|------|------|
| `bridgeUI.ts` | Bridge UI 日志工具 |
| `bridgeDebug.ts` / `debugUtils.ts` | 调试工具 |
| `bridgeStatusUtil.ts` | 状态格式化 |
| `bridgePointer.ts` | Bridge 指针管理 |
| `capacityWake.ts` | 容量唤醒：检测是否有 capacity 来处理新的 work |
| `codeSessionApi.ts` | 代码会话 API |
| `types.ts` | 类型定义：BridgeConfig, SessionHandle, SpawnMode 等 |

### 核心流程

```
claude remote-control
  │
  ├─ bridgeMain.ts: 连接 claude.ai bridge API
  │   ├─ 获取 environment ID
  │   ├─ 注册 trusted device
  │   └─ 开始轮询 work
  │
  ├─ 轮询循环 (指数退避):
  │   ├─ GET /environments/{id}/work
  │   ├─ 收到 work item → sessionRunner 生成子进程
  │   │   ├─ 创建 worktree (隔离)
  │   │   ├─ 解析 work secret → session ingress token
  │   │   ├─ spawn claude CLI 子进程
  │   │   └─ 收集输出 → 上报
  │   └─ 无 work → 继续轮询
  │
  └─ 子进程通过 SDK 流式输出消息
      └─ bridgeMessaging.ts 处理 ingress
          ├─ SDKMessage → 转发到远程
          ├─ control_request → 权限代理
          └─ echo → 去重跳过
```

### 协议层

Bridge 使用 **SDK 消息协议** (与 Anthropic Agent SDK 兼容):

```
SDKMessage = 
  | assistant message    (text, tool_use blocks)
  | user message         (tool_result blocks)
  | system message       (info, warning)
  | result message       (usage, cost, duration)
  | control_request      (permission prompts)
  | control_response     (permission decisions)
```

传输层支持两种模式：
- **v1**: WebSocket 直连
- **v2**: HybridTransport (WebSocket + HTTP fallback)

---

## Remote 系统 (src/remote/, 4 文件)

### 概述

Remote 系统实现 **CCR (Claude Code Remote)** 模式：用户通过 `--remote` 标志创建远程会话，本地 TUI 作为 viewer/client。

### 文件清单

| 文件 | 职责 |
|------|------|
| `RemoteSessionManager.ts` | 远程会话管理器：创建会话配置、处理 SDK 消息和控制请求 |
| `SessionsWebSocket.ts` | WebSocket 客户端：连接 CCR 后端、处理消息、重连逻辑 |
| `remotePermissionBridge.ts` | 远程权限桥接 |
| `sdkMessageAdapter.ts` | SDK 消息适配器 |

### 核心流程

```
claude --remote "task description"
  │
  ├─ prepareApiRequest() → 获取 OAuth token
  ├─ teleportToRemoteWithErrorHandling() → 创建远程会话
  ├─ createRemoteSessionConfig() → 生成连接配置
  │
  └─ REPL 启动:
      ├─ SessionsWebSocket 连接远程
      ├─ RemoteSessionManager 管理消息流
      │   ├─ 用户输入 → WebSocket → 远程执行
      │   └─ 远程输出 → WebSocket → 本地显示
      └─ 权限请求 → remotePermissionBridge → 本地确认
```

---

## Server 系统 (src/server/, 3 文件)

### Direct Connect

`createDirectConnectSession.ts` — 创建直连会话。POST 到 `${serverUrl}/sessions`，返回 `DirectConnectConfig` 供 REPL 使用。

`directConnectManager.ts` — 直连会话管理。

`types.ts` — 连接响应 schema 验证。

### 使用场景

```
claude connect cc://server-url
  │
  ├─ parseConnectUrl() → 提取 serverUrl + authToken
  ├─ createDirectConnectSession() → 创建会话
  └─ launchRepl() with directConnectConfig
      └─ REPL 通过 DirectConnectConfig 与远程通信
```

---

## Coordinator 系统 (src/coordinator/)

### 概述

`coordinatorMode.ts` — 多 Agent 协调模式。一个 "协调者" Agent 分发任务给多个 "工作器" Agent。

### 核心机制

协调模式通过环境变量 `CLAUDE_CODE_COORDINATOR_MODE=1` 启用。

工具过滤：
- 协调者只能使用：AgentTool, TaskStopTool, SendMessageTool, TeamCreateTool, TeamDeleteTool
- 工作器使用：BashTool, FileReadTool, FileEditTool, FileWriteTool 等基础工具
- 工作器禁止：AgentTool (防止递归), TeamCreateTool, TeamDeleteTool

### 协调者工具集

```typescript
const COORDINATOR_MODE_ALLOWED_TOOLS = [
  AGENT_TOOL_NAME,        // 派发子任务给工作器
  BASH_TOOL_NAME,         // 读取文件/检查状态
  FILE_READ_TOOL_NAME,    // 读文件
  FILE_EDIT_TOOL_NAME,    // 编辑文件
  TASK_STOP_TOOL_NAME,    // 停止工作器
  SEND_MESSAGE_TOOL_NAME, // 与工作器通信
]
```

### 工作器执行

工作器以 in-process 或 tmux 方式启动：
- `in-process`: 子 Agent 在同一进程内运行
- `tmux`: 子 Agent 在独立 tmux 窗格中运行

每个工作器有独立的工作树 (worktree)、独立的工具权限上下文。

---

## Swarm 团队系统 (utils/swarm/)

### 目录结构

```
utils/swarm/
├── backends/
│   ├── InProcessBackend.ts    — 进程内执行后端
│   ├── TmuxBackend.ts         — tmux 执行后端
│   ├── ITermBackend.ts        — iTerm2 执行后端
│   ├── PaneBackendExecutor.ts — 窗格执行器
│   ├── detection.ts           — 后端检测
│   ├── registry.ts            — 后端注册
│   └── types.ts               — 类型定义
├── constants.ts               — 常量
├── inProcessRunner.ts         — 进程内运行器
├── leaderPermissionBridge.ts  — 领导者权限桥接
├── permissionSync.ts          — 权限同步
├── reconnection.ts            — 重连逻辑
├── spawnInProcess.ts          — 进程内生成
├── spawnUtils.ts              — 生成工具
├── teamHelpers.ts             — 团队辅助
├── teammateInit.ts            — 队友初始化
├── teammateLayoutManager.ts   — 队友布局管理
├── teammateModel.ts           — 队友模型
└── teammatePromptAddendum.ts  — 队友提示补充
```

### 架构

Swarm 团队由一个 Leader 和多个 Teammate 组成：

```
Leader (协调者)
  │
  ├─ Teammate 1 (tmux/in-process)
  ├─ Teammate 2 (tmux/in-process)
  └─ Teammate N (tmux/in-process)
```

Leader 通过 `TeamCreateTool` 创建队友，通过 `SendMessageTool` 与队友通信。

权限同步：Leader 的权限决策通过 `leaderPermissionBridge` 同步给所有队友。

---

## 系统间协作关系

```
┌──────────────────┐     ┌──────────────────┐
│   claude.ai      │     │  Mobile/Web App  │
│   Bridge API     │     │   (CCR Client)   │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
    Bridge 协议              Remote 协议
    (JWT auth)              (OAuth auth)
         │                        │
┌────────▼────────────────────────▼────────┐
│          本地 Claude Code CLI            │
│                                          │
│  ┌──────────┐  ┌──────────┐  ┌────────┐ │
│  │  Bridge  │  │  Remote  │  │ Server │ │
│  │ Manager  │  │  Session │  │ Mode   │ │
│  └────┬─────┘  └────┬─────┘  └───┬────┘ │
│       │             │            │       │
│       └─────────────┼────────────┘       │
│                     │                    │
│              ┌──────▼──────┐             │
│              │    REPL     │             │
│              │  (本地交互)  │             │
│              └──────┬──────┘             │
│                     │                    │
│              ┌──────▼──────┐             │
│              │   Query     │             │
│              │  Engine     │             │
│              └──────┬──────┘             │
│                     │                    │
│              ┌──────▼──────┐             │
│              │   Tools     │             │
│              │  (执行层)   │             │
│              └─────────────┘             │
└──────────────────────────────────────────┘
```

## 关键设计决策

1. **Worktree 隔离**：每个远程会话在独立 worktree 中执行，避免污染本地工作区
2. **JWT 认证**：Bridge 使用 JWT 而非 OAuth，支持 token 刷新调度
3. **Echo 去重**：bridgeMessaging.ts 中的 BoundedUUIDSet 防止消息回环
4. **指数退避轮询**：pollConfig.ts 实现智能轮询，空闲时降低频率
5. **Trusted Device**：远程控制需要设备注册，增强安全性
6. **v1/v2 传输**：支持 WebSocket (v1) 和 HybridTransport (v2) 两种传输模式
