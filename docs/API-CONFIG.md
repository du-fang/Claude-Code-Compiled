# Claude Code API 配置指南

> 基于 2026-03-31 泄露的 Claude Code CLI 源码
> 最后更新：2026-04-01

---

## 1. API 提供商概览

Claude Code 支持 **4 种 API 后端**，通过环境变量切换：

| 提供商 | 启用变量 | 说明 |
|--------|----------|------|
| **Direct API** | 默认（无需设置） | Anthropic 官方 API |
| **AWS Bedrock** | `CLAUDE_CODE_USE_BEDROCK=1` | AWS 托管的 Claude |
| **Google Vertex AI** | `CLAUDE_CODE_USE_VERTEX=1` | GCP 托管的 Claude |
| **Azure Foundry** | `CLAUDE_CODE_USE_FOUNDRY=1` | Azure 托管的 Claude |

优先级判断逻辑（`src/utils/model/providers.ts`）：

```typescript
export function getAPIProvider(): APIProvider {
  return isEnvTruthy(process.env.CLAUDE_CODE_USE_BEDROCK) ? 'bedrock'
    : isEnvTruthy(process.env.CLAUDE_CODE_USE_VERTEX) ? 'vertex'
    : isEnvTruthy(process.env.CLAUDE_CODE_USE_FOUNDRY) ? 'foundry'
    : 'firstParty'
}
```

---

## 2. Direct API（默认）

### 2.1 认证

| 环境变量 | 必需 | 说明 |
|----------|------|------|
| `ANTHROPIC_API_KEY` | ✅ | Anthropic API 密钥 |
| `ANTHROPIC_AUTH_TOKEN` | — | Bearer token 替代方式 |

**二选一**，`ANTHROPIC_API_KEY` 优先级更高。也支持 OAuth 登录（`/login` 命令），token 存储在 `~/.claude/` 配置目录。

### 2.2 端点配置

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `ANTHROPIC_BASE_URL` | `https://api.anthropic.com` | API 基础 URL |
| `ANTHROPIC_UNIX_SOCKET` | — | Unix socket 路径（替代 TCP） |

自定义代理或本地网关时设置 `ANTHROPIC_BASE_URL`。代码中通过 `isFirstPartyAnthropicBaseUrl()` 判断是否为官方端点：

```typescript
export function isFirstPartyAnthropicBaseUrl(): boolean {
  const baseUrl = process.env.ANTHROPIC_BASE_URL
  if (!baseUrl) return true
  const host = new URL(baseUrl).host
  return ['api.anthropic.com'].includes(host)
}
```

### 2.3 模型选择

| 环境变量 | 说明 |
|----------|------|
| `ANTHROPIC_MODEL` | 主循环模型（最高优先级的用户可配变量） |
| `ANTHROPIC_SMALL_FAST_MODEL` | 轻量模型（默认 Haiku，用于 token 估算等） |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | 覆盖默认 Opus 模型 |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | 覆盖默认 Sonnet 模型 |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | 覆盖默认 Haiku 模型 |

**模型选择优先级**（`getMainLoopModel()`）：

1. 会话中 `/model` 命令覆盖 — 最高
2. `--model` CLI 参数
3. `ANTHROPIC_MODEL` 环境变量
4. 用户 settings 中保存的模型
5. 内置默认值（Sonnet）

### 2.4 Beta 功能

| 环境变量 | 说明 |
|----------|------|
| `ANTHROPIC_BETAS` | 追加 beta header（逗号分隔） |

Claude Code 内部会自动附加多个 beta header，如 `files-api-2025-04-14`、`oauth-2025-04-20` 等。

### 2.5 请求自定义

| 环境变量 | 说明 |
|----------|------|
| `ANTHROPIC_CUSTOM_HEADERS` | 自定义 HTTP 头（JSON 格式） |
| `CLAUDE_CODE_EXTRA_BODY` | 请求体额外字段（JSON 格式） |

---

## 3. AWS Bedrock

### 3.1 启用

```bash
export CLAUDE_CODE_USE_BEDROCK=1
```

### 3.2 认证

使用 AWS SDK 默认凭证链（`@aws-sdk/credential-provider-node`）：

