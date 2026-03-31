import { useCallback, useRef } from 'react';

// Shim for useEffectEvent (React 19 experimental, not in react-reconciler 0.31)
// Uses useRef to always call the latest callback without re-firing effects
export function useEffectEvent<T extends (...args: any[]) => any>(callback: T): T {
  const ref = useRef(callback);
  ref.current = callback;
  return useCallback(((...args: any[]) => ref.current(...args)) as T, []);
}
