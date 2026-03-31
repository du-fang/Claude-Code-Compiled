# Claude Code 服务层架构分析

> 基于 `src/services/` 目录下的实际源码分析。共 **21 个服务子目录** + **11 个独立服务文件**。

---

## 1. 服务总览

| 服务 | 类型 | 核心职责 |
|------|------|----------|
| `api/` | 核心基础设施 | API 客户端、bootstrap、usage tracking、重试逻辑 |
| `mcp/` | 核心协议 | MCP (Model Context Protocol) 协议实现与连接管理 |
| `oauth/` | 核心认证 | OAuth 2.0 + PKCE 认证流程 |
| `lsp/` | 核心IDE集成 | LSP 语言服务器管理与诊断 |
| `analytics/` | 核心可观测性 | 事件日志、Datadog、GrowthBook 特性开关 |
| `compact/` | 核心上下文管理 | 上下文压缩（自动/微压缩/会话记忆） |
| `plugins/` | 核心扩展性 | 插件安装、市场管理、CLI 命令 |
| `tools/` | 核心执行层 | 工具编排、执行、hook、流式执行 |
| `oauth/` | 核心认证 | OAuth 2.0 + PKCE 授权码流 |
| `settingsSync/` | 基础设施 | 跨环境设置同步 |
| `remoteManagedSettings/` | 企业管理 | 远程托管配置拉取与缓存 |
| `policyLimits/` | 企业管理 | 组织级策略限制 |
| `teamMemorySync/` | 协作 | 团队记忆文件同步 |
| `SessionMemory/` | AI记忆 | 会话级持久化记忆 |
| `extractMemories/` | AI记忆 | 从会话中提取持久化记忆 |
| `autoDream/` | AI记忆 | 后台记忆整合（/dream） |
| `AgentSummary/` | 协调器 | 子代理进度摘要 |
| `PromptSuggestion/` | UX增强 | 智能提示建议 |
| `MagicDocs/` | UX增强 | 自动文档更新 |
| `tips/` | UX增强 | Spinner 期间的提示展示 |
| `toolUseSummary/` | SDK | 工具调用批次的可读摘要 |

### 独立服务文件

| 文件 | 职责 |
|------|------|
| `voice.ts` | 音频录制（push-to-talk），原生 cpal/SoX 回退 |
| `voiceStreamSTT.ts` | 流式语音转文字 |
| `voiceKeyterms.ts` | 语音关键词处理 |
| `notifier.ts` | 系统通知（macOS/Linux/Windows） |
| `preventSleep.ts` | 阻止系统休眠 |
| `diagnosticTracking.ts` | 诊断跟踪状态管理 |
| `tokenEstimation.ts` | Token 用量估算 |
| `internalLogging.ts` | 内部日志 |
| `vcr.ts` | 录制/回放功能 |
| `claudeAiLimits.ts` | Claude.ai 速率限制处理 |
| `rateLimitMocking.ts` | 速率限制模拟（测试用） |
| `mockRateLimits.ts` | 速率限制 mock |
| `awaySummary.ts` | 离开时的会话摘要 |

---

## 2. 核心服务详细分析

### 2.1 `api/` — API 客户端层

**职责：** 与 Anthropic API 的所有通信。支持 Direct API、AWS Bedrock、Google Vertex AI、Azure Foundry 四种后端。

**关键文件与接口：**

| 文件 | 功能 | 对外接口 |
|------|------|----------|
| `client.ts` | Anthropic SDK 客户端工厂 | `createAnthropicClient()`, 多 provider 配置 |
| `claude.ts` | 消息发送核心 | `query()`, `streamClaudeResponse()`, `getMaxOutputTokensForModel()` |
| `bootstrap.ts` | 启动时获取客户端配置 | `fetchBootstrap()`, 返回 `client_data` + `additional_model_options` |
| `usage.ts` | 用量/速率追踪 | `fetchUtilization()`, `Utilization` (5h/7d 限制) |
| `withRetry.ts` | 智能重试 | `withRetry()`, 指数退避, 529 熔断, 前台/后台区分 |
| `errors.ts` | 错误处理 | `formatAPIError()`, 速率限制消息, 订阅检测 |
| `filesApi.ts` | 文件 API | 文件上传/下载，beta header `files-api-2025-04-14` |
| `grove.ts` | Grove (组织功能) | `fetchGroveConfig()`, 24h 缓存 |
| `logging.ts` | API 请求日志 | 请求/响应记录 |
| `sessionIngress.ts` | 会话入口 | 会话注册 |
| `referral.ts` | 推荐系统 | 推荐链接管理 |
| `adminRequests.ts` | 管理请求 | 管理员 API 调用 |

