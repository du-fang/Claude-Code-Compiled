# Claude Code 命令系统架构

> 基于 `claude-code` 源码分析 (`/src/commands/`, `commands.ts`, `skills/`, `plugins/`, `keybindings/`)

---

## 1. Command 类型系统

命令定义在 `src/types/command.ts`，核心类型为：

```typescript
type Command = CommandBase & (PromptCommand | LocalCommand | LocalJSXCommand)
```

### 三种命令类型

| 类型 | 说明 | 用途 |
|------|------|------|
| `prompt` | 展开为一段 prompt 发送给模型 | Skill 型命令，如 `/commit`, `/review`, `/init` |
| `local` | 本地执行，返回文本结果 | 不需要 UI 的命令，如 `/compact` |
| `local-jsx` | 本地执行，渲染 React/Ink UI 组件 | 需要交互式界面的命令，如 `/config`, `/mcp`, `/doctor` |

### CommandBase 通用属性

```typescript
type CommandBase = {
  name: string
  description: string
  aliases?: string[]
  type: 'prompt' | 'local' | 'local-jsx'
  isEnabled?: () => boolean       // 条件启用（feature flags、env check）
  isHidden?: boolean              // 是否从自动完成/帮助中隐藏
  availability?: CommandAvailability[] // 认证要求 ('claude-ai' | 'console')
  argumentHint?: string           // 参数提示文字
  whenToUse?: string              // 详细的使用场景说明
  version?: string
  disableModelInvocation?: boolean // 禁止模型调用
  userInvocable?: boolean
  loadedFrom?: 'skills' | 'plugin' | 'managed' | 'bundled' | 'mcp' | 'commands_DEPRECATED'
  kind?: 'workflow'
  immediate?: boolean             // 立即执行，不等待队列
  isSensitive?: boolean           // 参数脱敏
  source?: 'builtin' | 'plugin' | 'bundled' | 'mcp'
}
```

### PromptCommand

```typescript
type PromptCommand = {
  type: 'prompt'
  source: 'builtin' | 'plugin' | 'bundled' | 'mcp'
  progressMessage: string
  contentLength: number  // 0 = 动态内容
  allowedTools?: string[]
  getPromptForCommand: (args, context) => Promise<ContentBlockParam[]>
}
```

### LocalCommand

```typescript
type LocalCommand = {
  type: 'local'
  supportsNonInteractive?: boolean
  call: LocalCommandCall  // (args, context) => Promise<LocalCommandResult>
}
```

### LocalJSXCommand

```typescript
type LocalJSXCommand = {
  type: 'local-jsx'
  load: () => Promise<{ call: LocalJSXCommandCall }>
}
```

---

## 2. 命令注册机制

### 主入口：`src/commands.ts`

所有内置命令在 `src/commands.ts` 中以 **静态 import** 方式导入，然后通过 `COMMANDS()` memoize 函数组装。

```typescript
// commands.ts 中的核心结构
const COMMANDS = memoize((): Command[] => [
  addDir, advisor, agents, branch, btw, chrome, clear, color,
  compact, config, copy, desktop, context, cost, diff, doctor,
  effort, exit, fast, files, heapDump, help, ide, init, keybindings,
  mcp, memory, mobile, model, outputStyle, plugin, resume, session,
  skills, status, theme, review, ultrareview, ...,
  // 条件命令
  ...(webCmd ? [webCmd] : []),
  ...(buddy ? [buddy] : []),
  ...(bridge ? [bridge] : []),
  ...(voiceCommand ? [voiceCommand] : []),
  // 内部命令（仅 ant 用户）
  ...(process.env.USER_TYPE === 'ant' ? INTERNAL_ONLY_COMMANDS : []),
])
```

### 命令发现层次（5 层叠加）

`getCommands(cwd)` 按以下优先级组装最终命令列表：

```
1. bundledSkills         — 内置捆绑 Skills（registerBundledSkill 注册）
2. builtinPluginSkills   — 内置插件提供的 Skills
3. skillDirCommands      — 项目/用户 skills/ 目录中发现的 Markdown Skills
4. workflowCommands      — Workflow 脚本生成的命令
5. pluginCommands        — 第三方插件提供的命令
6. pluginSkills          — 插件提供的 Skills
7. COMMANDS()            — 内置命令（最高优先级，覆盖前面同名命令）
```

