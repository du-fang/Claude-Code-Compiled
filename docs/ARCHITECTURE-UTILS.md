# Utils 架构详细文档

> 290 个独立工具文件 + 32 个子目录，总计 ~88,500 行代码
> 占项目总代码量的 ~17%，是最大的单一模块

---

## 1. 子目录概览 (32 个)

按文件数量排序：

| 目录 | 文件数 | 职责 |
|------|--------|------|
| `plugins/` | 44 | 插件系统：加载、安装、版本、市场、验证 |
| `permissions/` | 24 | 权限引擎：模式、规则、分类器、路径验证 |
| `bash/` | 23 | Bash 解析器：AST、heredoc、shell completion |
| `swarm/` | 22 | 团队协作：后端、生成、权限同步、重连 |
| `settings/` | 19 | 配置系统：验证、缓存、MDM、变更检测 |
| `hooks/` | 17 | 钩子系统：注册、执行、事件、配置 |
| `model/` | 16 | 模型管理：别名、能力、deprecation、提供商 |
| `computerUse/` | 15 | 计算机使用：执行器、截图、输入、清理 |
| `shell/` | 10 | Shell 抽象：Bash/PowerShell 提供者、前缀 |
| `telemetry/` | 9 | 遥测：事件、追踪、性能、插件追踪 |
| `claudeInChrome/` | 7 | Chrome 集成：native host、MCP server |
| `secureStorage/` | 6 | 安全存储：macOS Keychain、明文 fallback |
| `deepLink/` | 6 | 深度链接：解析、协议处理、终端启动 |
| `task/` | 5 | 任务框架：输出格式化、磁盘持久化 |
| `suggestions/` | 5 | 补全建议：命令、目录、shell 历史 |
| `nativeInstaller/` | 5 | 原生安装器：下载、安装、包管理器 |
| `teleport/` | 4 | 远程传送：API、环境选择、git bundle |
| `processUserInput/` | 4 | 用户输入处理：bash 命令、斜杠命令、文本 |
| `powershell/` | 3 | PowerShell：危险 cmdlet、解析器 |
| `git/` | 3 | Git 操作：config 解析、文件系统、gitignore |
| `ultraplan/` | 2 | 超级计划：CCR 会话、关键词 |
| `sandbox/` | 2 | 沙箱：适配器、UI 工具 |
| `messages/` | 2 | 消息映射：SDK 消息转换 |
| `memory/` | 2 | 记忆：类型、版本 |
| `mcp/` | 2 | MCP 工具：日期解析、验证 |
| `filePersistence/` | 2 | 文件持久化：扫描器 |
| `dxt/` | 2 | DXT：辅助函数、zip |
| `background/` | 2 | 后台任务：远程预检查、会话 |
| `todo/` | 1 | Todo 类型定义 |
| `skills/` | 1 | 技能变更检测 |
| `github/` | 1 | GitHub 认证状态 |

---

## 2. 核心工具文件 (根目录 290 个)

### 2.1 文件系统与路径 (~25 文件)

| 文件 | 职责 |
|------|------|
| `file.ts` | 文件操作辅助 |
| `fileRead.ts` | 文件读取（带缓存、限制） |
| `fileReadCache.ts` | 文件读取缓存 |
| `fileStateCache.ts` | 文件状态缓存 (clone, merge, size limit) |
| `fileHistory.ts` | 文件历史快照追踪 |
| `fileOperationAnalytics.ts` | 文件操作分析 |
| `filePersistence/filePersistence.ts` | 文件持久化 |
| `glob.ts` | Glob 模式匹配 |
| `ripgrep.ts` | ripgrep 封装（代码搜索） |
| `fsOperations.ts` | 文件系统操作 |
| `path.ts` | 路径工具 |
| `tempfile.ts` | 临时文件生成 |
| `xdg.ts` | XDG 目录标准 |
| `systemDirectories.ts` | 系统目录 |
| `cachePaths.ts` | 缓存路径 |
| `getWorktreePaths.ts` | Worktree 路径 |
| `getWorktreePathsPortable.ts` | 跨平台 worktree 路径 |
| `worktree.ts` | Worktree 管理 |
| `worktreeModeEnabled.ts` | Worktree 模式开关 |
| `windowsPaths.ts` | Windows 路径处理 |

### 2.2 Git 相关 (~10 文件)