**多 Provider 支持：**
- **Direct API**: `ANTHROPIC_API_KEY`
- **AWS Bedrock**: AWS credentials + region 配置
- **Vertex AI**: `ANTHROPIC_VERTEX_PROJECT_ID` + model-specific region
- **Azure Foundry**: `ANTHROPIC_FOUNDRY_RESOURCE` + Azure AD / API key

**重试策略：**
- 默认最大重试 10 次，指数退避（500ms 基础延迟）
- 529 错误：前台查询重试最多 3 次，后台查询立即放弃
- OAuth 401 自动刷新重试（`withOAuth401Retry`）
- AWS/GCP 凭证自动刷新

---

### 2.2 `mcp/` — MCP 协议实现

**职责：** Model Context Protocol 的完整实现，管理 MCP 服务器连接、工具发现、资源读取。

**关键文件与接口：**

| 文件 | 功能 | 对外接口 |
|------|------|----------|
| `client.ts` | MCP 客户端核心 | `MCPClient` 类, 工具/资源/提示发现与调用 |
| `config.ts` | MCP 配置管理 | `getClaudeCodeMcpConfigs()`, 配置合并（local/user/project/enterprise） |
| `types.ts` | 类型定义 | `McpServerConfig`, `MCPServerConnection`, 7 种配置作用域 |
| `useManageMCPConnections.ts` | 连接管理 React Hook | 连接/断开/重连，工具列表刷新 |
| `auth.ts` | MCP OAuth 认证 | `discoverAuthorizationServerMetadata()`, PKCE, token 刷新 |
| `normalization.ts` | 工具/资源归一化 | 名称规范化，冲突解决 |
| `InProcessTransport.ts` | 进程内传输 | 内存中 MCP 服务器 |
| `SdkControlTransport.ts` | SDK 控制传输 | SDK 控制的 MCP 传输 |
| `channelAllowlist.ts` | 通道白名单 | 通道级 MCP 访问控制 |
| `channelPermissions.ts` | 通道权限 | 工具级细粒度权限 |
| `officialRegistry.ts` | 官方注册表 | MCP 服务器注册表查询 |
| `envExpansion.ts` | 环境变量展开 | `${VAR}` 语法支持 |
| `headersHelper.ts` | HTTP Headers | 自定义 header 处理 |
| `elicitationHandler.ts` | 引出处理 | MCP elicitation 协议 |
| `oauthPort.ts` | OAuth 端口 | MCP OAuth 回调端口管理 |
| `xaa.ts` | 跨应用访问 (XAA) | IdP 联合认证 |
| `claudeai.ts` | Claude.ai 集成 | Claude.ai MCP 配置获取 |

**配置作用域（ConfigScope）：**
1. `local` — 本地项目配置
2. `user` — 用户全局配置
3. `project` — 项目共享配置
4. `dynamic` — 动态添加
5. `enterprise` — 企业管理配置
6. `claudeai` — Claude.ai 配置
7. `managed` — 托管配置

**传输协议支持：**
- `stdio` — 标准输入/输出
- `sse` — Server-Sent Events
- `http` — Streamable HTTP
- `ws` — WebSocket
- `sdk` — SDK 内部

---

### 2.3 `oauth/` — OAuth 认证服务

**职责：** OAuth 2.0 + PKCE 授权码流的完整实现。

**关键文件与接口：**

| 文件 | 功能 | 对外接口 |
|------|------|----------|
| `index.ts` | `OAuthService` 类 | `startOAuthFlow()`, 支持自动/手动两种授权码获取方式 |
| `client.ts` | OAuth API 客户端 | `buildAuthUrl()`, `exchangeCodeForTokens()`, `refreshTokens()`, 用户信息获取 |
| `crypto.ts` | PKCE 加密 | `generateCodeVerifier()`, `generateCodeChallenge()`, `generateState()` |
| `auth-code-listener.ts` | 回调监听器 | `AuthCodeListener`, localhost 回调服务器 |
| `getOauthProfile.ts` | 用户画像 | OAuth profile 获取 |