- 环境变量：`AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` + `AWS_SESSION_TOKEN`
- AWS CLI 配置：`~/.aws/credentials`
- IAM Role（EC2 / ECS / Lambda）
- SSO

跳过 Bedrock 认证检查（开发/测试用）：

```bash
export CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
```

### 3.3 区域配置

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `AWS_REGION` / `AWS_DEFAULT_REGION` | `us-east-1` | 全局 AWS 区域 |
| `ANTHROPIC_SMALL_FAST_MODEL_AWS_REGION` | — | 轻量模型独立区域 |

### 3.4 端点

| 环境变量 | 说明 |
|----------|------|
| `ANTHROPIC_BEDROCK_BASE_URL` | 自定义 Bedrock 端点 |

---

## 4. Google Vertex AI

### 4.1 启用

```bash
export CLAUDE_CODE_USE_VERTEX=1
```

### 4.2 认证

使用 `google-auth-library` 默认凭证链：

- `GOOGLE_APPLICATION_CREDENTIALS` — 服务账号 JSON 路径
- `gcloud auth application-default login` — 用户凭证
- Workload Identity（GKE / Cloud Run）

跳过 Vertex 认证检查：

```bash
export CLAUDE_CODE_SKIP_VERTEX_AUTH=1
```

### 4.3 项目与区域

| 环境变量 | 必需 | 说明 |
|----------|------|------|
| `ANTHROPIC_VERTEX_PROJECT_ID` | ✅ | GCP 项目 ID |
| `CLOUD_ML_REGION` | — | 默认区域（回退 `us-east5`） |
| `VERTEX_REGION_CLAUDE_3_5_HAIKU` | — | Claude 3.5 Haiku 专属区域 |
| `VERTEX_REGION_CLAUDE_HAIKU_4_5` | — | Claude Haiku 4.5 专属区域 |
| `VERTEX_REGION_CLAUDE_3_5_SONNET` | — | Claude 3.5 Sonnet 专属区域 |
| `VERTEX_REGION_CLAUDE_3_7_SONNET` | — | Claude 3.7 Sonnet 专属区域 |

区域优先级：模型专属变量 > `CLOUD_ML_REGION` > 配置默认 > `us-east5`。

---

## 5. Azure Foundry

### 5.1 启用

```bash
export CLAUDE_CODE_USE_FOUNDRY=1
```

### 5.2 端点配置（二选一）

| 环境变量 | 说明 |
|----------|------|
| `ANTHROPIC_FOUNDRY_RESOURCE` | Azure 资源名，自动生成端点 `https://{resource}.services.ai.azure.com/anthropic/v1/messages` |
| `ANTHROPIC_FOUNDRY_BASE_URL` | 完整端点 URL（优先级更高） |

### 5.3 认证

| 方式 | 环境变量 | 说明 |
|------|----------|------|
| API Key | `ANTHROPIC_FOUNDRY_API_KEY` | 直接使用密钥 |
| Azure AD | — | 无 API key 时自动使用 `DefaultAzureCredential` |

Azure AD 支持的凭证方式：环境变量、Managed Identity、Azure CLI、Visual Studio Code 等。

跳过 Foundry 认证检查：

```bash
export CLAUDE_CODE_SKIP_FOUNDRY_AUTH=1
```

---

## 6. 代理（Proxy）

### 6.1 HTTP 代理

| 环境变量 | 优先级 | 说明 |
|----------|--------|------|
| `https_proxy` | 1 | 小写（最高优先级） |
| `HTTPS_PROXY` | 2 | 大写 |
| `http_proxy` | 3 | HTTP 代理 |
| `HTTP_PROXY` | 4 | HTTP 大写 |
| `no_proxy` / `NO_PROXY` | — | 代理排除列表 |

### 6.2 代理行为

```typescript
export function getProxyUrl(): string | undefined {
  return env.https_proxy || env.HTTPS_PROXY || env.http_proxy || env.HTTP_PROXY
}
```

`NO_PROXY` 支持逗号分隔的域名/IP 列表，支持通配符 `*`。

### 6.3 代理 DNS 解析

