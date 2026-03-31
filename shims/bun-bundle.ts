// shims/bun-bundle.ts
// Shim for bun:bundle feature flags
// In real Bun builds, these are compile-time constants
export function feature(name: string): boolean {
  const flags: Record<string, boolean> = {
    WORKFLOW_SCRIPTS: false,
    AGENT_TRIGGERS: false,
  };
  return flags[name] ?? false;
}
