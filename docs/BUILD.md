# Claude Code 编译与运行指南

> 基于 2026-03-31 泄露的 Claude Code CLI 源码
> 最后更新：2026-04-01

---

## 1. 前置条件

### 1.1 必须安装

| 工具 | 版本 | 安装命令 |
|------|------|----------|
| **Bun** | 1.3+ | `curl -fsSL https://bun.sh/install \| bash` |
| **Node.js** | 18+ | 已有则跳过（Bun 自带 npm） |

### 1.2 验证安装

```bash
bun --version   # 应输出 1.x.x
node --version  # 应输出 v18+ 或 v22+
```

### 1.3 工作目录

所有命令在以下目录执行：

```bash
cd ~/.openclaw/workspace/claude-code
```

---

## 2. 项目结构概览

```
claude-code/
├── src/                    # 源码（1,886 个 TypeScript 文件）
│   ├── main.tsx            # CLI 入口（4,683 行）
│   ├── QueryEngine.ts      # LLM 查询引擎（1,295 行）
│   ├── Tool.ts             # 工具接口定义（792 行）
│   ├── commands.ts         # 命令注册（754 行）
│   ├── tools.ts            # 工具注册（389 行）
│   ├── screens/            # 全屏 UI（REPL.tsx 5,005 行）
│   ├── components/         # React 组件（346 个）
│   ├── tools/              # 工具实现（42 个目录）
│   ├── services/           # 服务层（21 个子目录）
│   ├── commands/           # 斜杠命令（80+ 个）
│   ├── utils/              # 工具函数（290+ 文件, 88K 行）
│   ├── hooks/              # React hooks（104 个）
│   ├── bridge/             # IDE 桥接（31 文件）
│   └── ink/                # 自定义 Ink 渲染器（96 文件）
├── shims/                  # 编译 shim
│   ├── bun-bundle.ts       # bun:bundle feature() 替代
│   └── macro.ts            # MACRO 全局变量注入
├── dist/                   # 编译输出
├── ARCHITECTURE*.md        # 架构文档（7 份）
└── package.json            # 依赖声明
```

---

## 3. 缺失文件与修复

泄露的源码不完整。以下是编译前必须补充的内容：

### 3.1 缺失的源文件（22 个 stub）

这些文件在 `src/` 下，是内部工具引用但泄露包中不存在的：

| 文件 | 用途 |
|------|------|
| `src/global.d.ts` | TypeScript 全局类型声明 |
| `src/utils/protectedNamespace.ts` | 命名空间保护检查 |
| `src/utils/useEffectEvent.ts` | React useEffectEvent shim |
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

这些 stub 已经在仓库中，编译时会自动包含。

### 3.2 缺失的 npm 包

泄露的 `package.json` 缺少 28 个依赖。运行以下命令安装：

```bash
bun install
```

这会安装 `package.json` 中声明的所有依赖（已补充完整）。

### 3.3 内部 Anthropic 包（stub）

以下两个包是 Anthropic 内部包，无法从 npm 安装：

- `@ant/claude-for-chrome-mcp` — Chrome 集成 MCP
- `@anthropic-ai/sandbox-runtime` — 沙箱运行时

它们在 `node_modules/` 中以 stub 形式存在（已创建）。

---

## 4. 需要修改的源码

### 4.1 Commander.js 短标志

原代码使用 `-d2e` 这种多字符短标志，Commander.js 不支持。

**修改文件**：`node_modules/commander/lib/option.js`

```javascript
// 原代码
const shortFlagExp = /^-[^-]$/;

// 修改为（允许任意长度短标志）
const shortFlagExp = /^-[^-]+$/;
```

> ⚠️ 修改的是 `node_modules/` 中的文件。每次 `bun install` 后需要重新修改。建议创建 postinstall 脚本自动 patch。

### 4.2 MACRO 全局变量

原代码使用 `MACRO.VERSION` 等全局变量，Bun 编译时会自动注入。开源版本没有这个机制。

**创建文件**：`shims/macro.ts`

```typescript
globalThis.MACRO = {
  VERSION: "1.0.0",
  BUILD_TIME: undefined,
  ISSUES_EXPLAINER: "https://github.com/anthropics/claude-code/issues",
  FEEDBACK_CHANNEL: "#claude-code-feedback",
  NATIVE_PACKAGE_URL: "https://claude.ai/download",
  PACKAGE_URL: "https://www.npmjs.com/package/@anthropic-ai/claude-code",
  VERSION_CHANGELOG: "https://github.com/anthropics/claude-code/releases",
};
```

编译时作为额外入口点注入。

### 4.3 bun:bundle feature()

原代码使用 `import { feature } from 'bun:bundle'` 实现编译时死码消除。开源 Bun 没有这个功能。

**创建文件**：`shims/bun-bundle.ts`

```typescript
export function feature(name: string): boolean {
  const flags: Record<string, boolean> = {
    WORKFLOW_SCRIPTS: false,
    AGENT_TRIGGERS: false,
    // ... 其他 flag 默认 false
  };
  return flags[name] ?? false;
}
```

Bun 的 `bunfig.toml` 配置了 `.js` → `.ts` 的 loader 映射，会自动解析这个 shim。

### 4.4 useEffectEvent 兼容

代码使用了 React 19 实验性 Hook `useEffectEvent`，但 `react-reconciler@0.31` 不支持。

**创建文件**：`src/utils/useEffectEvent.ts`

