# Claude Code — 编译修复版

**[English](README.md)** | **[中文](README_CN.md)**

基于 2026-03-31 泄露的 Claude Code CLI 源码，修复所有缺失文件、断裂引用和运行时错误，使其可以正常编译运行。

---

## 项目背景

2026 年 3 月 31 日，Anthropic 的 Claude Code CLI 完整源码通过 npm 注册表中的 `.map` 文件泄露。原始泄露版本**无法编译** — 缺少 22+ 个源文件、存在断裂的内部引用、依赖 Anthropic 内部包、并使用了未发布的 Bun 特性（`bun:bundle`）。

本仓库修复了以上所有问题。最终效果：一条 `bun build` 命令即可生成可用的 ~23MB 单文件 bundle。

---

## 相比原始泄露版本的修改

### 补充的缺失源文件（22 个 stub）

泄露的源码引用了不存在的文件。已创建对应的 stub：

| 文件 | 用途 |
|------|------|
| `src/global.d.ts` | TypeScript 全局类型声明 |
| `src/utils/protectedNamespace.ts` | 命名空间保护 |
| `src/utils/useEffectEvent.ts` | React `useEffectEvent` polyfill |
| `src/entrypoints/sdk/coreTypes.generated.ts` | SDK 生成类型 |
| `src/entrypoints/sdk/runtimeTypes.ts` | SDK 运行时类型 |
| `src/entrypoints/sdk/toolTypes.ts` | SDK 工具类型 |
| `src/tools/REPLTool/REPLTool.ts` | REPL 工具 stub |
| `src/tools/SuggestBackgroundPRTool/` | PR 建议工具 stub |
| `src/tools/VerifyPlanExecutionTool/` | 计划验证工具 stub |
| `src/tools/WorkflowTool/` | 工作流工具 stub |
| `src/tools/TungstenTool/TungstenLiveMonitor.tsx` | Tungsten 监控 stub |
| `src/commands/agents-platform/` | Agent 平台命令 stub |
| `src/commands/assistant/` | 助手命令 stub |
| `src/components/agents/SnapshotUpdateDialog.tsx` | 快照对话框 stub |
| `src/assistant/AssistantSessionChooser.tsx` | 会话选择器 stub |
| `src/services/compact/snipCompact.ts` | 剪裁压缩 stub |
| `src/services/compact/cachedMicrocompact.ts` | 微压缩 stub |
| `src/services/contextCollapse/` | 上下文折叠 stub |
| `src/ink/devtools.ts` | 开发工具 stub |
| `src/skills/bundled/verify/` | 验证 skill stub |
| `src/utils/filePersistence/types.ts` | 文件持久化类型 stub |

### 源码修复

