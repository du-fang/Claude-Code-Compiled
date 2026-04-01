#!/bin/bash
# postinstall.sh — Create stubs for Anthropic internal packages
# Run automatically after `bun install` via package.json scripts

set -e

STUBS_DIR="node_modules/@ant"
SANDBOX_DIR="node_modules/@anthropic-ai/sandbox-runtime"

echo "[postinstall] Creating stub packages..."

# ── @ant/claude-for-chrome-mcp ──────────────────────────────────────────────
mkdir -p "$STUBS_DIR/claude-for-chrome-mcp"
cat > "$STUBS_DIR/claude-for-chrome-mcp/package.json" << 'EOF'
{ "name": "@ant/claude-for-chrome-mcp", "version": "0.0.0", "main": "index.js" }
EOF
cat > "$STUBS_DIR/claude-for-chrome-mcp/index.js" << 'EOF'
module.exports = { BROWSER_TOOLS: [], setupClaudeInChrome: () => ({}) };
EOF

# ── @ant/computer-use-input ─────────────────────────────────────────────────
mkdir -p "$STUBS_DIR/computer-use-input"
cat > "$STUBS_DIR/computer-use-input/package.json" << 'EOF'
{ "name": "@ant/computer-use-input", "version": "0.0.0", "main": "index.js" }
EOF
cat > "$STUBS_DIR/computer-use-input/index.js" << 'EOF'
module.exports = {};
EOF

# ── @ant/computer-use-mcp ──────────────────────────────────────────────────
mkdir -p "$STUBS_DIR/computer-use-mcp"
cat > "$STUBS_DIR/computer-use-mcp/package.json" << 'EOF'
{ "name": "@ant/computer-use-mcp", "version": "0.0.0", "main": "index.js" }
EOF
cat > "$STUBS_DIR/computer-use-mcp/index.js" << 'EOF'
module.exports = {
  buildComputerUseTools: () => ({}),
  bindSessionContext: () => ({}),
  DEFAULT_GRANT_FLAGS: {},
  API_RESIZE_PARAMS: {},
  targetImageSize: () => ({ width: 0, height: 0 }),
};
EOF
mkdir -p "$STUBS_DIR/computer-use-mcp/sentinelApps"
cat > "$STUBS_DIR/computer-use-mcp/sentinelApps/index.js" << 'EOF'
module.exports = { getSentinelCategory: () => '' };
EOF
mkdir -p "$STUBS_DIR/computer-use-mcp/types"
cat > "$STUBS_DIR/computer-use-mcp/types/index.js" << 'EOF'
module.exports = { DEFAULT_GRANT_FLAGS: {} };
EOF

# ── @ant/computer-use-swift ─────────────────────────────────────────────────
mkdir -p "$STUBS_DIR/computer-use-swift"
cat > "$STUBS_DIR/computer-use-swift/package.json" << 'EOF'
{ "name": "@ant/computer-use-swift", "version": "0.0.0", "main": "index.js" }
EOF
cat > "$STUBS_DIR/computer-use-swift/index.js" << 'EOF'
module.exports = {};
EOF

# ── @anthropic-ai/sandbox-runtime ───────────────────────────────────────────
# Only create stub if not already installed (e.g. from npm)
if [ ! -f "$SANDBOX_DIR/dist/index.js" ]; then
  echo "[postinstall] Creating sandbox-runtime stub (install @anthropic-ai/sandbox-runtime for real sandboxing)..."
  mkdir -p "$SANDBOX_DIR"
  cat > "$SANDBOX_DIR/package.json" << 'EOF'
{ "name": "@anthropic-ai/sandbox-runtime", "version": "0.0.0-stub", "main": "index.js" }
EOF
  cat > "$SANDBOX_DIR/index.js" << 'STUBEOF'
class SandboxManager {
  static getFsReadConfig() { return null; }
  static getFsWriteConfig() { return null; }
  static getNetworkConfig() { return null; }
  static getNetworkRestrictionConfig() { return null; }
  static isSandboxingEnabled() { return false; }
  static isSupportedPlatform() { return false; }
  static areUnsandboxedCommandsAllowed() { return true; }
  static isAutoAllowBashIfSandboxedEnabled() { return false; }
  static getSandboxConfig() { return null; }
  static refreshConfig() {}
  static reset() { return Promise.resolve(); }
  static wrapWithSandbox(cmd) { return Promise.resolve(cmd); }
  static getExcludedCommands() { return []; }
  static getSandboxSettings() { return null; }
  static setSandboxSettings() {}
  static getIgnoreViolations() { return null; }
  static getIgnoreViolationsConfig() { return null; }
  static checkDependencies() { return { errors: [], warnings: [] }; }
  static initialize() { return Promise.resolve(); }
  static updateConfig() {}
  static getAllowUnixSockets() { return undefined; }
  static getAllowLocalBinding() { return undefined; }
  static getEnableWeakerNestedSandbox() { return undefined; }
  static getProxyPort() { return undefined; }
  static getSocksProxyPort() { return undefined; }
  static getLinuxHttpSocketPath() { return undefined; }
  static getLinuxSocksSocketPath() { return undefined; }
  static waitForNetworkInitialization() { return Promise.resolve(true); }
  static cleanupAfterCommand() {}
  static getSandboxViolationStore() { return new SandboxViolationStore(); }
  static annotateStderrWithSandboxFailures(_cmd, stderr) { return stderr; }
  static getLinuxGlobPatternWarnings() { return []; }
}
class SandboxViolationStore {
  constructor() {}
  addViolation() {}
  getViolations() { return []; }
  clear() {}
}
const SandboxRuntimeConfigSchema = {
  parse: (x) => x,
  safeParse: (x) => ({ success: true, data: x }),
};
module.exports = { SandboxManager, SandboxViolationStore, SandboxRuntimeConfigSchema };
STUBEOF
fi

echo "[postinstall] Stubs created."

# ── Patch Commander.js for multi-char short flags ───────────────────────────
OPTION_JS=$(find node_modules -path "*/commander/lib/option.js" -type f | head -1)
if [ -n "$OPTION_JS" ]; then
  # Patch 1: shortFlagExp — allow one or more chars after dash
  sed -i "s|shortFlagExp = /\^-\\[^-\\]\\$/|shortFlagExp = /\^-[^-]+\$/|" "$OPTION_JS"
  # Patch 2: disable single-char short flag restriction
  sed -i "s|if (/\\^-\\[^-\\]\\[^-\\]/.test(unsupportedFlag))|if (false)|" "$OPTION_JS"
  echo "[postinstall] Patched Commander.js for multi-char short flags"
fi