**OAuth 流程：**
1. 生成 PKCE code_verifier + code_challenge
2. 构建授权 URL（支持 Claude.ai 和 Console 两种入口）
3. **自动模式**：打开浏览器 → localhost 回调捕获授权码
4. **手动模式**：用户手动复制粘贴授权码
5. 交换 token → 存储 OAuth tokens
6. token 过期自动刷新

**支持的登录方式：**
- `loginWithClaudeAi` — Claude.ai 订阅者
- `inferenceOnly` — 仅推理权限
- 自定义 `orgUUID` — 组织级登录
- `loginHint` — 登录提示

---

### 2.4 `lsp/` — LSP 语言服务器

**职责：** 管理多个 LSP 语言服务器实例，按文件扩展名路由请求。

**关键文件与接口：**

| 文件 | 功能 | 对外接口 |
|------|------|----------|
| `manager.ts` | 全局单例管理 | `getLspServerManager()`, `initializeLspServerManager()`, `shutdownLspServerManager()` |
| `LSPServerManager.ts` | 服务器管理器 | `initialize()`, `shutdown()`, `getServerForFile()`, `sendRequest()`, `openFile()`/`changeFile()`/`saveFile()`/`closeFile()` |
| `LSPClient.ts` | LSP 客户端 | `createLSPClient()`, 基于 `vscode-jsonrpc`, stdio 通信 |
| `LSPServerInstance.ts` | 服务器实例 | 单个 LSP 服务器的生命周期管理 |
| `config.ts` | 配置加载 | `getAllLspServers()`, 从 settings 读取 LSP 配置 |
| `passiveFeedback.ts` | 被动反馈 | LSP 诊断 → Claude 诊断格式转换 |
| `LSPDiagnosticRegistry.ts` | 诊断注册 | LSP 诊断事件注册与追踪 |

**管理器接口（LSPServerManager）：**
```typescript
interface LSPServerManager {
  initialize(): Promise<void>
  shutdown(): Promise<void>
  getServerForFile(filePath: string): LSPServerInstance | undefined
  ensureServerStarted(filePath: string): Promise<LSPServerInstance | undefined>
  sendRequest<T>(filePath: string, method: string, params: unknown): Promise<T | undefined>
  openFile(filePath: string, content: string): Promise<void>
  changeFile(filePath: string, content: string): Promise<void>
  saveFile(filePath: string): Promise<void>
  closeFile(filePath: string): Promise<void>
  isFileOpen(filePath: string): boolean
}
```

---

### 2.5 `analytics/` — 分析与特性开关

**职责：** 事件日志路由（Datadog + 一阶方事件）、GrowthBook 特性开关。

**关键文件与接口：**

| 文件 | 功能 | 对外接口 |
|------|------|----------|
| `index.ts` | 公共 API | `logEvent()`, `logEventAsync()`, 事件队列, `AnalyticsSink` 接口 |
| `sink.ts` | 路由实现 | `initializeAnalyticsSink()`, Datadog + 1P 双路路由 |
| `datadog.ts` | Datadog 集成 | `trackDatadogEvent()`, 批量发送（100条/15s）, 允许事件白名单 |
| `growthbook.ts` | GrowthBook | `getFeatureValue_CACHED_MAY_BE_STALE()`, `checkStatsigFeatureGate_CACHED_MAY_BE_STALE()`, A/B 测试 |
| `firstPartyEventLogger.ts` | 一阶方事件 | `logEventTo1P()`, `shouldSampleEvent()`, 实验曝光日志 |
| `firstPartyEventLoggingExporter.ts` | 事件导出 | 一阶方事件导出器 |
| `metadata.ts` | 事件元数据 | `getEventMetadata()`, 平台/模型/版本信息 |
| `config.ts` | 配置 | `isAnalyticsDisabled()`, 分析开关 |
| `sinkKillswitch.ts` | 杀开关 | `isSinkKilled()`, 紧急关闭特定 sink |

**设计特点：**
- **零依赖设计**：`index.ts` 无任何外部依赖，避免循环引用
- **事件排队**：sink 未初始化前事件入队，attach 后批量消费
- **PII 保护**：`_PROTO_*` 前缀字段仅 1P exporter 可见，Datadog 自动过滤
- **GrowthBook 集成**：远程特性评估，支持 targeting（用户属性/订阅类型/平台）

---

### 2.6 `compact/` — 上下文压缩

**职责：** 当上下文窗口接近上限时自动压缩对话历史。