```typescript
export async function getCommands(cwd: string): Promise<Command[]> {
  const allCommands = await loadAllCommands(cwd)
  // 过滤：availability + isEnabled
  const baseCommands = allCommands.filter(
    _ => meetsAvailabilityRequirement(_) && isCommandEnabled(_),
  )
  // 动态 Skills 插入到 plugin skills 之后、builtin 之前
  // ...
}
```

### 加载来源（loadedFrom 枚举）

| 值 | 含义 |
|---|------|
| `skills` | 从 `skills/` 目录加载的 Markdown Skill |
| `plugin` | 从插件加载 |
| `managed` | 托管路径加载 |
| `bundled` | 随 CLI 捆绑的内置 Skill |
| `mcp` | MCP 服务器提供的 Skill |
| `commands_DEPRECATED` | 旧版 `commands/` 目录（已废弃） |

---

## 3. 全部命令清单

### 3.1 内置斜杠命令（60+）

按目录列出：

| 命令 | 目录 | 类型 | 说明 |
|------|------|------|------|
| `/add-dir` | `add-dir/` | local-jsx | 添加额外工作目录 |
| `/agents` | `agents/` | local-jsx | 多 agent 管理 |
| `/branch` | `branch/` | local | 分支操作 |
| `/btw` | `btw/` | local-jsx | 快速笔记 |
| `/chrome` | `chrome/` | local-jsx | Chrome 浏览器集成 |
| `/clear` | `clear/` | local | 清空对话 |
| `/color` | `color/` | local | 切换 agent 颜色 |
| `/compact` | `compact/` | local | 压缩对话历史（保留摘要） |
| `/config` | `config/` | local-jsx | 打开配置面板 (aliases: `settings`) |
| `/copy` | `copy/` | local-jsx | 复制最后一条消息 |
| `/cost` | `cost/` | local-jsx | 显示会话费用 |
| `/desktop` | `desktop/` | local-jsx | 桌面应用集成 |
| `/diff` | `diff/` | local-jsx | 查看代码差异 |
| `/doctor` | `doctor/` | local-jsx | 诊断安装和配置 |
| `/effort` | `effort/` | local-jsx | 设置推理努力级别 |
| `/exit` | `exit/` | local-jsx | 退出 REPL (aliases: `quit`) |
| `/export` | `export/` | local-jsx | 导出会话 |
| `/extra-usage` | `extra-usage/` | local-jsx | 额外使用量报告 |
| `/fast` | `fast/` | local-jsx | 快速模式切换 |
| `/feedback` | `feedback/` | local-jsx | 发送反馈 |
| `/files` | `files/` | local | 列出跟踪文件 |
| `/heapdump` | `heapdump/` | local | 堆转储（调试用） |
| `/help` | `help/` | local-jsx | 显示帮助和可用命令 |
| `/hooks` | `hooks/` | local-jsx | 管理 hooks |
| `/ide` | `ide/` | local-jsx | IDE 集成 |
| `/init` | `init.ts` | prompt | 初始化 CLAUDE.md |
| `/install` | `install.tsx` | local-jsx | 安装配置 |
| `/install-github-app` | `install-github-app/` | local-jsx | 安装 GitHub App |
| `/install-slack-app` | `install-slack-app/` | local-jsx | 安装 Slack App |
| `/keybindings` | `keybindings/` | local | 管理键绑定 |
| `/login` | `login/` | local-jsx | 登录 Anthropic 账号 |
| `/logout` | `logout/` | local-jsx | 登出 |
| `/mcp` | `mcp/` | local-jsx | 管理 MCP 服务器 |
| `/memory` | `memory/` | local-jsx | 管理记忆文件 |
| `/mobile` | `mobile/` | local-jsx | 移动端 QR 码 |
| `/model` | `model/` | local-jsx | 设置 AI 模型 |
| `/output-style` | `output-style/` | local-jsx | 输出样式 |
| `/passes` | `passes/` | local-jsx | 通行证管理 |
| `/permissions` | `permissions/` | local-jsx | 权限管理 |
| `/plan` | `plan/` | local-jsx | 计划模式 |
| `/plugin` | `plugin/` | local-jsx | 插件管理 |
| `/privacy-settings` | `privacy-settings/` | local-jsx | 隐私设置 |
| `/rate-limit-options` | `rate-limit-options/` | local-jsx | 速率限制选项 |
| `/release-notes` | `release-notes/` | local | 显示版本说明 |
| `/reload-plugins` | `reload-plugins/` | local | 重新加载插件 |
| `/remote-env` | `remote-env/` | local-jsx | 远程环境 |
| `/rename` | `rename/` | local | 重命名会话 |
| `/resume` | `resume/` | local-jsx | 恢复会话 |
| `/rewind` | `rewind/` | local-jsx | 回退对话 |
| `/sandbox-toggle` | `sandbox-toggle/` | local-jsx | 沙箱切换 |
| `/session` | `session/` | local-jsx | 会话管理 |
| `/skills` | `skills/` | local-jsx | Skills 管理 |
| `/stats` | `stats/` | local-jsx | 统计信息 |
| `/status` | `status/` | local-jsx | 显示状态（版本、模型、账号等） |
| `/stickers` | `stickers/` | local | 贴纸 |
| `/tag` | `tag/` | local-jsx | 标签管理 |
| `/tasks` | `tasks/` | local-jsx | 任务管理 |
| `/terminalSetup` | `terminalSetup/` | local-jsx | 终端设置 |
| `/theme` | `theme/` | local-jsx | 切换主题 |
| `/thinkback` | `thinkback/` | local-jsx | Thinkback 功能 |
| `/thinkback-play` | `thinkback-play/` | local-jsx | Thinkback 播放 |
| `/upgrade` | `upgrade/` | local-jsx | 升级 |
| `/usage` | `usage/` | local-jsx | 使用量 |
| `/vim` | `vim/` | local | Vim 模式切换 |

