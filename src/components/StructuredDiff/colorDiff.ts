import {
  getNativeModule,
  type SyntaxTheme,
} from '../../native-ts/color-diff/index.js'
import { isEnvDefinedFalsy } from '../../utils/envUtils.js'

type NativeColorModule = NonNullable<ReturnType<typeof getNativeModule>>

export type ColorModuleUnavailableReason = 'env'

/**
 * Returns a static reason why the color-diff module is unavailable, or null if available.
 * 'env' = disabled via CLAUDE_CODE_SYNTAX_HIGHLIGHT
 *
 * The TS port of color-diff works in all build modes, so the only way to
 * disable it is via the env var.
 */
export function getColorModuleUnavailableReason(): ColorModuleUnavailableReason | null {
  if (isEnvDefinedFalsy(process.env.CLAUDE_CODE_SYNTAX_HIGHLIGHT)) {
    return 'env'
  }
  return null
}

export function expectColorDiff(): NativeColorModule['ColorDiff'] | null {
  return getColorModuleUnavailableReason() === null
    ? (getNativeModule()?.ColorDiff ?? null)
    : null
}

export function expectColorFile(): NativeColorModule['ColorFile'] | null {
  return getColorModuleUnavailableReason() === null
    ? (getNativeModule()?.ColorFile ?? null)
    : null
}

export function getSyntaxTheme(themeName: string): SyntaxTheme | null {
  return getColorModuleUnavailableReason() === null
    ? (getNativeModule()?.getSyntaxTheme(themeName) ?? null)
    : null
}