**关键文件与接口：**

| 文件 | 功能 | 对外接口 |
|------|------|----------|
| `compact.ts` | 核心压缩 | `compactConversation()`, 将对话历史压缩为摘要 |
| `autoCompact.ts` | 自动压缩 | `isAutoCompactEnabled()`, 基于 token 阈值触发 |
| `microCompact.ts` | 微压缩 | 时间基微压缩，清理旧工具结果，保留最近内容 |
| `apiMicrocompact.ts` | API 微压缩 | 基于 API 的微压缩策略 |
| `sessionMemoryCompact.ts` | 会话记忆压缩 | 压缩时更新会话记忆 |
| `grouping.ts` | 消息分组 | 将消息按主题分组以优化压缩 |
| `compactWarningHook.ts` | 压缩警告 | 接近上限时的用户警告 hook |
| `compactWarningState.ts` | 警告状态 | 警告抑制/清除状态管理 |
| `postCompactCleanup.ts` | 压缩后清理 | 压缩后的资源清理 |
| `prompt.ts` | 压缩提示 | 压缩摘要的 prompt 构建 |
| `timeBasedMCConfig.ts` | 时间配置 | 微压缩的时间阈值配置 |

**压缩策略层次：**
1. **微压缩 (Micro-compact)**：清理旧工具结果内容，替换为 stub
2. **API 微压缩**：通过 API 端点执行微压缩
3. **自动压缩 (Auto-compact)**：当 token 用量超过阈值时触发完整压缩
4. **会话记忆压缩**：压缩时同步更新会话记忆文件

**关键常量：**
- `MAX_OUTPUT_TOKENS_FOR_SUMMARY = 20,000`
- `CAPPED_DEFAULT_MAX_TOKENS` — 模型最大输出
- 上下文窗口 = 模型窗口 - 预留压缩输出空间

---

### 2.7 `plugins/` — 插件系统

**职责：** 后台插件安装、市场管理、CLI 命令处理。

**关键文件与接口：**

| 文件 | 功能 | 对外接口 |
|------|------|----------|
| `PluginInstallationManager.ts` | 后台安装管理 | `performBackgroundPluginInstallations()`, 市场 reconciliation |
| `pluginOperations.ts` | 插件操作 | 插件安装/卸载/更新操作 |
| `pluginCliCommands.ts` | CLI 命令 | `/plugin` 相关命令处理 |

**安装流程：**
1. 加载已知市场配置 (`loadKnownMarketplacesConfig`)
2. Diff 新旧市场 (`diffMarketplaces`)
3. Reconcile 市场 (`reconcileMarketplaces`)
4. 刷新活跃插件 (`refreshActivePlugins`)
5. 更新 AppState 安装状态

**依赖的工具层：**
- `utils/plugins/marketplaceManager.ts` — 市场管理
- `utils/plugins/pluginLoader.ts` — 插件加载
- `utils/plugins/reconciler.ts` — 市场协调
- `utils/plugins/refresh.ts` — 插件刷新
- `utils/plugins/mcpPluginIntegration.ts` — MCP 插件集成

---

## 3. 辅助服务分析

### 3.1 `tools/` — 工具执行层

| 文件 | 功能 |
|------|------|
| `toolExecution.ts` | 单工具执行，权限检查，hook 执行 |
| `toolOrchestration.ts` | 并发安全工具编排（read-only 并发，write 串行） |
| `StreamingToolExecutor.ts` | 流式工具执行器，实时处理到达的工具调用 |
| `toolHooks.ts` | Pre/post tool hook 执行，规则权限检查 |

**并发策略：**
- `isConcurrencySafe` 标记的工具（read-only）可并行执行
- 最大并发数由 `CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY` 控制（默认 10）
- 写操作必须串行执行

### 3.2 `settingsSync/` — 设置同步

- **方向**：交互式 CLI 上传 → 远程；CCR 下载 → 本地
- **增量同步**：只同步变更的条目
- **文件大小限制**：500KB/文件
- **重试**：最多 3 次，带退避

### 3.3 `remoteManagedSettings/` — 远程托管配置

- **目标用户**：Enterprise/C4E 和 Team 订阅者
- **设计**：Fail-open（失败不阻塞），ETag 缓存，后台轮询（1 小时间隔）
- **安全**：配置签名验证

### 3.4 `policyLimits/` — 策略限制

