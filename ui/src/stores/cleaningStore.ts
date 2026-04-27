// src/stores/cleaningStore.ts
import { atom, map } from 'nanostores';
import type { CleaningResponse, ExtensionScanResponse, PromptStepResponse, TreeComparisonResponse } from '../lib/api';

export const activeCleaning   = atom<CleaningResponse | null>(null);
export const scanResult        = atom<ExtensionScanResponse | null>(null);
export const steps             = atom<PromptStepResponse[]>([]);
export const treeComparison    = atom<TreeComparisonResponse | null>(null);
export const isLoading         = atom<boolean>(false);
export const currentError      = atom<string | null>(null);

// Unknown extension modal
export const unknownExtModal = map<{
  open: boolean; extensions: string[]; current: string | null;
}>({ open: false, extensions: [], current: null });

export function openUnknownExtModal(exts: string[]) {
  unknownExtModal.set({ open: true, extensions: exts, current: exts[0] ?? null });
}
export function closeUnknownExtModal() {
  unknownExtModal.set({ open: false, extensions: [], current: null });
}

// Execution target modal
export const execTargetModal = map<{
  open: boolean;
  cleaningId: string | null;
  /** 'source' = picked source path, 'alternate' = entered alternate path */
  mode: 'source' | 'alternate' | null;
  // 'source' confirm flow: 'warn1' = first warning, 'confirm' = second/final
  sourceStep: 'warn1' | 'confirm' | null;
  alternatePath: string;
}>({
  open: false, cleaningId: null, mode: null, sourceStep: null, alternatePath: ''
});

export function openExecTargetModal(cleaningId: string) {
  execTargetModal.set({
    open: true, cleaningId, mode: null,
    sourceStep: null, alternatePath: ''
  });
}
export function closeExecTargetModal() {
  execTargetModal.set({
    open: false, cleaningId: null, mode: null, sourceStep: null, alternatePath: ''
  });
}