### 3.2 Prompt 型命令

| 命令 | 文件 | 说明 |
|------|------|------|
| `/commit` | `commit.ts` | 创建 git commit（展开为 prompt 让模型执行） |
| `/review` | `review.ts` | Review PR（本地 prompt 模式） |
| `/init` | `init.ts` | 分析代码库创建 CLAUDE.md |
| `/advisor` | `advisor.ts` | 提供建议 |
| `/security-review` | `security-review.ts` | 安全审查 |
| `/insights` | (lazy import) | 会话分析报告（113KB 大模块，懒加载） |

### 3.3 条件命令（Feature Flag 门控）

```typescript
// 基于 bun:bundle feature flags
const proactive = feature('PROACTIVE') || feature('KAIROS') ? ... : null
const briefCommand = feature('KAIROS') || feature('KAIROS_BRIEF') ? ... : null
const assistantCommand = feature('KAIROS') ? ... : null
const bridge = feature('BRIDGE_MODE') ? ... : null
const voiceCommand = feature('VOICE_MODE') ? ... : null
const workflowsCmd = feature('WORKFLOW_SCRIPTS') ? ... : null
const webCmd = feature('CCR_REMOTE_SETUP') ? ... : null
const ultraplan = feature('ULTRAPLAN') ? ... : null
const torch = feature('TORCH') ? ... : null
const peersCmd = feature('UDS_INBOX') ? ... : null
const forkCmd = feature('FORK_SUBAGENT') ? ... : null
const buddy = feature('BUDDY') ? ... : null
```

---

## 4. 核心命令详细分析

### `/commit` — Git Commit

**文件**: `src/commands/commit.ts`  
**类型**: `prompt`  
**源**: `builtin`

**机制**:
- 展开为一段 prompt，注入当前 `git status`、`git diff HEAD`、`git log` 信息
- 模型分析变更并执行 `git add` + `git commit`
- 限制允许的工具：`Bash(git add:*)`, `Bash(git status:*)`, `Bash(git commit:*)`
- 使用 HEREDOC 语法创建 commit message
- 内置安全协议：禁止 `--amend`、禁止跳过 hooks、禁止提交包含密钥的文件

### `/review` — PR Review

**文件**: `src/review.ts`  
**类型**: `prompt` (本地) + `local-jsx` (ultrareview)  
**源**: `builtin`

**机制**:
- `/review`：本地 prompt 模式，使用 `gh` CLI 查看 PR、获取 diff、生成代码审查
- `/ultrareview`：`local-jsx` 类型，远程 Claude Code on the Web 模式
- `ultrareview` 有 `isEnabled()` 检查，受功能开关控制
- 超出免费额度时弹出 overage dialog (`UltrareviewOverageDialog.tsx`)

### `/compact` — 压缩对话

**文件**: `src/commands/compact/index.ts` + `compact.ts`  
**类型**: `local`  
**源**: `builtin`