- **来源**：组织级 API 策略
- **行为**：禁用特定 CLI 功能
- **设计**：与 remoteManagedSettings 相同的 fail-open + ETag + 轮询模式

### 3.5 `teamMemorySync/` — 团队记忆同步

- **作用域**：per-repo（基于 git remote hash）
- **同步语义**：Server wins per-key；delta upload（只上传内容变更的 key）
- **安全**：secret scanner 扫描敏感信息

### 3.6 `SessionMemory/` — 会话记忆

- **机制**：forked subagent 后台运行，从对话中提取关键信息
- **输出**：Markdown 文件，持久化到项目记忆目录
- **触发**：注册到 post-sampling hook

### 3.7 `extractMemories/` — 记忆提取

- **时机**：每个完整 query loop 结束时（stop hook）
- **机制**：forked agent 共享父 prompt cache
- **输出**：`~/.claude/projects/<path>/memory/` 下的记忆文件

### 3.8 `autoDream/` — 记忆整合

- **触发条件**：时间门（小时）+ 会话积累数
- **机制**：forked subagent 执行 `/dream` prompt
- **锁机制**：`consolidationLock` 防止并发整合

### 3.9 `AgentSummary/` — 子代理摘要

- **频率**：每 ~30 秒
- **方式**：forked subagent 生成 3-5 词进度描述
- **用途**：协调器模式的 UI 展示

### 3.10 `PromptSuggestion/` — 提示建议

- **特性**：智能意图预测、推测执行（speculation）
- **控制**：GrowthBook feature gate + 环境变量覆盖

### 3.11 `MagicDocs/` — 自动文档

- **触发**：读取包含 `# MAGIC DOC: [title]` header 的文件
- **机制**：post-sampling hook 驱动后台更新

### 3.12 `tips/` — Spinner 提示

- **展示时机**：Spinner 等待期间
- **选择策略**：优先展示最久未展示的 tip

### 3.13 `toolUseSummary/` — 工具摘要

- **方式**：调用 Haiku 模型生成单行摘要
- **限制**：~30 字符截断（移动应用适配）

---

## 4. 服务间依赖关系

```
┌─────────────────────────────────────────────────────────────────┐
│                        用户界面层 (REPL/CLI)                       │
└───────────────────────────────┬─────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
┌───────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   tools/      │     │    compact/     │     │    plugins/     │
│ (工具执行层)   │     │ (上下文压缩)     │     │   (插件系统)     │
└───────┬───────┘     └────────┬────────┘     └────────┬────────┘
        │                      │                       │
        │    ┌─────────────────┼───────────────────────┘
        │    │                 │
        ▼    ▼                 ▼
┌──────────────────────────────────────────────────────────────────┐
│                          api/ (API 客户端层)                        │
│  client.ts → claude.ts → withRetry.ts → bootstrap.ts → usage.ts │
└──────────────────────────┬───────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│   oauth/     │   │    mcp/      │   │    lsp/      │
│ (OAuth认证)   │   │ (MCP协议)     │   │ (语言服务器)  │
└──────────────┘   └──────────────┘   └──────────────┘
        │                  │
        └──────────┬───────┘
                   │
                   ▼
        ┌──────────────────┐
        │   analytics/     │
        │ (分析 & 特性开关) │
        └──────────────────┘
```

### 核心依赖矩阵

