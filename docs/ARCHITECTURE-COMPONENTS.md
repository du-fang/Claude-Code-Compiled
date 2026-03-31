# Claude Code 组件架构文档

> 基于 `/src/components/` 目录的实际代码分析

## 概览

- **总文件数**: 389 个文件（`.tsx` + `.ts`）
- **目录结构**: 40+ 子目录
- **渲染引擎**: [Ink](https://github.com/vadimdemedes/ink)（React 终端渲染器）
- **编译器**: React Compiler（`react/compiler-runtime` 自动 memo 化）
- **状态管理**: 自定义 `useAppState` / `useSetAppState`（基于 `AppState` context）
- **布局模式**: 全屏模式（`FullscreenLayout`）+ 内联模式

---

## 1. 主应用组件

### `App.tsx` — 顶层 Provider 嵌套

```
FpsMetricsProvider
  └── StatsProvider
        └── AppStateProvider
              └── {children}  (REPL 内容)
```

提供三个上下文层：FPS 指标、统计信息、应用状态。本身无 UI，纯 Provider 包装。

### REPL 与主布局

| 组件 | 职责 |
|------|------|
| **`FullscreenLayout.tsx`** | 全屏布局：scrollable 区（消息列表）+ bottom 区（输入框）+ overlay/modal 区 |
| **`Messages.tsx`** | 消息列表主容器。负责消息过滤、重排、分组、构建 lookups，渲染 LogoHeader + MessageRow 列表 |
| **`VirtualMessageList.tsx`** | 虚拟滚动消息列表。管理滚动位置、搜索导航（`JumpHandle`）、sticky header |
| **`MessageRow.tsx`** | 单行消息包装。管理消息折叠/展开状态、model 标签、时间戳 |
| **`Message.tsx`** | 消息类型分发器。根据消息类型渲染对应的子组件 |
| **`MessageResponse.tsx`** | 助手回复渲染（流式输出） |
| **`Spinner.tsx`** | 加载动画。显示旋转字符 + 任务列表 + 闪烁文字 |

### 数据流

```
AppState → Messages → VirtualMessageList → MessageRow → Message → 具体消息类型组件
                                                              ↓
                                                    (permissions, tool use, etc.)
```

---

## 2. 消息渲染组件 (`messages/`)

### 助手消息

| 组件 | 职责 |
|------|------|
| **`AssistantTextMessage.tsx`** | 助手文本回复（Markdown 渲染） |
| **`AssistantThinkingMessage.tsx`** | 助手思考过程（可折叠/展开） |
| **`AssistantRedactedThinkingMessage.tsx`** | 加密思考块 |
| **`AssistantToolUseMessage.tsx`** | 工具调用展示（紧凑/详细模式） |

### 用户消息

| 组件 | 职责 |
|------|------|
| **`UserTextMessage.tsx`** | 用户文本输入 |
| **`UserPromptMessage.tsx`** | 用户 prompt 展示 |
| **`UserImageMessage.tsx`** | 用户上传图片 |
| **`UserBashInputMessage.tsx`** | 用户 bash 输入 |
| **`UserBashOutputMessage.tsx`** | bash 输出结果 |
| **`UserChannelMessage.tsx`** | 频道消息 |
| **`UserCommandMessage.tsx`** | 用户命令 |
| **`UserPlanMessage.tsx`** | 计划模式消息 |
| **`UserTeammateMessage.tsx`** | 队友消息 |
| **`UserMemoryInputMessage.tsx`** | Memory 输入 |
| **`UserResourceUpdateMessage.tsx`** | 资源更新 |
| **`UserLocalCommandOutputMessage.tsx`** | 本地命令输出 |
| **`UserAgentNotificationMessage.tsx`** | Agent 通知消息 |

### 工具结果消息 (`UserToolResultMessage/`)

| 组件 | 职责 |
|------|------|
| **`UserToolResultMessage.tsx`** | 工具结果主容器（分发器） |
| **`UserToolSuccessMessage.tsx`** | 成功结果 |
| **`UserToolErrorMessage.tsx`** | 错误结果 |
| **`UserToolRejectMessage.tsx`** | 拒绝结果 |
| **`UserToolCanceledMessage.tsx`** | 取消结果 |
| **`RejectedToolUseMessage.tsx`** | 被拒绝的工具调用 |
| **`RejectedPlanMessage.tsx`** | 被拒绝的计划 |

### 系统消息

| 组件 | 职责 |
|------|------|
| **`SystemTextMessage.tsx`** | 系统文本消息 |
| **`SystemAPIErrorMessage.tsx`** | API 错误消息 |
| **`ShutdownMessage.tsx`** | 关闭/退出消息 |
| **`RateLimitMessage.tsx`** | 速率限制消息 |

### 聚合/折叠消息

| 组件 | 职责 |
|------|------|
| **`CollapsedReadSearchContent.tsx`** | 折叠的 read/search 组（灰点 + "Reading…"） |
| **`GroupedToolUseContent.tsx`** | 分组工具调用 |
| **`CompactBoundaryMessage.tsx`** | Compact 边界标记 |
| **`HookProgressMessage.tsx`** | Hook 进度 |
| **`PlanApprovalMessage.tsx`** | 计划审批 |
| **`TaskAssignmentMessage.tsx`** | 任务分配 |
| **`AdvisorMessage.tsx`** | Advisor 消息 |
| **`AttachmentMessage.tsx`** | 附件消息 |
| **`HighlightedThinkingText.tsx`** | 高亮思考文本 |

### 辅助文件

| 文件 | 职责 |
|------|------|
| **`nullRenderingAttachments.ts`** | 标记不渲染的附件 |
| **`teamMemCollapsed.tsx`** | 队友消息折叠逻辑 |
| **`teamMemSaved.ts`** | 队友消息保存状态 |

---

## 3. 权限对话框组件 (`permissions/`)

### 核心组件

| 组件 | 职责 |
|------|------|
| **`PermissionRequest.tsx`** | 权限请求分发器。根据工具类型选择对应的权限请求组件 |
| **`PermissionDialog.tsx`** | 权限对话框容器（标题 + subtitle + children） |
| **`PermissionPrompt.tsx`** | 权限提示（带快捷键操作） |
| **`PermissionExplanation.tsx`** | 权限解释说明 |
| **`PermissionRequestTitle.tsx`** | 权限请求标题 |
| **`PermissionRuleExplanation.tsx`** | 权限规则解释 |
| **`PermissionDecisionDebugInfo.tsx`** | 调试信息 |
| **`FallbackPermissionRequest.tsx`** | 通用兜底权限请求 |
| **`WorkerBadge.tsx`** | Worker 标记 |
| **`WorkerPendingPermission.tsx`** | 待处理 Worker 权限 |
| **`SandboxPermissionRequest.tsx`** | 沙箱权限 |

### 工具级权限请求

| 子目录/组件 | 工具 |
|-------------|------|
| **`BashPermissionRequest/`** | Bash 命令执行权限 |
| **`PowerShellPermissionRequest/`** | PowerShell 权限 |
| **`FileEditPermissionRequest/`** | 文件编辑权限 |
| **`FileWritePermissionRequest/`** | 文件写入权限（含 diff） |
| **`FilePermissionDialog/`** | 通用文件权限对话框（含 hook、IDE diff 配置） |
| **`FilesystemPermissionRequest/`** | 文件系统操作权限 |
| **`NotebookEditPermissionRequest/`** | Notebook 编辑权限 |
| **`SedEditPermissionRequest/`** | Sed 编辑权限 |
| **`WebFetchPermissionRequest/`** | 网络请求权限 |
| **`SkillPermissionRequest/`** | Skill 执行权限 |
| **`ComputerUseApproval/`** | Computer Use 权限 |
| **`AskUserQuestionPermissionRequest/`** | AskUserQuestion 工具权限 |
| **`EnterPlanModePermissionRequest/`** | 进入计划模式权限 |
| **`ExitPlanModePermissionRequest/`** | 退出计划模式权限 |

### 权限规则管理 (`rules/`)

| 组件 | 职责 |
|------|------|
| **`AddPermissionRules.tsx`** | 添加权限规则 |
| **`PermissionRuleInput.tsx`** | 规则输入 |
| **`PermissionRuleList.tsx`** | 规则列表 |
| **`PermissionRuleDescription.tsx`** | 规则描述 |
| **`AddWorkspaceDirectory.tsx`** | 添加工作目录 |
| **`RemoveWorkspaceDirectory.tsx`** | 移除工作目录 |
| **`RecentDenialsTab.tsx`** | 最近拒绝记录 |
| **`WorkspaceTab.tsx`** | 工作目录标签页 |

### 辅助

| 文件 | 职责 |
|------|------|
| **`hooks.ts`** | 权限相关 hooks |
| **`utils.ts`** | 权限工具函数 |
| **`shellPermissionHelpers.tsx`** | Shell 权限辅助 |
| **`useShellPermissionFeedback.ts`** | Shell 权限反馈 |

---

## 4. 设计系统组件 (`design-system/`)

| 组件 | 职责 |
|------|------|
| **`Dialog.tsx`** | 对话框容器（标题、subtitle、ESC 取消、输入指南） |
| **`Pane.tsx`** | 面板容器（边框、内边距） |
| **`Tabs.tsx`** | 标签页（Tab 切换） |
| **`Divider.tsx`** | 分隔线 |
| **`Byline.tsx`** | 副标题/署名 |
| **`ListItem.tsx`** | 列表项 |
| **`LoadingState.tsx`** | 加载状态 |
| **`ProgressBar.tsx`** | 进度条 |
| **`StatusIcon.tsx`** | 状态图标（✓ ✗ ⚠ 等） |
| **`Ratchet.tsx`** | 步进器（数字递增/递减） |
| **`KeyboardShortcutHint.tsx`** | 键盘快捷键提示 |
| **`FuzzyPicker.tsx`** | 模糊搜索选择器 |
| **`ThemeProvider.tsx`** | 主题提供者 |
| **`ThemedBox.tsx`** | 主题化 Box |
| **`ThemedText.tsx`** | 主题化 Text |
| **`color.ts`** | 颜色工具函数 |

---

## 5. 提示输入组件 (`PromptInput/`)

| 组件 | 职责 |
|------|------|
| **`PromptInput.tsx`** | 主输入组件（~600 行）。处理键盘输入、历史导航、粘贴、快捷键、模式切换 |
| **`PromptInputFooter.tsx`** | 输入框底部（模式指示器 + 建议） |
| **`PromptInputFooterLeftSide.tsx`** | 底部左侧内容 |
| **`PromptInputFooterSuggestions.tsx`** | 输入建议（命令、文件路径） |
| **`PromptInputHelpMenu.tsx`** | 帮助菜单 |
| **`PromptInputModeIndicator.tsx`** | 模式指示器（编辑/vim/计划等） |
| **`PromptInputQueuedCommands.tsx`** | 队列命令显示 |
| **`PromptInputStashNotice.tsx`** | Stash 通知 |
| **`ShimmeredInput.tsx`** | 闪烁输入效果 |
| **`VoiceIndicator.tsx`** | 语音输入指示器 |
| **`HistorySearchInput.tsx`** | 历史搜索输入 |
| **`IssueFlagBanner.tsx`** | Issue 标记横幅 |
| **`Notifications.tsx`** | 通知组件 |
| **`SandboxPromptFooterHint.tsx`** | 沙箱模式提示 |

### 工具/辅助

| 文件 | 职责 |
|------|------|
| **`inputModes.ts`** | 输入模式定义（normal/vim/edit） |
| **`inputPaste.ts`** | 粘贴处理逻辑 |
| **`utils.ts`** | Vim 模式检测等工具 |
| **`useMaybeTruncateInput.ts`** | 输入截断 hook |
| **`usePromptInputPlaceholder.ts`** | 占位符 hook |
| **`useShowFastIconHint.ts`** | 快速模式图标提示 |
| **`useSwarmBanner.ts`** | Swarm 横幅 hook |

---

## 6. 任务管理组件 (`tasks/`)

| 组件 | 职责 |
|------|------|
| **`BackgroundTasksDialog.tsx`** | 后台任务列表对话框（支持多种任务类型） |
| **`BackgroundTask.tsx`** | 单个后台任务条目 |
| **`BackgroundTaskStatus.tsx`** | 任务状态显示 |
| **`AsyncAgentDetailDialog.tsx`** | 异步 Agent 详情对话框 |
| **`InProcessTeammateDetailDialog.tsx`** | 进程内队友详情 |
| **`RemoteSessionDetailDialog.tsx`** | 远程会话详情 |
| **`RemoteSessionProgress.tsx`** | 远程会话进度 |
| **`DreamDetailDialog.tsx`** | Dream 任务详情 |
| **`ShellDetailDialog.tsx`** | Shell 任务详情 |
| **`ShellProgress.tsx`** | Shell 进度 |
| **`renderToolActivity.tsx`** | 工具活动渲染 |
| **`taskStatusUtils.tsx`** | 任务状态工具函数 |

支持的任务类型：
- `local_bash` — 本地 Bash
- `local_agent` — 本地 Agent
- `remote_agent` — 远程 Agent
- `in_process_teammate` — 进程内队友
- `dream` — Dream 任务
- `local_shell` — Shell 任务
- `local_workflow` — Workflow 任务
- `monitor_mcp` — MCP Monitor

---

## 7. Agent 管理组件 (`agents/`)

### 核心

| 组件 | 职责 |
|------|------|
| **`AgentsMenu.tsx`** | Agent 管理主菜单（列表 → 详情 → 编辑） |
| **`AgentsList.tsx`** | Agent 列表（分组：project/global/built-in） |
| **`AgentDetail.tsx`** | Agent 详情展示 |
| **`AgentEditor.tsx`** | Agent 配置编辑器 |
| **`AgentNavigationFooter.tsx`** | 导航底部 |
| **`ColorPicker.tsx`** | 颜色选择器 |
| **`ModelSelector.tsx`** | 模型选择器 |
| **`ToolSelector.tsx`** | 工具选择器 |

### Agent 创建向导 (`new-agent-creation/`)

| 组件 | 职责 |
|------|------|
| **`CreateAgentWizard.tsx`** | 创建 Agent 向导主控 |
| **`wizard-steps/MethodStep.tsx`** | 选择方式（手动/AI 生成） |
| **`wizard-steps/TypeStep.tsx`** | Agent 类型 |
| **`wizard-steps/DescriptionStep.tsx`** | 描述 |
| **`wizard-steps/PromptStep.tsx`** | System Prompt |
| **`wizard-steps/ToolsStep.tsx`** | 工具选择 |
| **`wizard-steps/ModelStep.tsx`** | 模型选择 |
| **`wizard-steps/ColorStep.tsx`** | 颜色选择 |
| **`wizard-steps/LocationStep.tsx`** | 保存位置 |
| **`wizard-steps/MemoryStep.tsx`** | Memory 配置 |
| **`wizard-steps/GenerateStep.tsx`** | AI 生成 |
| **`wizard-steps/ConfirmStep.tsx`** | 确认 |
| **`wizard-steps/ConfirmStepWrapper.tsx`** | 确认包装 |

### 工具

| 文件 | 职责 |
|------|------|
| **`types.ts`** | Agent 类型定义 |
| **`utils.ts`** | Agent 工具函数 |
| **`validateAgent.ts`** | Agent 验证 |
| **`agentFileUtils.ts`** | Agent 文件操作 |
| **`generateAgent.ts`** | AI 生成 Agent |

---

## 8. MCP 相关组件 (`mcp/`)

| 组件 | 职责 |
|------|------|
| **`MCPSettings.tsx`** | MCP 设置主入口（列表 → 详情） |
| **`MCPListPanel.tsx`** | MCP 服务器列表 |
| **`MCPStdioServerMenu.tsx`** | Stdio 服务器配置菜单 |
| **`MCPRemoteServerMenu.tsx`** | 远程服务器配置菜单 |
| **`MCPAgentServerMenu.tsx`** | Agent 级 MCP 服务器菜单 |
| **`MCPToolListView.tsx`** | MCP 工具列表 |
| **`MCPToolDetailView.tsx`** | MCP 工具详情 |
| **`CapabilitiesSection.tsx`** | 服务器能力展示 |
| **`MCPReconnect.tsx`** | 重连组件 |
| **`ElicitationDialog.tsx`** | MCP Elicitation 对话框 |
| **`McpParsingWarnings.tsx`** | 解析警告 |

---

## 9. Settings 组件 (`Settings/`)

| 组件 | 职责 |
|------|------|
| **`Settings.tsx`** | 设置主界面（Tab 切换：Status/Config/Usage） |
| **`Status.tsx`** | 状态页（诊断信息、连接状态） |
| **`Config.tsx`** | 配置页（设置项编辑） |
| **`Usage.tsx`** | 使用统计页 |

---

## 10. Spinner 组件 (`Spinner/`)

| 组件 | 职责 |
|------|------|
| **`SpinnerAnimationRow.tsx`** | 动画行（旋转字符 + 文字） |
| **`SpinnerGlyph.tsx`** | 旋转字符渲染 |
| **`ShimmerChar.tsx`** | 闪烁字符 |
| **`FlashingChar.tsx`** | 闪烁字符 |
| **`GlimmerMessage.tsx`** | 微光消息 |
| **`TeammateSpinnerLine.tsx`** | 队友 Spinner 行 |
| **`TeammateSpinnerTree.tsx`** | 队友 Spinner 树（递归任务树） |

---

## 11. Logo 与欢迎组件 (`LogoV2/`)

| 组件 | 职责 |
|------|------|
| **`LogoV2.tsx`** | 主 Logo + 欢迎界面（最近活动、what's new、项目入门） |
| **`WelcomeV2.tsx`** | 欢迎消息 |
| **`CondensedLogo.tsx`** | 精简 Logo（窄终端） |
| **`Clawd.tsx`** | Clawd 角色 |
| **`AnimatedClawd.tsx`** | 动画 Clawd |
| **`AnimatedAsterisk.tsx`** | 动画星号 |
| **`Feed.tsx`** | 信息流容器 |
| **`FeedColumn.tsx`** | 信息流列 |
| **`feedConfigs.tsx`** | 信息流配置（最近活动、what's new、项目入门） |
| **`EmergencyTip.tsx`** | 紧急提示 |
| **`VoiceModeNotice.tsx`** | 语音模式通知 |
| **`Opus1mMergeNotice.tsx`** | Opus 1M 合并通知 |
| **`ChannelsNotice.tsx`** | 频道通知 |
| **`GuestPassesUpsell.tsx`** | Guest Pass 推广 |
| **`OverageCreditUpsell.tsx`** | 超额信用推广 |

---

## 12. 其他重要组件

### 对话框/覆盖层

| 组件 | 职责 |
|------|------|
| **`Onboarding.tsx`** | 首次使用引导（主题、OAuth、API Key、安全） |
| **`ExitFlow.tsx`** | 退出流程 |
| **`ExportDialog.tsx`** | 导出对话框 |
| **`GlobalSearchDialog.tsx`** | 全局搜索（Transcript 搜索） |
| **`HistorySearchDialog.tsx`** | 历史搜索 |
| **`QuickOpenDialog.tsx`** | 快速打开 |
| **`ModelPicker.tsx`** | 模型选择器 |
| **`ThemePicker.tsx`** | 主题选择器 |
| **`LanguagePicker.tsx`** | 语言选择器 |
| **`OutputStylePicker.tsx`** | 输出风格选择器 |
| **`BridgeDialog.tsx`** | Bridge 对话框 |
| **`CostThresholdDialog.tsx`** | 成本阈值对话框 |
| **`BypassPermissionsModeDialog.tsx`** | 绕过权限模式对话框 |
| **`ChannelDowngradeDialog.tsx`** | 频道降级对话框 |
| **`AutoModeOptInDialog.tsx`** | 自动模式加入对话框 |
| **`IdeOnboardingDialog.tsx`** | IDE 入门对话框 |
| **`IdeAutoConnectDialog.tsx`** | IDE 自动连接 |
| **`InvalidConfigDialog.tsx`** | 无效配置 |
| **`InvalidSettingsDialog.tsx`** | 无效设置 |
| **`IdleReturnDialog.tsx`** | 空闲返回对话框 |
| **`WorktreeExitDialog.tsx`** | Worktree 退出对话框 |
| **`TeleportRepoMismatchDialog.tsx`** | 仓库不匹配 |
| **`ClaudeMdExternalIncludesDialog.tsx`** | CLAUDE.md 外部引用 |
| **`DevChannelsDialog.tsx`** | 开发频道对话框 |
| **`WorkflowMultiselectDialog.tsx`** | Workflow 多选对话框 |
| **`ManagedSettingsSecurityDialog/`** | 托管设置安全对话框 |
| **`TrustDialog/`** | 信任对话框 |
| **`MCPServerApprovalDialog.tsx`** | MCP 服务器审批 |
| **`MCPServerDesktopImportDialog.tsx`** | MCP 桌面导入 |
| **`MCPServerMultiselectDialog.tsx`** | MCP 多选对话框 |
| **`MCPServerDialogCopy.tsx`** | MCP 对话框副本 |
| **`ClaudeInChromeOnboarding.tsx`** | Chrome 入门 |

### 显示/工具组件

| 组件 | 职责 |
|------|------|
| **`Markdown.tsx`** | Markdown 渲染（`StreamingMarkdown`） |
| **`MarkdownTable.tsx`** | Markdown 表格 |
| **`HighlightedCode.tsx`** | 代码高亮 |
| **`StructuredDiff.tsx`** | 结构化 Diff |
| **`StructuredDiffList.tsx`** | Diff 列表 |
| **`FileEditToolDiff.tsx`** | 文件编辑 Diff |
| **`FilePathLink.tsx`** | 文件路径链接（可点击） |
| **`ClickableImageRef.tsx`** | 可点击图片引用 |
| **`Stats.tsx`** | 统计信息（tokens、成本、时长） |
| **`StatusLine.tsx`** | 状态栏（模型、权限模式、cwd、context） |
| **`StatusNotices.tsx`** | 状态通知 |
| **`ThinkingToggle.tsx`** | Thinking 开关 |
| **`EffortCallout.tsx`** | Effort 提示 |
| **`EffortIndicator.ts`** | Effort 指示器 |
| **`TokenWarning.tsx`** | Token 警告 |
| **`MemoryUsageIndicator.tsx`** | 内存使用指示器 |
| **`ToolUseLoader.tsx`** | 工具使用加载器 |
| **`SearchBox.tsx`** | 搜索框 |
| **`LogSelector.tsx`** | 日志选择器 |
| **`TagTabs.tsx`** | 标签标签页 |
| **`PrBadge.tsx`** | PR 标记 |
| **`ContextSuggestions.tsx`** | 上下文建议 |
| **`ContextVisualization.tsx`** | 上下文可视化 |
| **`CompactSummary.tsx`** | Compact 摘要 |
| **`ResumeTask.tsx`** | 恢复任务 |
| **`SessionPreview.tsx`** | 会话预览 |
| **`SessionBackgroundHint.tsx`** | 会话背景提示 |
| **`ShowInIDEPrompt.tsx`** | IDE 中显示提示 |
| **`TaskListV2.tsx`** | 任务列表 V2 |
| **`TeammateViewHeader.tsx`** | 队友视图头部 |
| **`CoordinatorAgentStatus.tsx`** | 协调者 Agent 状态 |
| **`AgentProgressLine.tsx`** | Agent 进度行 |

### Teleport 相关

| 组件 | 职责 |
|------|------|
| **`DesktopHandoff.tsx`** | 桌面端交接 |
| **`TeleportError.tsx`** | Teleport 错误 |
| **`TeleportProgress.tsx`** | Teleport 进度 |
| **`TeleportResumeWrapper.tsx`** | Teleport 恢复包装 |
| **`TeleportStash.tsx`** | Teleport Stash |
| **`RemoteCallout.tsx`** | 远程提示 |
| **`RemoteEnvironmentDialog.tsx`** | 远程环境对话框 |

### 自动更新

| 组件 | 职责 |
|------|------|
| **`AutoUpdater.tsx`** | 自动更新逻辑 |
| **`AutoUpdaterWrapper.tsx`** | 自动更新包装 |
| **`NativeAutoUpdater.tsx`** | 原生自动更新 |
| **`PackageManagerAutoUpdater.tsx`** | 包管理器自动更新 |

### 反馈/调查

| 组件 | 职责 |
|------|------|
| **`Feedback.tsx`** | 反馈入口 |
| **`FeedbackSurvey/`** | 反馈调查（评分、transcript 分享） |
| **`SkillImprovementSurvey.tsx`** | Skill 改进调查 |

### 输入/交互

| 组件 | 职责 |
|------|------|
| **`TextInput.tsx`** | 文本输入组件 |
| **`BaseTextInput.tsx`** | 基础文本输入 |
| **`VimTextInput.tsx`** | Vim 模式文本输入 |
| **`ConfigurableShortcutHint.tsx`** | 可配置快捷键提示 |
| **`PressEnterToContinue.tsx`** | "按 Enter 继续" |
| **`CtrlOToExpand.tsx`** | Ctrl+O 展开提示 |
| **`ScrollKeybindingHandler.tsx`** | 滚动键绑定处理 |
| **`KeybindingWarnings.tsx`** | 键绑定警告 |
| **`InterruptedByUser.tsx`** | 用户中断显示 |
| **`ValidationErrorsList.tsx`** | 验证错误列表 |
| **`ApproveApiKey.tsx`** | API Key 审批 |
| **`AwsAuthStatusBox.tsx`** | AWS 认证状态 |
| **`ConsoleOAuthFlow.tsx`** | Console OAuth 流程 |

### 其他子目录

| 目录 | 组件 | 职责 |
|------|------|------|
| **`CustomSelect/`** | `select.tsx`, `SelectMulti.tsx`, `select-option.tsx`, `select-input-option.tsx` | 自定义选择器（单选/多选/输入） |
| **`HelpV2/`** | `HelpV2.tsx`, `Commands.tsx`, `General.tsx` | 帮助界面 |
| **`hooks/`** | `HooksConfigMenu.tsx`, `SelectEventMode.tsx`, `SelectHookMode.tsx` 等 | Hooks 配置管理 |
| **`memory/`** | `MemoryFileSelector.tsx`, `MemoryUpdateNotification.tsx` | Memory 管理 |
| **`sandbox/`** | `SandboxSettings.tsx`, `SandboxConfigTab.tsx` 等 | 沙箱设置 |
| **`shell/`** | `ShellProgressMessage.tsx`, `OutputLine.tsx` 等 | Shell 输出展示 |
| **`skills/`** | `SkillsMenu.tsx` | Skills 菜单 |
| **`teams/`** | `TeamsDialog.tsx`, `TeamStatus.tsx` | 团队管理 |
| **`diff/`** | `DiffDialog.tsx`, `DiffDetailView.tsx`, `DiffFileList.tsx` | Diff 查看器 |
| **`grove/`** | `Grove.tsx` | Grove 功能 |
| **`passes/`** | `Passes.tsx` | Passes 功能 |
| **`wizard/`** | `WizardDialogLayout.tsx`, `WizardProvider.tsx`, `useWizard.ts` | 通用向导框架 |
| **`ui/`** | `OrderedList.tsx`, `OrderedListItem.tsx`, `TreeSelect.tsx` | 通用 UI 原语 |
| **`ClaudeCodeHint/`** | `PluginHintMenu.tsx` | 插件提示菜单 |
| **`DesktopUpsell/`** | `DesktopUpsellStartup.tsx` | 桌面版推广 |
| **`LspRecommendation/`** | `LspRecommendationMenu.tsx` | LSP 推荐菜单 |
| **`Passes/`** | `Passes.tsx` | Passes |
| **`HighlightCode/`** | `Fallback.tsx` | 代码高亮回退 |
| **`StructuredDiff/`** | `Fallback.tsx`, `colorDiff.ts` | Diff 回退/颜色 |

### 独立组件

| 组件 | 职责 |
|------|------|
| **`messageActions.tsx`** | 消息动作状态管理（`MessageActionsState`、导航） |
| **`OffscreenFreeze.tsx`** | 离屏冻结（React Compiler 优化） |
| **`SentryErrorBoundary.ts`** | Sentry 错误边界 |
| **`DevBar.tsx`** | 开发者工具栏 |
| **`DiagnosticsDisplay.tsx`** | 诊断信息展示 |
| **`FallbackToolUseErrorMessage.tsx`** | 兜底工具错误消息 |
| **`FallbackToolUseRejectedMessage.tsx`** | 兜底工具拒绝消息 |
| **`FileEditToolUpdatedMessage.tsx`** | 文件编辑更新消息 |
| **`FileEditToolUseRejectedMessage.tsx`** | 文件编辑拒绝消息 |
| **`NotebookEditToolUseRejectedMessage.tsx`** | Notebook 编辑拒绝消息 |
| **`SandboxViolationExpandedView.tsx`** | 沙箱违规展开视图 |
| **`FastIcon.tsx`** | 快速模式图标 |
| **`MessageModel.tsx`** | 消息模型标签 |
| **`MessageTimestamp.tsx`** | 消息时间戳 |
| **`MessageSelector.tsx`** | 消息选择器 |

---

## 13. 父子关系与数据流

### 核心渲染链

```
App (Provider 嵌套)
  └── FullscreenLayout
        ├── scrollable 区
        │   └── Messages
        │       ├── LogoHeader (LogoV2 + StatusNotices)
        │       └── VirtualMessageList
        │           └── MessageRow (per message)
        │               ├── MessageModel
        │               ├── MessageTimestamp
        │               └── Message
        │                   ├── AssistantTextMessage → StreamingMarkdown
        │                   ├── AssistantThinkingMessage
        │                   ├── AssistantToolUseMessage
        │                   ├── UserTextMessage
        │                   ├── UserToolResultMessage → 具体结果组件
        │                   ├── SystemTextMessage
        │                   ├── CollapsedReadSearchContent
        │                   ├── GroupedToolUseContent
        │                   └── ... (30+ 种消息类型)
        ├── bottom 区
        │   ├── Spinner (加载中)
        │   └── PromptInput
        │       ├── PromptInputFooter
        │       │   ├── PromptInputModeIndicator
        │       │   └── PromptInputFooterSuggestions
        │       ├── Notifications
        │       └── VoiceIndicator
        ├── overlay 区
        │   └── PermissionRequest → 具体权限组件
        └── modal 区
            └── Settings / MCPSettings / AgentsMenu / BackgroundTasksDialog ...
```

### 权限请求链

```
PermissionRequest (分发器)
  ├── BashPermissionRequest
  ├── FileEditPermissionRequest
  ├── FileWritePermissionRequest → FileWriteToolDiff
  ├── NotebookEditPermissionRequest → NotebookEditToolDiff
  ├── WebFetchPermissionRequest
  ├── SkillPermissionRequest
  ├── PowerShellPermissionRequest
  ├── AskUserQuestionPermissionRequest
  ├── EnterPlanModePermissionRequest
  ├── ExitPlanModePermissionRequest
  ├── FilesystemPermissionRequest
  ├── SedEditPermissionRequest
  ├── ComputerUseApproval
  └── FallbackPermissionRequest

所有权限组件 → PermissionDialog → PermissionRequestTitle
```

### Agent 创建向导链

```
AgentsMenu
  ├── AgentsList
  ├── AgentDetail
  ├── AgentEditor
  └── CreateAgentWizard (WizardProvider)
        └── WizardDialogLayout → Dialog
              └── wizard-steps/* (12 步)
```

---

## 14. 状态管理方式

### 核心状态

| 状态源 | Hook/Context | 管理内容 |
|--------|-------------|----------|
| **AppState** | `useAppState()` / `useSetAppState()` | 全局应用状态（消息、工具、MCP、Agent 定义等） |
| **AppStateStore** | `useAppStateStore()` | 状态存储（Footer items 等） |
| **Settings** | `useSettings()` | 用户设置 |
| **Theme** | `useTheme()` | 主题 |
| **Modal Context** | `useIsInsideModal()` | 是否在 modal 内 |
| **Overlay Context** | `usePromptOverlay()` | Prompt overlay 状态 |
| **Notifications** | `useNotifications()` | 通知系统 |
| **FPS Metrics** | `useFpsMetrics()` | 性能指标 |
| **Stats** | `useStats()` | 统计信息 |
| **Terminal Size** | `useTerminalSize()` | 终端尺寸 |

### 状态流向

1. **AppState** 是中央状态容器，包含消息数组、工具列表、MCP 连接、Agent 定义等
2. **PromptInput** 通过 `useSetAppState()` 写入用户输入，触发消息处理
3. **Messages** 从 `useAppState()` 读取消息数组，经过过滤/重排后渲染
4. **PermissionRequest** 从 `useAppState()` 读取当前工具使用，显示对应权限 UI
5. **Settings/MCP/Agents** 等 modal 通过 `useSetAppState()` 修改配置

### 性能优化

- **React Compiler**: 所有组件使用 `_c()` memo 缓存，自动避免不必要重渲染
- **`OffscreenFreeze`**: 离屏组件冻结，防止不可见区域的渲染开销
- **`VirtualMessageList`**: 虚拟滚动，只渲染可见消息
- **`React.memo`**: 关键子树（如 `LogoHeader`）显式 memo
- **`useSyncExternalStore`**: 外部状态（终端尺寸、scroll 位置）订阅

---

## 15. 组件数量统计

| 分类 | 组件数 |
|------|--------|
| 主应用/布局 | ~6 |
| 消息渲染 | ~40 |
| 权限对话框 | ~35 |
| 设计系统 | ~16 |
| PromptInput | ~20 |
| 任务管理 | ~12 |
| Agent 管理 | ~20 |
| MCP | ~12 |
| Settings | 4 |
| Spinner | ~10 |
| LogoV2 | ~18 |
| 其他独立组件 | ~50+ |
| 辅助/工具文件 | ~100+ |
| **总计** | **389 个文件** |