**机制**:
- 调用 `compactConversation()` 服务压缩对话历史
- 支持自定义压缩指令：`/compact [instructions]`
- 支持 session memory compaction（无自定义指令时优先）
- 支持 microcompact（短对话）
- 支持 reactive compact（feature flag）
- 运行 post-compact cleanup 和 pre-compact hooks
- `supportsNonInteractive: true`

### `/config` — 配置面板

**文件**: `src/commands/config/index.ts` + `config.tsx`  
**类型**: `local-jsx`  
**别名**: `settings`

**机制**:
- 懒加载 React/Ink UI 组件
- 渲染交互式配置界面

### `/mcp` — MCP 服务器管理

**文件**: `src/commands/mcp/index.ts` + `mcp.tsx`, `addCommand.ts`, `xaaIdpCommand.ts`  
**类型**: `local-jsx`  
**源**: `builtin`

**机制**:
- `immediate: true` — 立即执行不等待队列
- 支持子命令：`enable`, `disable`
- UI 组件管理 MCP server 的增删改查

### `/login` — 登录

**文件**: `src/commands/login/index.ts` + `login.tsx`  
**类型**: `local-jsx`  
**源**: `builtin`

**机制**:
- 动态 description：根据当前认证状态显示不同文字
- 使用工厂函数 `export default () => ({...})` — 可延迟评估 `hasAnthropicApiKeyAuth()`
- 有 `isEnabled()` 检查：`DISABLE_LOGIN_COMMAND` 环境变量可禁用
- 只在非 3P 服务模式下出现（在 `COMMANDS()` 中条件包含）

### `/doctor` — 诊断

**文件**: `src/commands/doctor/index.ts` + `doctor.tsx`  
**类型**: `local-jsx`  
**源**: `builtin`

**机制**:
- 诊断安装和设置
- `DISABLE_DOCTOR_COMMAND` 环境变量可禁用

### `/status` — 状态

**文件**: `src/commands/status/index.ts` + `status.tsx`  
**类型**: `local-jsx`  
**源**: `builtin`

**机制**:
- `immediate: true`
- 显示版本、模型、账号、API 连通性、工具状态

### `/help` — 帮助

**文件**: `src/commands/help/index.ts` + `help.tsx`  
**类型**: `local-jsx`

---

## 5. 命令目录结构模式

### 标准模式（目录型）

```
commands/<command-name>/
├── index.ts          # 导出 Command 定义（类型、名称、描述、load 函数）
├── <command-name>.tsx  # 实现文件（local-jsx 型通常为 .tsx，local 型为 .ts）
└── ...辅助文件
```

`index.ts` 的典型结构：

```typescript
import type { Command } from '../../commands.js'

const myCommand = {
  type: 'local-jsx',       // 或 'local' 或 'prompt'
  name: 'mycommand',
  description: 'Description text',
  load: () => import('./mycommand.js'),  // 懒加载实现
  // prompt 型需要 getPromptForCommand
  // local 型需要 call
} satisfies Command

export default myCommand
```

### 简单模式（单文件型）

```
commands/
├── commit.ts         # 单文件导出 Command（prompt 型常见）
├── advisor.ts
├── security-review.ts
├── version.ts
├── brief.ts
└── init.ts
```

这些直接在 `commands.ts` 中 import，没有独立目录。

### 复杂模式（多子文件型）

```
commands/plugin/           # 最复杂的命令之一
├── index.tsx
├── plugin.tsx
├── parseArgs.ts
├── ValidatePlugin.tsx
├── DiscoverPlugins.tsx
├── BrowseMarketplace.tsx
├── AddMarketplace.tsx
├── ManagePlugins.tsx
├── ManageMarketplaces.tsx
├── PluginOptionsFlow.tsx
├── PluginOptionsDialog.tsx
├── PluginSettings.tsx
├── PluginTrustWarning.tsx
├── PluginErrors.tsx
├── pluginDetailsHelpers.tsx
├── UnifiedInstalledCell.tsx
└── usePagination.ts
```

---

## 6. Skill 系统

### 目录结构