| 文件 | 职责 |
|------|------|
| `git.ts` | Git 操作：findGitRoot, getBranch, getIsGit, getWorktreeCount |
| `gitDiff.ts` | Git diff 解析和格式化 |
| `git/gitConfigParser.ts` | Git config 解析 |
| `git/gitFilesystem.ts` | Git 文件系统抽象 |
| `git/gitignore.ts` | Gitignore 处理 |
| `gitSettings.ts` | Git 设置 |
| `github/ghAuthStatus.ts` | GitHub 认证状态 |
| `githubRepoPathMapping.ts` | GitHub 仓库路径映射 |
| `ghPrStatus.ts` | PR 状态查询 |
| `commitAttribution.ts` | Commit 归因 |

### 2.3 进程与执行 (~10 文件)

| 文件 | 职责 |
|------|------|
| `process.ts` | 进程工具：writeToStderr, peekForStdinData |
| `execFileNoThrow.ts` | 安全 exec (无异常) |
| `execFileNoThrowPortable.ts` | 跨平台 exec |
| `execSyncWrapper.ts` | 同步 exec 包装 |
| `genericProcessUtils.ts` | 通用进程工具 |
| `subprocessEnv.ts` | 子进程环境变量 |
| `Shell.ts` | Shell 管理：cwd、执行 |
| `ShellCommand.ts` | Shell 命令构建 |
| `which.ts` | 可执行文件查找 |
| `findExecutable.ts` | 可执行文件发现 |
| `tree-kill` | 进程树终止 |

### 2.4 加密与安全 (~8 文件)

| 文件 | 职责 |
|------|------|
| `crypto.ts` | 加密工具 |
| `secureStorage/index.ts` | 安全存储入口 |
| `secureStorage/macOsKeychainStorage.ts` | macOS Keychain |
| `secureStorage/keychainPrefetch.ts` | Keychain 预取 (启动优化) |
| `secureStorage/fallbackStorage.ts` | Fallback 明文存储 |
| `secureStorage/plainTextStorage.ts` | 明文存储 |
| `caCerts.ts` / `caCertsConfig.ts` | CA 证书 |
| `mtls.ts` | mTLS 支持 |

### 2.5 配置与设置 (~15 文件)

| 文件 | 职责 |
|------|------|
| `config.ts` | 全局配置：读写 ~/.claude/ |
| `configConstants.ts` | 配置常量 |
| `env.ts` / `envDynamic.ts` / `envUtils.ts` / `envValidation.ts` | 环境变量管理 |
| `managedEnv.ts` / `managedEnvConstants.ts` | 管理环境变量 |
| `settings/settings.ts` | 设置加载（多源合并） |
| `settings/validation.ts` | Zod schema 验证 |
| `settings/settingsCache.ts` | 设置缓存 |
| `settings/changeDetector.ts` | 文件变更检测 |
| `settings/mdm/` | MDM 企业设置 |

### 2.6 认证与 API (~12 文件)

| 文件 | 职责 |
|------|------|
| `auth.ts` | 认证：OAuth token、Claude.ai 订阅 |
| `authFileDescriptor.ts` | 认证文件描述符 |
| `authPortable.ts` | 跨平台认证 |
| `api.ts` | API 工具 |
| `apiPreconnect.ts` | API 预连接 (启动优化) |
| `billing.ts` | 计费 |
| `user.ts` | 用户信息 |
| `sessionIngressAuth.ts` | 会话入口认证 |
| `jwt` 相关 | JWT 工具 |
| `proxy.ts` | 代理配置 |

### 2.7 Diff 与比较 (~5 文件)

| 文件 | 职责 |
|------|------|
| `diff.ts` | Diff 工具 |
| `treeify.ts` | 树形展示 |
| `highlightMatch.tsx` | 匹配高亮 |
| `contentArray.ts` | 内容数组操作 |
| `truncate.ts` | 文本截断 |

### 2.8 UI 与渲染 (~12 文件)

| 文件 | 职责 |
|------|------|
| `ansiToPng.ts` / `ansiToSvg.ts` | ANSI 转图片/SVG |
| `cliHighlight.ts` | CLI 高亮 |
| `format.ts` | 格式化（token、时间、文件大小） |
| `markdown.ts` | Markdown 处理 |
| `renderOptions.ts` | 渲染选项 |
| `staticRender.tsx` | 静态渲染 |
| `fullscreen.ts` | 全屏模式 |
| `hyperlink.ts` | 终端超链接 |
| `ink.ts` | Ink 工具 |
| `screenshotClipboard.ts` | 截图剪贴板 |
| `theme.ts` / `systemTheme.ts` | 主题管理 |
| `exportRenderer.tsx` | 导出渲染器 |

### 2.9 会话管理 (~12 文件)