| 修复项 | 文件 | 说明 |
|--------|------|------|
| `useEffectEvent` 导入 | `src/components/tasks/BackgroundTasksDialog.tsx`, `src/state/AppState.tsx` | React 19 实验性 Hook 在 `react-reconciler@0.31` 中不可用 — 改为本地 polyfill |
| 版本检查跳过 | `src/utils/autoUpdater.ts` | `assertMinVersion()` 会访问 Anthropic 服务器 — 直接跳过 |
| 组织验证跳过 | `src/main.tsx` | `validateForceLoginOrg()` 需要 Anthropic 认证 — 注释掉 |
| 认证检查跳过 | `src/main.tsx` | 登录流程依赖 Anthropic OAuth — 启用自动执行 |
| `SandboxManager` 替换 | `node_modules/@anthropic-ai/sandbox-runtime/` | 将 14 个方法的 stub 替换为 [anthropic-experimental/sandbox-runtime](https://github.com/anthropic-experimental/sandbox-runtime) 的真实实现 |

### Bun 兼容 Shim

| 文件 | 用途 |
|------|------|
| `shims/macro.ts` | 提供 `MACRO` 全局变量（VERSION、BUILD_TIME 等）— 原本由 Anthropic 内部 Bun 构建注入 |
| `shims/bun-bundle.ts` | 提供 `feature()` 函数 — 替代 Anthropic 内部的 `bun:bundle` |

### 缺失依赖（补充 28 个包）

原始 `package.json` 不完整。已补充 28 个缺失依赖，包括 `@anthropic-ai/` 系列 SDK、OpenTelemetry 包和其他必要模块。

### 内部包处理

两个 Anthropic 内部包无法从 npm 安装：

- `@anthropic-ai/sandbox-runtime` — 已替换为[开源实现](https://github.com/anthropic-experimental/sandbox-runtime)
- `@ant/claude-for-chrome-mcp` — 已在 `node_modules/` 中创建 stub

---

## 快速开始

### 前置要求

- **Bun** 1.3+ — `curl -fsSL https://bun.sh/install | bash`
- **Node.js** 18+（可选，Bun 自带 npm）

### 编译

```bash
git clone https://github.com/roger2ai/Claude-Code-Compiled.git
cd Claude-Code-Compiled

# 安装依赖
bun install

# 修补 Commander.js（多字符短标志不支持）
# 详见 docs/BUILD.md §4.1 — 每次 bun install 后需重新应用

# 编译
bun build shims/macro.ts src/main.tsx --target=bun --outdir=./dist

# 合并为单文件
cat dist/shims/macro.js dist/src/main.js > dist/bundle.js
echo 'if (typeof main === "function") main().catch(e => { console.error(e); process.exit(1); });' >> dist/bundle.js
```

输出：`dist/bundle.js`（~23 MB，~5,750 模块，~300ms 编译时间）

### 运行

```bash
# 查看帮助（不需要 API key）
bun dist/bundle.js --help

# 交互式 REPL（需要真实终端 + API key）
export ANTHROPIC_API_KEY=你的密钥
bun dist/bundle.js

# 单次执行模式
bun dist/bundle.js -p "say hello"
```

---

## 项目结构

```
claude-code/
├── src/                  # 源码（~1,900 个 TypeScript 文件，512K+ 行）
│   ├── main.tsx          # CLI 入口
│   ├── QueryEngine.ts    # LLM 查询引擎
│   ├── Tool.ts           # 工具类型定义
│   ├── tools/            # 43 个工具实现
│   ├── commands/         # 80+ 个斜杠命令
│   ├── components/       # 346 个 React/Ink UI 组件
│   ├── services/         # 21 个服务模块
│   ├── screens/          # 全屏 UI（REPL、Doctor 等）
│   └── utils/            # 290+ 个工具函数文件
├── shims/                # Bun 兼容 shim
├── docs/                 # 架构与编译文档
├── dist/                 # 编译输出（gitignored）
└── package.json          # 依赖声明（574 个包）
```

---

## 文档

| 文档 | 内容 |
|------|------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 全景架构总览 |
| [docs/ARCHITECTURE-TOOLS.md](docs/ARCHITECTURE-TOOLS.md) | 43 个工具详细分析 |
| [docs/ARCHITECTURE-SERVICES.md](docs/ARCHITECTURE-SERVICES.md) | 21 个服务模块 |
| [docs/ARCHITECTURE-COMPONENTS.md](docs/ARCHITECTURE-COMPONENTS.md) | 346 个 UI 组件 |
| [docs/ARCHITECTURE-COMMANDS.md](docs/ARCHITECTURE-COMMANDS.md) | 命令、Skill、Plugin |
| [docs/ARCHITECTURE-UTILS.md](docs/ARCHITECTURE-UTILS.md) | 工具函数层 |
| [docs/ARCHITECTURE-BRIDGE-REMOTE.md](docs/ARCHITECTURE-BRIDGE-REMOTE.md) | IDE 桥接与远程会话 |
| [docs/API-CONFIG.md](docs/API-CONFIG.md) | API 配置（环境变量、认证、代理） |
| [docs/BUILD.md](docs/BUILD.md) | 详细编译指南与所有补丁 |
| [docs/REFACTORING-ASSESSMENT.md](docs/REFACTORING-ASSESSMENT.md) | 重构可行性评估 |

---

## 功能完备性

### 核心工具 — 全部正常 ✅

| 工具 | 用途 |
|------|------|
| BashTool | 命令行执行 |
| FileReadTool | 文件读取（图片、PDF、Notebook） |
| FileWriteTool | 文件创建/覆盖 |
| FileEditTool | 文件局部修改 |
| GlobTool | 文件模式匹配 |
| GrepTool | ripgrep 内容搜索 |
| WebFetchTool | URL 内容抓取 |
| WebSearchTool | 网页搜索 |
| AgentTool | 子 Agent 调用 |
| SkillTool | Skill 执行 |
| NotebookEditTool | Jupyter Notebook 编辑 |
| AskUserQuestionTool | 交互式提问 |
| MCPTool | MCP 服务器工具调用 |
| ListMcpResourcesTool / ReadMcpResourceTool | MCP 资源访问 |

### 有条件启用的工具

| 工具 | 启用条件 | 状态 |
|------|----------|------|
| LSPTool | 设置 `ENABLE_LSP_TOOL=true` | ✅ 可用 |
| PowerShellTool | Windows 环境 | ✅ 可用 |
| EnterWorktreeTool / ExitWorktreeTool | 配置开启 | ✅ 可用 |
| TaskCreateTool 等 4 个 | 配置开启 | ✅ 可用 |
| TeamCreateTool / TeamDeleteTool | Agent Swarms 配置 | ✅ 可用 |
| ToolSearchTool | 配置开启 | ✅ 可用 |

### 关闭的内部功能（80+ 个 feature flag）

以下 Anthropic 内部实验性功能通过 `feature()` 标志关闭，不影响核心 CLI 使用：

| 功能 | 影响 |
|------|------|
| Voice Mode（`VOICE_MODE`） | 语音输入不可用 |
| Proactive Mode（`PROACTIVE`） | SleepTool、主动提醒不可用 |
| Agent Swarms（`TEAMMEM`、`BG_SESSIONS`） | 多 Agent 协调不可用 |
| Cron 调度（`AGENT_TRIGGERS`） | 定时触发器不可用 |
| Computer Use（`CHICAGO_MCP`） | 桌面自动化不可用 — 需要 Anthropic 内部原生模块 |
| Claude in Chrome（`CHICAGO_MCP`） | 浏览器集成不可用 |
| KAIROS（`KAIROS`） | Anthropic 内部助手模式不可用 |
| Transcript Classifier（`TRANSCRIPT_CLASSIFIER`） | 自动权限分类不可用 |

### Stub 工具（自动过滤，零运行时影响）

| 工具 | 原因 |
|------|------|
| REPLTool | `USER_TYPE=ant` 条件不满足 |
| SuggestBackgroundPRTool | `USER_TYPE=ant` 条件不满足 |
| VerifyPlanExecutionTool | `CLAUDE_CODE_VERIFY_PLAN` 未设置 |
| WorkflowTool | `feature('WORKFLOW_SCRIPTS')` 返回 false |
| TungstenTool | `USER_TYPE=ant` 条件不满足 |

### 缺失的内部包（无运行时影响）

所有 `@ant/*` 包引用都在 `feature()` 守卫的 dead code 分支内，编译时被完全剔除：

| 包 | 用途 | 影响 |
|------|------|------|
| `@ant/claude-for-chrome-mcp` | Chrome 浏览器 MCP | 无 — dead code |
| `@ant/computer-use-mcp` | Computer Use MCP | 无 — dead code |
| `@ant/computer-use-input` | 鼠标/键盘控制 | 无 — dead code |
| `@ant/computer-use-swift` | macOS 原生截图 | 无 — dead code |
| `@anthropic-ai/claude-agent-sdk` | SDK 类型引用 | 无 — 仅 `import type` |

**总结：所有核心 CLI 功能（文件操作、命令执行、搜索、API 调用、MCP 集成）均可正常使用。缺失的功能均为 Anthropic 内部实验性功能，在官方公开版本中同样不存在。**

---

## 已知限制

1. **TUI 需要真实终端** — 管道或非 TTY 环境下静默退出
2. **需要 API key** — 实际对话必须设置 `ANTHROPIC_API_KEY`
3. **macOS Keychain** — Linux 上回退到明文文件存储
4. **WSL2 沙箱** — 需要 `apt install bubblewrap socat` 才能使用沙箱功能
5. **Commander.js 补丁** — 多字符短标志（`-d2e`）每次 `bun install` 后需手动修补 `node_modules`

---

## 原始来源

源码由 [@Fried_rice](https://x.com/Fried_rice) 于 2026-03-31 泄露。所有原始源码归 [Anthropic](https://www.anthropic.com) 所有。本仓库仅作为可编译参考，不用于生产环境。