```
src/skills/
├── index.ts              # 入口（可能调用 registerBundledSkill）
├── bundledSkills.ts      # 注册捆绑 Skill 的 API
├── loadSkillsDir.ts      # 从文件系统发现 Skill（1007 行）
├── mcpSkillBuilders.ts   # 从 MCP 注册 Skill
└── bundled/              # 内置捆绑的 Skills
    ├── batch.ts
    ├── claudeApi.ts
    ├── claudeApiContent.ts
    ├── claudeInChrome.ts
    ├── debug.ts
    ├── index.ts
    ├── keybindings.ts
    ├── loop.ts
    ├── loremIpsum.ts
    ├── remember.ts
    ├── scheduleRemoteAgents.ts
    ├── simplify.ts
    ├── skillify.ts
    ├── stuck.ts
    ├── updateConfig.ts
    ├── verify.ts
    └── verifyContent.ts
```

### Skill 发现流程

`loadSkillsDir.ts` 实现了完整的 Skill 发现管道：

1. **扫描目录**: 搜索以下路径的 `skills/` 子目录：
   - 项目目录 `.claude/skills/`
   - 用户配置目录 `~/.claude/skills/`
   - 托管路径（managed）

2. **解析 Markdown**: 读取 `.md` 文件，解析 frontmatter

3. **Frontmatter 字段**:
   - `name` — 命令名称
   - `description` — 命令描述
   - `aliases` — 别名
   - `whenToUse` — 使用场景
   - `allowedTools` — 允许的工具
   - `model` — 指定模型
   - `hooks` — Hooks 配置
   - `argumentHint` — 参数提示

4. **生成 Command**: 将 Markdown Skill 转换为 `Command` 类型（`type: 'prompt'`）

### 捆绑 Skill 注册

```typescript
// bundledSkills.ts
export function registerBundledSkill(definition: BundledSkillDefinition): void {
  const command: Command = {
    type: 'prompt',
    name: definition.name,
    description: definition.description,
    loadedFrom: 'bundled',
    // ...
  }
  bundledSkills.push(command)
}
```

捆绑 Skills 支持：
- `files` — 附加引用文件，首次调用时提取到磁盘
- `hooks` — 绑定的 hooks
- `context` — `'inline'` 或 `'fork'` 上下文模式
- `agent` — 指定 agent

---

## 7. 插件系统

### 目录结构

```
src/plugins/
├── builtinPlugins.ts     # 内置插件注册表
├── bundled/
│   └── index.ts          # 捆绑插件入口
└── (通过 loadPluginCommands.ts 加载第三方插件)
```

### 插件 vs Skill 的区别

| 方面 | Skill | Plugin |
|------|-------|--------|
| 来源 | `skills/` 目录中的 `.md` 文件 | 插件市场或内置 |
| 注册 | 自动发现 | 需要启用 |
| UI | 无单独 UI | `/plugin` 命令管理 |
| ID 格式 | `<name>` | `<name>@<marketplace>` (内置为 `<name>@builtin`) |
| 提供内容 | 仅 prompt 命令 | Skills + Hooks + MCP 服务器 |

### 内置插件 API

```typescript
// builtinPlugins.ts
export function registerBuiltinPlugin(definition: BuiltinPluginDefinition): void
export function isBuiltinPluginId(pluginId: string): boolean
export function getBuiltinPlugins(): { enabled: LoadedPlugin[], disabled: LoadedPlugin[] }
export function getBuiltinPluginSkillCommands(): Command[]
```

### 命令优先级（插件侧）

```
pluginCommands (插件的 slash commands)
  ↓
pluginSkills (插件的 skills，prompt 型)
  ↓
COMMANDS() (内置命令，最终覆盖)
```

### 插件命令加载

```typescript
// src/utils/plugins/loadPluginCommands.ts
export function getPluginCommands(): Promise<Command[]>
export function getPluginSkills(): Promise<Command[]>
export function clearPluginCommandCache(): void
export function clearPluginSkillsCache(): void
```

---

## 8. 键绑定系统

### 目录结构

```
src/keybindings/
├── defaultBindings.ts        # 默认绑定定义
├── loadUserBindings.ts       # 加载用户自定义绑定
├── parser.ts                 # 解析按键语法
├── match.ts                  # 按键匹配逻辑
├── resolver.ts               # 解析按键到动作
├── schema.ts                 # JSON Schema 验证
├── validate.ts               # 绑定验证
├── template.ts               # 模板
├── shortcutFormat.ts         # 快捷键显示格式
├── reservedShortcuts.ts      # 保留快捷键（不可重映射）
├── KeybindingContext.tsx      # React Context
├── KeybindingProviderSetup.tsx # Provider 设置
├── useKeybinding.ts          # Hook：注册键绑定
└── useShortcutDisplay.ts     # Hook：显示快捷键
```

### 默认绑定