| 文件 | 职责 |
|------|------|
| `sessionStart.ts` | 会话启动钩子 |
| `sessionState.ts` | 会话状态 |
| `sessionStorage.ts` | 会话存储（transcript 读写） |
| `sessionStoragePortable.ts` | 跨平台会话存储 |
| `sessionRestore.ts` | 会话恢复 |
| `sessionTitle.ts` | 会话标题 |
| `sessionUrl.ts` | 会话 URL |
| `sessionActivity.ts` | 会话活动追踪 |
| `sessionEnvVars.ts` | 会话环境变量 |
| `sessionEnvironment.ts` | 会话环境 |
| `concurrentSessions.ts` | 并发会话检测 |
| `conversationRecovery.ts` | 对话恢复 |

### 2.10 其他重要文件

| 文件 | 职责 |
|------|------|
| `abortController.ts` | AbortController 工具 |
| `array.ts` | 数组工具（count, uniq 等） |
| `bufferedWriter.ts` | 缓冲写入 |
| `circularBuffer.ts` | 环形缓冲区 |
| `cleanupRegistry.ts` | 清理注册表 |
| `cron.ts` / `cronScheduler.ts` / `cronTasks.ts` | Cron 定时任务 |
| `debug.ts` / `debugFilter.ts` | 调试工具 |
| `errors.ts` | 错误处理 |
| `fpsTracker.ts` | FPS 追踪 |
| `gracefulShutdown.ts` | 优雅关闭 |
| `hash.ts` | 哈希工具 |
| `http.ts` | HTTP 工具 |
| `json.ts` / `jsonRead.ts` | JSON 解析 |
| `lockfile.ts` | 文件锁 |
| `log.ts` | 日志 |
| `memoize.ts` | Memoize 工具 |
| `modifiers.ts` | 修饰键检测 |
| `platform.ts` | 平台检测 |
| `queueProcessor.ts` | 队列处理器 |
| `sanitization.ts` | 输入清理 |
| `semver.ts` | 语义版本 |
| `sequential.ts` | 顺序执行器 |
| `signal.ts` | 信号处理 |
| `sleep.ts` | 延迟 |
| `stringUtils.ts` | 字符串工具 |
| `uuid.ts` | UUID 生成/验证 |
| `words.ts` | 单词工具 |
| `yaml.ts` | YAML 解析 |
| `xml.ts` | XML 工具 |
| `zodToJsonSchema.ts` | Zod → JSON Schema 转换 |

---

## 3. 关键设计模式

### 3.1 启动预取

多个文件实现启动时并行预取：
- `apiPreconnect.ts` — API 连接预热
- `secureStorage/keychainPrefetch.ts` — macOS Keychain 预读
- `settings/mdm/rawRead.ts` — MDM 设置预读

### 3.2 缓存层级

```
内存缓存 (memoize / LRU)
  → 文件缓存 (settingsCache, fileReadCache)
    → 文件系统 (config.json, settings.json)
```

### 3.3 多源配置合并

`settings/settings.ts` 实现多层配置合并：
```
远程管理 → 策略 → 用户 → 项目 → 本地 → CLI → 环境变量
(优先级从低到高)
```

### 3.4 安全沙箱

- `sandbox/sandbox-adapter.ts` — 沙箱适配器
- `permissions/dangerousPatterns.ts` — 危险模式检测
- `permissions/bashClassifier.ts` — Bash 命令分类器
- `permissions/yoloClassifier.ts` — YOLO 分类器

### 3.5 跨平台兼容

多处实现平台抽象：
- `shell/shellProvider.ts` — Bash/PowerShell 抽象
- `secureStorage/` — macOS Keychain / 明文 fallback
- `getWorktreePathsPortable.ts` — 跨平台路径
- `execFileNoThrowPortable.ts` — 跨平台 exec

---

## 4. 依赖关系

utils/ 是最底层的模块，被所有其他模块依赖：

```
main.tsx → utils/ (config, env, auth, platform, ...)
REPL.tsx → utils/ (session, file, git, ...)
QueryEngine → utils/ (model, tokens, ...)
Tools → utils/ (bash, permissions, ...)
Components → utils/ (format, theme, ...)
Services → utils/ (http, crypto, ...)

utils/ ← 无外部依赖（纯工具层）
```

---

## 5. 代码质量特征

- **88,500 行**，占项目 17%
- **290 + 32×N 个文件**，高度模块化
- 大量 memoize 使用（lodash-es）
- Zod schema 验证贯穿配置系统
- 完善的错误处理（`errors.ts` 统一错误类型）
- 详细的调试日志（`debug.ts`, `log.ts`）