```bash
# 让代理端解析域名（适用于沙箱环境）
export CLAUDE_CODE_PROXY_RESOLVES_HOSTS=1
```

---

## 7. mTLS 与 TLS 配置

| 环境变量 | 说明 |
|----------|------|
| `CLAUDE_CODE_CLIENT_CERT` | 客户端证书文件路径 |
| `CLAUDE_CODE_CLIENT_KEY` | 客户端私钥文件路径 |
| `CLAUDE_CODE_CLIENT_KEY_PASSPHRASE` | 私钥密码 |
| `NODE_EXTRA_CA_CERTS` | 额外 CA 证书（Node.js 自动加载） |

---

## 8. OAuth 认证

### 8.1 流程

Claude Code 实现了完整的 OAuth 2.0 流程（`src/services/oauth/`）：

1. 用户执行 `/login`
2. 浏览器打开 Anthropic 授权页面
3. 用户授权后回调到本地监听端口
4. 交换 access_token / refresh_token
5. Token 存储在 `~/.claude/` 安全存储中

### 8.2 OAuth Scopes

| Scope | 用途 |
|-------|------|
| `user:inference` | API 推理调用 |
| `user:profile` | 用户信息读取 |
| `user:sessions:claude_code` | Claude Code 会话管理 |
| `user:mcp_servers` | MCP 服务器管理 |
| `user:file_upload` | 文件上传 |
| `org:create_api_key` | Console 端 API key 创建 |

### 8.3 OAuth 环境变量

| 环境变量 | 说明 |
|----------|------|
| `CLAUDE_CODE_OAUTH_CLIENT_ID` | 自定义 OAuth client ID |
| `CLAUDE_CODE_OAUTH_TOKEN` | 直接注入 OAuth token |
| `CLAUDE_CODE_OAUTH_REFRESH_TOKEN` | 注入 refresh token |
| `CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR` | 从文件描述符读取 token |
| `CLAUDE_CODE_CUSTOM_OAUTH_URL` | 自定义 OAuth 端点 URL |

---

## 9. 其他关键配置

### 9.1 会话与上下文

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `CLAUDE_CODE_MAX_CONTEXT_TOKENS` | — | 最大上下文 token 数 |
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | — | 最大输出 token 数 |
| `CLAUDE_CODE_MAX_RETRIES` | — | API 重试次数 |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | — | 自动压缩窗口大小 |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | — | 压缩阈值百分比 |

### 9.2 功能开关