`defaultBindings.ts` 定义了默认键绑定，按上下文分组：

```typescript
export const DEFAULT_BINDINGS: KeybindingBlock[] = [
  {
    context: 'Global',
    bindings: {
      'ctrl+c': 'app:interrupt',
      'ctrl+d': 'app:exit',
      'ctrl+l': 'app:redraw',
      'ctrl+t': 'app:toggleTodos',
      'ctrl+o': 'app:toggleTranscript',
      'ctrl+r': 'history:search',
      // ...
    }
  },
  // 更多上下文...
]
```

### 解析流程

1. `parser.ts` — 解析按键字符串（如 `"ctrl+shift+f"`）为结构化对象
2. `match.ts` — 匹配实际输入与绑定
3. `resolver.ts` — 解析按键到动作（支持和弦序列）
4. `match.ts` 中的 `matchesBinding()` — 核心匹配逻辑

### 上下文感知

键绑定支持上下文切换：
- `Global` — 全局上下文
- `Chat` — 聊天输入模式
- 更多上下文...

### 用户自定义

`loadUserBindings.ts` 加载用户自定义绑定，覆盖默认值：
- 用户绑定优先（last one wins）
- `reservedShortcuts.ts` 定义不可重映射的快捷键（如 `ctrl+c`, `ctrl+d`）

---

## 9. 远程安全命令

### REMOTE_SAFE_COMMANDS

这些命令在 `--remote` 模式下安全可用：

```typescript
export const REMOTE_SAFE_COMMANDS = new Set([
  session, exit, clear, help, theme, color, vim,
  cost, usage, copy, btw, feedback, plan, keybindings,
  statusline, stickers, mobile,
])
```

### BRIDGE_SAFE_COMMANDS

这些 `local` 型命令可通过 Remote Control bridge 执行：

```typescript
export const BRIDGE_SAFE_COMMANDS = new Set([
  compact, clear, cost, summary, releaseNotes, files,
])
```

---

## 10. 命令缓存管理

```typescript
// 清除命令缓存（保留 skill 缓存）
export function clearCommandMemoizationCaches(): void

// 清除所有缓存（命令 + 插件 + skill）
export function clearCommandsCache(): void
```

所有加载函数使用 `lodash-es/memoize` 缓存。`getCommands()` 在每次调用时重新评估 `availability` 和 `isEnabled()` 以支持认证变更（如 `/login` 后）。

---

## 11. 命令查找 API

```typescript
// 查找命令（按名称或别名）
export function findCommand(commandName: string, commands: Command[]): Command | undefined

// 获取命令（找不到抛异常）
export function getCommand(commandName: string, commands: Command[]): Command

// 格式化描述（带来源标注）
export function formatDescriptionWithSource(cmd: Command): string

// 检查是否桥接安全
export function isBridgeSafeCommand(cmd: Command): boolean

// 检查是否远程安全
export function filterCommandsForRemoteMode(commands: Command[]): Command[]
```

---

## 12. 命令执行流程总结

```
用户输入 /commit
    ↓
REPL 解析命令名，调用 findCommand('commit', commands)
    ↓
找到 Command { type: 'prompt', name: 'commit', ... }
    ↓
调用 getPromptForCommand(args, context)
    ↓
返回 ContentBlockParam[]（含 git status/diff 信息的 prompt）
    ↓
将 prompt 发送给 AI 模型
    ↓
模型执行允许的工具（git add, git commit）
    ↓
命令完成
```

对于 `local-jsx` 命令：

```
用户输入 /config
    ↓
REPL 解析命令名，找到 Command { type: 'local-jsx', load: () => import('./config.js') }
    ↓
调用 load() 获取模块
    ↓
调用 module.call(onDone, context, args)
    ↓
渲染 React/Ink 组件
    ↓
用户交互完成后调用 onDone(result)
    ↓
命令完成
```

---

## 附录：内部命令（ANT 用户专用）

```typescript
export const INTERNAL_ONLY_COMMANDS = [
  backfillSessions, breakCache, bughunter, commit, commitPushPr,
  ctx_viz, goodClaude, issue, initVerifiers, mockLimits, bridgeKick,
  version, resetLimits, resetLimitsNonInteractive, onboarding,
  share, summary, teleport, antTrace, perfIssue, env, oauthRefresh,
  debugToolCall, agentsPlatform, autofixPr,
]
```

这些命令仅在 `USER_TYPE === 'ant'` 时可见。
