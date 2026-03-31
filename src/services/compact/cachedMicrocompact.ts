export type CachedMCState = Record<string, unknown>
export type CacheEditsBlock = Record<string, unknown>

export function isCachedMicrocompactEnabled(): boolean { return false }
export function isModelSupportedForCacheEditing(_model: string): boolean { return false }
export function getCachedMCConfig(): Record<string, unknown> { return { supportedModels: [] } }
export function createCachedMCState(): CachedMCState { return {} }
export function resetCachedMCState(_state: CachedMCState): void {}