| 环境变量 | 说明 |
|----------|------|
| `CLAUDE_CODE_DISABLE_THINKING` | 禁用 thinking 模式 |
| `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING` | 禁用自适应 thinking |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | 禁用非必要网络请求 |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY` | 禁用自动记忆提取 |
| `CLAUDE_CODE_DISABLE_CRON` | 禁用定时任务 |
| `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` | 禁用后台任务 |
| `CLAUDE_CODE_ALWAYS_ENABLE_EFFORT` | 始终启用 extended thinking |
| `CLAUDE_CODE_EFFORT_LEVEL` | thinking effort 级别 |
| `CLAUDE_CODE_SIMPLE` | 简化模式（减少输出） |
| `CLAUDE_CODE_BRIEF` | 简洁模式 |

### 9.3 调试与诊断

| 环境变量 | 说明 |
|----------|------|
| `CLAUDE_DEBUG` | 调试模式 |
| `CLAUDE_CODE_DEBUG_LOGS_DIR` | 调试日志目录 |
| `CLAUDE_CODE_DEBUG_LOG_LEVEL` | 调试日志级别 |
| `CLAUDE_CODE_PROFILE_STARTUP` | 启动性能分析 |
| `CLAUDE_CODE_PROFILE_QUERY` | 查询性能分析 |
| `CLAUDE_CODE_DIAGNOSTICS_FILE` | 诊断输出文件 |
| `CLAUDE_CODE_JSONL_TRANSCRIPT` | JSONL 格式对话记录 |

### 9.4 配置目录

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `CLAUDE_CONFIG_DIR` | `~/.claude` | 配置目录 |

配置目录结构：

```
~/.claude/
├── config.json          # 全局配置（模型、设置）
├── settings.json        # 用户设置
├── oauth-tokens.json    # OAuth token 存储
├── mcp-servers.json     # MCP 服务器配置
├── projects/            # 项目级配置
└── memory/              # 持久化记忆
```

---

## 10. 自定义模型选项

允许在模型选择菜单中添加自定义模型：

| 环境变量 | 说明 |
|----------|------|
| `ANTHROPIC_CUSTOM_MODEL_OPTION` | 自定义模型 ID |
| `ANTHROPIC_CUSTOM_MODEL_OPTION_NAME` | 显示名称 |
| `ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION` | 模型描述 |

---

## 11. 完整配置示例

### 11.1 Direct API（最简）

```bash
export ANTHROPIC_API_KEY=sk-ant-xxx
bun dist/bundle.js -p "hello"
```

### 11.2 自定义代理

```bash
export ANTHROPIC_API_KEY=sk-ant-xxx
export ANTHROPIC_BASE_URL=https://my-proxy.example.com
bun dist/bundle.js
```

### 11.3 AWS Bedrock

```bash
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=us-west-2
export AWS_ACCESS_KEY_ID=AKIAxxx
export AWS_SECRET_ACCESS_KEY=xxx
bun dist/bundle.js
```

### 11.4 Vertex AI

```bash
export CLAUDE_CODE_USE_VERTEX=1
export ANTHROPIC_VERTEX_PROJECT_ID=my-gcp-project
export CLOUD_ML_REGION=us-central1
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
bun dist/bundle.js
```

### 11.5 Azure Foundry + API Key

```bash
export CLAUDE_CODE_USE_FOUNDRY=1
export ANTHROPIC_FOUNDRY_RESOURCE=my-azure-resource
export ANTHROPIC_FOUNDRY_API_KEY=xxx
bun dist/bundle.js
```

### 11.6 带代理 + mTLS

```bash
export ANTHROPIC_API_KEY=sk-ant-xxx
export HTTPS_PROXY=http://proxy.corp.com:8080
export NO_PROXY=localhost,127.0.0.1
export CLAUDE_CODE_CLIENT_CERT=/path/to/client.pem
export CLAUDE_CODE_CLIENT_KEY=/path/to/client-key.pem
bun dist/bundle.js
```

### 11.7 调试模式

```bash
export ANTHROPIC_API_KEY=sk-ant-xxx
export CLAUDE_DEBUG=1
export CLAUDE_CODE_DEBUG_LOGS_DIR=/tmp/claude-debug
export CLAUDE_CODE_DEBUG_LOG_LEVEL=verbose
bun dist/bundle.js
```

---

## 12. 认证优先级

Claude Code 的认证解析顺序（`src/utils/auth.ts`）：

1. **文件描述符注入** — `CLAUDE_CODE_API_KEY_FILE_DESCRIPTOR` / `CLAUDE_CODE_OAUTH_TOKEN_FILE_DESCRIPTOR`
2. **环境变量** — `ANTHROPIC_API_KEY` / `CLAUDE_CODE_OAUTH_TOKEN`
3. **macOS Keychain** — 安全存储的凭证
4. **配置文件** — `~/.claude/config.json` 中的 API key
5. **API key helper** — `CLAUDE_CODE_API_KEY_HELPER_TTL_MS` 控制的外部脚本
6. **OAuth 登录** — `/login` 流程获取的 token

---

## 13. 注意事项

1. **`isFirstPartyAnthropicBaseUrl()` 影响行为** — 只有指向 `api.anthropic.com` 时才被视为官方端点，影响 bootstrap 请求、模型默认值等
2. **第三方提供商模型延迟** — Bedrock/Vertex/Foundry 的模型可用性滞后于 Direct API，代码中为它们保留了独立的默认模型分支
3. **macOS Keychain 回退** — Linux 环境下安全存储回退到明文文件，注意权限控制
4. **代理 + mTLS 同时使用** — 代码同时支持 HTTPS 代理 + 客户端证书认证，按需组合
5. **OAuth token 自动刷新** — `withOAuth401Retry()` 会自动处理 401 错误并刷新 token