| 下游服务 ↑ \ 下游依赖 → | api/ | oauth/ | analytics/ | mcp/ | lsp/ | compact/ | tools/ |
|--------------------------|------|--------|------------|------|------|----------|--------|
| **tools/**               | ✅   |        | ✅         | ✅   |      |          |        |
| **compact/**             | ✅   |        | ✅         |      |      |          |        |
| **plugins/**             | ✅   |        | ✅         | ✅   |      |          |        |
| **mcp/**                 | ✅   | ✅     | ✅         |      |      |          |        |
| **oauth/**               |      |        | ✅         |      |      |          |        |
| **lsp/**                 |      |        |            |      |      |          |        |
| **analytics/**           |      |        |            |      |      |          |        |
| **SessionMemory/**       | ✅   |        | ✅         |      |      | ✅       |        |
| **extractMemories/**     |      |        | ✅         |      |      |          |        |
| **autoDream/**           |      |        | ✅         |      |      |          |        |
| **settingsSync/**        | ✅   | ✅     | ✅         |      |      |          |        |
| **teamMemorySync/**      | ✅   | ✅     | ✅         |      |      |          |        |
| **remoteManagedSettings/**| ✅  | ✅     |            |      |      |          |        |
| **policyLimits/**        | ✅   | ✅     |            |      |      |          |        |
| **PromptSuggestion/**    | ✅   |        | ✅         |      |      |          |        |

### 关键依赖链

1. **api/ ← oauth/**: `client.ts` 调用 `checkAndRefreshOAuthTokenIfNeeded()`, `getClaudeAIOAuthTokens()`
2. **api/ ← analytics/**: `errors.ts` 调用 `logEvent()` 记录 API 错误
3. **mcp/ ← oauth/**: `auth.ts` 实现 MCP 服务器的独立 OAuth 流
4. **mcp/ ← analytics/**: 连接事件、工具调用事件日志
5. **compact/ ← api/**: `autoCompact.ts` 调用 `getMaxOutputTokensForModel()`
6. **compact/ ← analytics/**: `microCompact.ts` 记录压缩事件
7. **tools/ ← analytics/**: `toolExecution.ts` 记录工具执行元数据
8. **tools/ ← mcp/**: `toolExecution.ts` 调用 `isMcpTool()` 判断 MCP 工具
9. **settingsSync/ ← api/**: 使用 `withRetry` 和 OAuth 认证
10. **SessionMemory/ ← compact/**: `sessionMemory.ts` 检查 `isAutoCompactEnabled()`

### analytics/ 是全系统的横切关注点

`analytics/index.ts` 的 `logEvent()` 几乎被所有服务调用。它被设计为零依赖（无外部 import），通过事件队列 + sink 注入模式避免循环引用。

---

## 5. 架构设计模式

### 5.1 工厂函数 + 闭包（非类）

LSP、MCP 客户端等核心组件均使用工厂函数模式（`createLSPClient()`, `createLSPServerManager()`），通过闭包封装私有状态，避免 class 的 `this` 绑定问题。

### 5.2 Forked Agent 模式

多个服务（SessionMemory, extractMemories, autoDream, AgentSummary, PromptSuggestion）使用 `runForkedAgent()` 模式：
- 创建主对话的完美 fork
- 共享父级 prompt cache（CacheSafeParams）
- 通过 `canUseTool` 回调限制工具使用
- 在后台运行，不阻塞主对话

### 5.3 Hook 系统

服务间通过 hook 解耦：
- `postSamplingHooks` — 采样后 hook（SessionMemory, MagicDocs）
- `preCompactHooks` / `postCompactHooks` — 压缩前后 hook
- `preToolHooks` / `postToolHooks` — 工具调用前后 hook
- `stopHooks` — 停止时 hook（extractMemories）

### 5.4 Fail-Open 设计

企业级服务（remoteManagedSettings, policyLimits）均采用 fail-open 设计：
- API 失败不阻塞启动
- ETag 缓存减少网络请求
- 后台轮询更新（1 小时间隔）
- 最多 5 次重试 + 指数退避

### 5.5 Feature Gate 分层

```
环境变量 > GrowthBook feature gate > 默认值
```
- 环境变量覆盖一切（测试用）
- GrowthBook 远程评估（生产）
- 安全默认值

---

## 6. 数据流总结

### 启动流程

```
bootstrap.ts (获取客户端配置)
    ↓
remoteManagedSettings (拉取远程配置)
    ↓
policyLimits (拉取策略限制)
    ↓
oauth (验证/刷新 token)
    ↓
mcp/config (加载 MCP 服务器配置)
    ↓
lsp/manager (初始化语言服务器)
    ↓
analytics/sink (初始化事件路由)
    ↓
plugins/PluginInstallationManager (后台安装插件)
```

### 请求流程

```
用户输入
    ↓
compact/autoCompact (检查是否需要压缩)
    ↓
api/claude.ts (发送 API 请求, withRetry)
    ↓
tools/toolOrchestration (编排工具调用)
    ↓
  ┌─────────┴──────────┐
  │                    │
  ▼                    ▼
mcp/client.ts      tools/toolExecution.ts
(远程工具)          (本地工具)
  │                    │
  └─────────┬──────────┘
            │
            ▼
  analytics/logEvent (记录事件)
            │
            ▼
  SessionMemory / extractMemories (后台记忆更新)
```

---

*生成时间: 2026-03-31 | 基于 claude-code 源码分析*