```typescript
import { useCallback, useRef } from 'react';

export function useEffectEvent<T extends (...args: any[]) => any>(callback: T): T {
  const ref = useRef(callback);
  ref.current = callback;
  return useCallback(((...args: any[]) => ref.current(...args)) as T, []);
}
```

**修改**：`src/components/tasks/BackgroundTasksDialog.tsx` 和 `src/state/AppState.tsx` 中将 `import { ... useEffectEvent ... } from 'react'` 改为从 `../../utils/useEffectEvent.js` 导入。

### 4.5 版本检查跳过

原代码调用 `assertMinVersion()` 检查远程最低版本配置，会访问 Anthropic 服务器。

**修改文件**：`src/utils/autoUpdater.ts`

```typescript
export async function assertMinVersion(): Promise<void> {
  return;  // 直接返回，跳过检查
  // ... 原有代码
}
```

### 4.6 组织验证跳过

原代码调用 `validateForceLoginOrg()` 检查组织限制。

**修改文件**：`src/main.tsx`

注释掉两处 `validateForceLoginOrg` 调用（约第 2302 行和第 2614 行）：

```typescript
// const orgValidation = await validateForceLoginOrg();
// if (!orgValidation.valid) {
//   process.exit(1);
// }
```

---

## 5. 编译步骤

### 5.1 完整编译命令

```bash
cd ~/.openclaw/workspace/claude-code

# 1. 安装依赖
bun install

# 2. 编译 TypeScript → JavaScript bundle
bun build shims/macro.ts src/main.tsx --target=bun --outdir=./dist

# 3. 合并为单文件（macro shim + main bundle + auto-execute）
cat dist/shims/macro.js dist/src/main.js > dist/bundle.js
echo 'if (typeof main === "function") main().catch(e => { console.error(e); process.exit(1); });' >> dist/bundle.js
```

### 5.2 编译结果

```
Bundled 5745 modules in ~300ms
  dist/bundle.js  ~23 MB  (单文件可执行)
```

- **模块数**：5,745（含源码 + 依赖）
- **文件大小**：~23 MB
- **编译时间**：~300ms
- **输出**：`dist/bundle.js`（单文件）

### 5.3 一键编译脚本

```bash
#!/bin/bash
set -e
cd ~/.openclaw/workspace/claude-code

echo "Building..."
bun build shims/macro.ts src/main.tsx --target=bun --outdir=./dist 2>&1

echo "Bundling..."
cat dist/shims/macro.js dist/src/main.js > dist/bundle.js
echo 'if (typeof main === "function") main().catch(e => { console.error(e); process.exit(1); });' >> dist/bundle.js

echo "Done: $(ls -lh dist/bundle.js | awk '{print $5}')"
```

---

## 6. 运行

### 6.1 基本用法

```bash
# 查看帮助（不需要 API key）
bun dist/bundle.js --help

# 查看 MCP 子命令帮助
bun dist/bundle.js mcp --help

# 查看版本
bun dist/bundle.js --version
```

### 6.2 交互模式（需要真实终端）

```bash
# 进入 REPL 交互界面
bun dist/bundle.js
```

会显示：
1. **信任对话框** — 确认信任当前目录
2. **欢迎界面** — Logo + 版本信息
3. **REPL 输入框** — 等待输入

### 6.3 非交互模式（-p）

```bash
# 需要 API key
export ANTHROPIC_API_KEY=你的密钥
bun dist/bundle.js -p "say hello"
```

### 6.4 配置管理

```bash
# 添加 MCP 服务器
bun dist/bundle.js mcp add myserver http://localhost:3000

# 查看配置
bun dist/bundle.js config

# 查看已添加的 MCP 服务器
bun dist/bundle.js mcp list
```

---

## 7. 文档索引

### 7.1 API 配置

完整的 API 配置指南（环境变量、认证方式、多云后端、代理、mTLS）：

→ **[API-CONFIG.md](./API-CONFIG.md)**

### 7.2 架构文档

项目包含 8 份架构分析文档：

| 文档 | 大小 | 内容 |
|------|------|------|
| `ARCHITECTURE.md` | 20KB | 全景架构总览 |
| `ARCHITECTURE-TOOLS.md` | 24KB | 43 个工具详细分析 |
| `ARCHITECTURE-SERVICES.md` | 28KB | 21 个服务详细分析 |
| `ARCHITECTURE-COMPONENTS.md` | 28KB | 389 个组件分析 |
| `ARCHITECTURE-COMMANDS.md` | 24KB | 60+ 命令/Skill/Plugin |
| `ARCHITECTURE-UTILS.md` | 12KB | 290+ 工具文件 |
| `ARCHITECTURE-BRIDGE-REMOTE.md` | 12KB | Bridge/Remote/Coordinator |
| `REFACTORING-ASSESSMENT.md` | 12KB | 重构可行性评估 |
| **`API-CONFIG.md`** | **10KB** | **API 配置完整参考** |

---

## 8. 已知问题

1. **TUI 需要真实终端** — SSH 管道或非 TTY 环境下会静默退出
2. **API 调用需要密钥** — 没有 `ANTHROPIC_API_KEY` 时发送消息会失败
3. **部分功能为 stub** — REPLTool、WorkflowTool 等是空实现
4. **macOS Keychain** — 安全存储在 Linux 上回退到明文文件
5. **Windows 支持** — PowerShell 工具需要 Windows 环境测试
