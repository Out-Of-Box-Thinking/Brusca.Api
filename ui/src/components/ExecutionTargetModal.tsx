// src/components/ExecutionTargetModal.tsx
import { useState } from 'react';
import { useStore } from '@nanostores/react';
import {
  execTargetModal, closeExecTargetModal, activeCleaning
} from '../stores/cleaningStore';
import { api } from '../lib/api';

export default function ExecutionTargetModal({
  onTargetSet
}: {
  onTargetSet: () => void;
}) {
  const modal = useStore(execTargetModal);
  const cleaning = useStore(activeCleaning);
  const [saving, setSaving] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  if (!modal.open || !modal.cleaningId || !cleaning) return null;

  // ── Step 0: choose source vs alternate ──────────────────────────────────────
  if (!modal.mode) {
    return (
      <Overlay>
        <h2 className="text-lg font-semibold mb-1">Choose execution target</h2>
        <p className="text-sm text-gray-500 mb-5">
          Where should Brusca apply the rename and move operations?
        </p>
        <div className="space-y-3">
          <button
            onClick={() => execTargetModal.set({ ...modal, mode: 'alternate' })}
            className="w-full text-left border border-gray-200 rounded-xl p-4 hover:border-indigo-400 hover:bg-indigo-50 transition-colors group"
          >
            <div className="font-medium text-sm mb-0.5 group-hover:text-indigo-700">
              Use an alternate path <span className="text-xs font-normal text-green-600 ml-1">Recommended</span>
            </div>
            <div className="text-xs text-gray-500">
              Copy changes to a staging directory. Your originals are untouched.
            </div>
          </button>
          <button
            onClick={() => execTargetModal.set({ ...modal, mode: 'source', sourceStep: 'warn1' })}
            className="w-full text-left border border-red-200 rounded-xl p-4 hover:border-red-400 hover:bg-red-50 transition-colors group"
          >
            <div className="font-medium text-sm mb-0.5 group-hover:text-red-700 text-red-600">
              Apply directly to source path
            </div>
            <div className="text-xs text-gray-500 font-mono truncate">{cleaning.rootPath}</div>
          </button>
        </div>
        <div className="mt-4 flex justify-end">
          <button onClick={closeExecTargetModal}
            className="text-sm text-gray-500 hover:text-gray-700">
            Cancel
          </button>
        </div>
      </Overlay>
    );
  }

  // ── Alternate path form ──────────────────────────────────────────────────────
  if (modal.mode === 'alternate') {
    return (
      <Overlay>
        <h2 className="text-lg font-semibold mb-1">Alternate execution path</h2>
        <p className="text-sm text-gray-500 mb-4">
          Brusca will copy the directory structure here and apply all approved steps.
          Your original files at <code className="bg-gray-100 px-1 py-0.5 rounded text-xs">{cleaning.rootPath}</code> will not be modified.
        </p>
        <input
          className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm font-mono focus:outline-none focus:ring-2 focus:ring-indigo-500 mb-1"
          placeholder="\\server\staging\brusca-output  or  C:\Temp\cleaned"
          value={modal.alternatePath}
          onChange={e => execTargetModal.set({ ...modal, alternatePath: e.target.value })}
          autoFocus
        />
        {err && <p className="text-xs text-red-600 mb-2">{err}</p>}
        <div className="flex gap-2 justify-end mt-4">
          <button onClick={() => execTargetModal.set({ ...modal, mode: null })}
            className="text-sm text-gray-500 hover:text-gray-700">
            Back
          </button>
          <button
            disabled={!modal.alternatePath.trim() || saving}
            onClick={async () => {
              setSaving(true); setErr(null);
              try {
                await api.cleanings.setExecutionTarget(
                  modal.cleaningId!, 'AlternatePath', modal.alternatePath.trim());
                activeCleaning.set({ ...cleaning,
                  executionTarget: 'AlternatePath',
                  alternateExecutionPath: modal.alternatePath.trim() });
                closeExecTargetModal();
                onTargetSet();
              } catch (e: any) { setErr(e.message); }
              finally { setSaving(false); }
            }}
            className="bg-indigo-600 text-white text-sm px-4 py-2 rounded-lg disabled:opacity-50 hover:bg-indigo-700 transition-colors"
          >
            {saving ? 'Saving…' : 'Confirm alternate path'}
          </button>
        </div>
      </Overlay>
    );
  }

  // ── Source path: first warning ───────────────────────────────────────────────
  if (modal.mode === 'source' && modal.sourceStep === 'warn1') {
    return (
      <Overlay warning>
        <div className="flex items-center gap-2 mb-3">
          <span className="text-2xl">⚠️</span>
          <h2 className="text-lg font-semibold text-red-700">You are about to modify the original files</h2>
        </div>
        <p className="text-sm text-gray-700 mb-2">
          Applying changes directly to the source path will <strong>permanently rename and move</strong> files and directories at:
        </p>
        <div className="bg-red-50 border border-red-200 rounded-lg p-3 font-mono text-sm text-red-800 mb-4 break-all">
          {cleaning.rootPath}
        </div>
        <p className="text-sm text-gray-600 mb-4">
          This action <strong>cannot be undone</strong> by Brusca. Make sure you have a backup before proceeding.
        </p>
        <div className="flex gap-2 justify-end">
          <button onClick={closeExecTargetModal}
            className="text-sm bg-gray-100 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-200">
            Cancel — use alternate path instead
          </button>
          <button
            onClick={() => execTargetModal.set({ ...modal, sourceStep: 'confirm' })}
            className="text-sm bg-red-600 text-white px-4 py-2 rounded-lg hover:bg-red-700 transition-colors"
          >
            I understand — proceed
          </button>
        </div>
      </Overlay>
    );
  }

  // ── Source path: final confirmation ─────────────────────────────────────────
  if (modal.mode === 'source' && modal.sourceStep === 'confirm') {
    return (
      <Overlay warning>
        <div className="flex items-center gap-2 mb-3">
          <span className="text-2xl">🔴</span>
          <h2 className="text-lg font-semibold text-red-700">Final confirmation</h2>
        </div>
        <p className="text-sm text-gray-700 mb-4">
          Are you absolutely sure you want to apply all approved steps directly to the source path?
        </p>
        <div className="bg-red-100 border border-red-300 rounded-lg p-3 font-mono text-sm text-red-900 mb-4 break-all">
          {cleaning.rootPath}
        </div>
        {err && <p className="text-xs text-red-600 mb-2">{err}</p>}
        <div className="flex gap-2 justify-end">
          <button onClick={() => execTargetModal.set({ ...modal, sourceStep: 'warn1' })}
            className="text-sm text-gray-500 hover:text-gray-700">
            Back
          </button>
          <button
            disabled={saving}
            onClick={async () => {
              setSaving(true); setErr(null);
              try {
                await api.cleanings.setExecutionTarget(modal.cleaningId!, 'SourcePath');
                activeCleaning.set({ ...cleaning,
                  executionTarget: 'SourcePath', alternateExecutionPath: undefined });
                closeExecTargetModal();
                onTargetSet();
              } catch (e: any) { setErr(e.message); }
              finally { setSaving(false); }
            }}
            className="bg-red-600 text-white text-sm px-4 py-2 rounded-lg hover:bg-red-700 disabled:opacity-50 transition-colors"
          >
            {saving ? 'Saving…' : 'Yes, apply to source'}
          </button>
        </div>
      </Overlay>
    );
  }

  return null;
}

// ── Overlay wrapper ───────────────────────────────────────────────────────────
function Overlay({ children, warning }: { children: React.ReactNode; warning?: boolean }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className={`bg-white rounded-xl shadow-xl w-full max-w-lg p-6 mx-4
        ${warning ? 'ring-2 ring-red-400' : ''}`}>
        {children}
      </div>
    </div>
  );
}
