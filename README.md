# Claude Code — Compiled & Fixed

**[English](README.md)** | **[中文](README_CN.md)**

A working, buildable version of the [Claude Code](https://github.com/anthropics/claude-code) CLI, reconstructed from the leaked source (2026-03-31) with all missing files, broken imports, and runtime errors fixed.

---

## What This Is

On March 31, 2026, the full source code of Anthropic's Claude Code CLI was leaked via a `.map` file in their npm registry. The original leak is **not buildable** — it's missing 22+ source files, has broken internal imports, uses Anthropic-internal packages, and relies on unreleased Bun features (`bun:bundle`).

This repo fixes all of that. The result: a single `bun build` command that produces a working ~23MB bundle.

---

## Changes From the Original Leak

### Missing Source Files Added (22 stubs)

The leaked source references files that don't exist in the package. These have been created as functional stubs:

| File | Purpose |
|------|---------|
| `src/global.d.ts` | TypeScript global declarations |
| `src/utils/protectedNamespace.ts` | Namespace protection |
| `src/utils/useEffectEvent.ts` | React `useEffectEvent` polyfill |
| `src/entrypoints/sdk/coreTypes.generated.ts` | SDK generated types |
| `src/entrypoints/sdk/runtimeTypes.ts` | SDK runtime types |
| `src/entrypoints/sdk/toolTypes.ts` | SDK tool types |
| `src/tools/REPLTool/REPLTool.ts` | REPL tool stub |
| `src/tools/SuggestBackgroundPRTool/` | PR suggestion stub |
| `src/tools/VerifyPlanExecutionTool/` | Plan verification stub |
| `src/tools/WorkflowTool/` | Workflow tool stub |
| `src/tools/TungstenTool/TungstenLiveMonitor.tsx` | Tungsten monitor stub |
| `src/commands/agents-platform/` | Agent platform command stub |
| `src/commands/assistant/` | Assistant command stub |
| `src/components/agents/SnapshotUpdateDialog.tsx` | Snapshot dialog stub |
| `src/assistant/AssistantSessionChooser.tsx` | Session chooser stub |
| `src/services/compact/snipCompact.ts` | Snip compact stub |
| `src/services/compact/cachedMicrocompact.ts` | Microcompact stub |
| `src/services/contextCollapse/` | Context collapse stub |
| `src/ink/devtools.ts` | Devtools stub |
| `src/skills/bundled/verify/` | Verify skill stub |
| `src/utils/filePersistence/types.ts` | File persistence types stub |

### Source Code Fixes

| Fix | File(s) | Description |
|-----|---------|---------|
| `useEffectEvent` import | `src/components/tasks/BackgroundTasksDialog.tsx`, `src/state/AppState.tsx` | React 19 experimental hook not available in `react-reconciler@0.31` — moved to local polyfill |
| Version check skip | `src/utils/autoUpdater.ts` | `assertMinVersion()` calls Anthropic servers — bypassed |
| Org validation skip | `src/main.tsx` | `validateForceLoginOrg()` requires Anthropic auth — commented out |
| Auth check skip | `src/main.tsx` | Login flow requires Anthropic OAuth — auto-execute enabled |
| `SandboxManager` stub | `node_modules/@anthropic-ai/sandbox-runtime/` | Replaced minimal 14-method stub with real implementation from [anthropic-experimental/sandbox-runtime](https://github.com/anthropic-experimental/sandbox-runtime) |

### Shim Files (Bun compatibility)

| File | Purpose |
|------|---------|
| `shims/macro.ts` | Provides `MACRO` global (VERSION, BUILD_TIME, etc.) — normally injected by Anthropic's Bun build |
| `shims/bun-bundle.ts` | Provides `feature()` function stub — replaces `bun:bundle` which is Anthropic-internal |

### Missing Dependencies (28 packages added)

The original `package.json` was incomplete. 28 missing dependencies have been added, including `@anthropic-ai/` SDKs, OpenTelemetry packages, and other required modules.

### Internal Package Stubs

Two Anthropic-internal packages that can't be installed from npm:

- `@anthropic-ai/sandbox-runtime` — replaced with [real open-source implementation](https://github.com/anthropic-experimental/sandbox-runtime)
- `@ant/claude-for-chrome-mcp` — stubbed in `node_modules/`

---

## Quick Start

### Prerequisites

- **Bun** 1.3+ — `curl -fsSL https://bun.sh/install | bash`
- **Node.js** 18+ (optional, Bun includes npm)

### Build

```bash
git clone https://github.com/roger2ai/Claude-Code-Compiled.git
cd Claude-Code-Compiled

# Install dependencies
bun install

# Patch Commander.js (multi-char short flags not supported upstream)
# See docs/BUILD.md §4.1 for details — needs re-apply after bun install

# Build
bun build shims/macro.ts src/main.tsx --target=bun --outdir=./dist

# Bundle into single file
cat dist/shims/macro.js dist/src/main.js > dist/bundle.js
echo 'if (typeof main === "function") main().catch(e => { console.error(e); process.exit(1); });' >> dist/bundle.js
```

Output: `dist/bundle.js` (~23 MB, ~5,750 modules, ~300ms build time)

### Run

```bash
# Help (no API key needed)
bun dist/bundle.js --help

# Interactive REPL (requires real terminal + API key)
export ANTHROPIC_API_KEY=your-key
bun dist/bundle.js

# One-shot mode
bun dist/bundle.js -p "say hello"
```

---

## Project Structure

```
claude-code/
├── src/                  # Source (~1,900 TypeScript files, 512K+ lines)
│   ├── main.tsx          # CLI entrypoint
│   ├── QueryEngine.ts    # LLM query engine
│   ├── Tool.ts           # Tool type definitions
│   ├── tools/            # 43 tool implementations
│   ├── commands/         # 80+ slash commands
│   ├── components/       # 346 React/Ink UI components
│   ├── services/         # 21 service modules
│   ├── screens/          # Full-screen UIs (REPL, Doctor, etc.)
│   └── utils/            # 290+ utility files
├── shims/                # Bun compatibility shims
├── docs/                 # Architecture & build documentation
├── dist/                 # Build output (gitignored)
└── package.json          # Dependencies (574 packages)
```

---

## Documentation

| Document | Content |
|----------|---------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Full architecture overview |
| [docs/ARCHITECTURE-TOOLS.md](docs/ARCHITECTURE-TOOLS.md) | 43 tool implementations |
| [docs/ARCHITECTURE-SERVICES.md](docs/ARCHITECTURE-SERVICES.md) | 21 service modules |
| [docs/ARCHITECTURE-COMPONENTS.md](docs/ARCHITECTURE-COMPONENTS.md) | 346 UI components |
| [docs/ARCHITECTURE-COMMANDS.md](docs/ARCHITECTURE-COMMANDS.md) | Commands, skills, plugins |
| [docs/ARCHITECTURE-UTILS.md](docs/ARCHITECTURE-UTILS.md) | Utility layer |
| [docs/ARCHITECTURE-BRIDGE-REMOTE.md](docs/ARCHITECTURE-BRIDGE-REMOTE.md) | IDE bridge & remote sessions |
| [docs/API-CONFIG.md](docs/API-CONFIG.md) | API configuration (env vars, auth, proxies) |
| [docs/BUILD.md](docs/BUILD.md) | Detailed build guide & all patches |
| [docs/REFACTORING-ASSESSMENT.md](docs/REFACTORING-ASSESSMENT.md) | Refactoring feasibility analysis |

---

## Feature Completeness

### Core Tools — All Working ✅

| Tool | Description |
|------|-------------|
| BashTool | Shell command execution |
| FileReadTool | File reading (images, PDFs, notebooks) |
| FileWriteTool | File creation / overwrite |
| FileEditTool | Partial file modification |
| GlobTool | File pattern matching |
| GrepTool | ripgrep-based content search |
| WebFetchTool | Fetch URL content |
| WebSearchTool | Web search |
| AgentTool | Sub-agent spawning |
| SkillTool | Skill execution |
| NotebookEditTool | Jupyter notebook editing |
| AskUserQuestionTool | Interactive prompts |
| MCPTool | MCP server tool invocation |
| ListMcpResourcesTool / ReadMcpResourceTool | MCP resource access |

### Conditionally Enabled Tools

| Tool | Condition | Status |
|------|-----------|--------|
| LSPTool | Set `ENABLE_LSP_TOOL=true` | Works |
| PowerShellTool | Windows environment | Works |
| EnterWorktreeTool / ExitWorktreeTool | Config enabled | Works |
| TaskCreateTool / TaskGetTool / TaskUpdateTool / TaskListTool | Config enabled | Works |
| TeamCreateTool / TeamDeleteTool | Agent Swarms config | Works |
| ToolSearchTool | Config enabled | Works |

### Disabled Internal Features (80+ feature flags off)

These Anthropic-internal experimental features are disabled via `feature()` flags and do not affect core CLI usage:

| Feature | Impact |
|---------|--------|
| Voice Mode (`VOICE_MODE`) | Voice input unavailable |
| Proactive Mode (`PROACTIVE`) | SleepTool, proactive alerts unavailable |
| Agent Swarms (`TEAMMEM`, `BG_SESSIONS`) | Multi-agent coordination unavailable |
| Cron Scheduling (`AGENT_TRIGGERS`) | Scheduled triggers unavailable |
| Computer Use (`CHICAGO_MCP`) | Desktop automation unavailable — requires Anthropic internal native modules |
| Claude in Chrome (`CHICAGO_MCP`) | Browser integration unavailable |
| KAIROS (`KAIROS`) | Anthropic internal assistant mode unavailable |
| Transcript Classifier (`TRANSCRIPT_CLASSIFIER`) | Auto permission classification unavailable |

### Stub Tools (auto-filtered, zero runtime impact)

| Tool | Reason |
|------|--------|
| REPLTool | Gated behind `USER_TYPE=ant` |
| SuggestBackgroundPRTool | Gated behind `USER_TYPE=ant` |
| VerifyPlanExecutionTool | Gated behind `CLAUDE_CODE_VERIFY_PLAN` |
| WorkflowTool | Gated behind `feature('WORKFLOW_SCRIPTS')` |
| TungstenTool | Gated behind `USER_TYPE=ant` |

### Missing Internal Packages (no runtime impact)

All `@ant/*` package references are behind `feature()` guards and tree-shaken at build time:

| Package | Purpose | Impact |
|---------|---------|--------|
| `@ant/claude-for-chrome-mcp` | Chrome browser MCP | None — dead code |
| `@ant/computer-use-mcp` | Computer Use MCP | None — dead code |
| `@ant/computer-use-input` | Mouse/keyboard control | None — dead code |
| `@ant/computer-use-swift` | macOS native screenshots | None — dead code |
| `@anthropic-ai/claude-agent-sdk` | SDK type reference | None — `import type` only |

**Summary: All core CLI functionality (file ops, commands, search, API calls, MCP) works. Missing features are Anthropic-internal experiments not available in the official release either.**

---

## Known Limitations

1. **TUI requires a real terminal** — silent exit in pipes or non-TTY environments
2. **API key required** — `ANTHROPIC_API_KEY` must be set for actual queries
3. **macOS Keychain** — falls back to plaintext file on Linux
4. **Sandbox on WSL2** — requires `apt install bubblewrap socat` for sandbox features
5. **Commander.js patch** — multi-character short flags (`-d2e`) need a manual patch to `node_modules` after each `bun install`

