// src/components/CleaningDashboard.tsx
import { useState, useCallback } from 'react';
import { useStore } from '@nanostores/react';
import {
  activeCleaning, scanResult, steps, treeComparison,
  isLoading, currentError,
  unknownExtModal, openUnknownExtModal, closeUnknownExtModal,
  openExecTargetModal
} from '../stores/cleaningStore';
import { api } from '../lib/api';
import type { PromptStepCommandResponse } from '../lib/api';
import TreeComparison from './TreeComparison';
import ExecutionTargetModal from './ExecutionTargetModal';

// ── Status badge ──────────────────────────────────────────────────────────────
function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    Pending: 'bg-gray-100 text-gray-600',
    Scanning: 'bg-blue-100 text-blue-700',
    AwaitingExtensionResolution: 'bg-amber-100 text-amber-700',
    Analyzing: 'bg-purple-100 text-purple-700',
    PromptGenerated: 'bg-indigo-100 text-indigo-700',
    Executing: 'bg-orange-100 text-orange-700',
    Completed: 'bg-green-100 text-green-700',
    Failed: 'bg-red-100 text-red-700',
    Restarted: 'bg-teal-100 text-teal-700',
  };
  return (
    <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${colors[status] ?? 'bg-gray-100 text-gray-500'}`}>
      {status}
    </span>
  );
}

// ── Unknown extension modal ───────────────────────────────────────────────────
function UnknownExtensionModal() {
  const modal = useStore(unknownExtModal);
  const [pkg, setPkg] = useState('');
  const [saving, setSaving] = useState(false);
  if (!modal.open || !modal.current) return null;

  async function handleSave() {
    if (!pkg.trim() || !modal.current) return;
    setSaving(true);
    await api.extensions.registerPackage(modal.current, pkg.trim());
    setSaving(false);
    setPkg('');
    const remaining = modal.extensions.filter(e => e !== modal.current);
    if (remaining.length === 0) closeUnknownExtModal();
    else unknownExtModal.set({ open: true, extensions: remaining, current: remaining[0] });
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
      <div className="bg-white rounded-xl shadow-xl w-full max-w-md p-6">
        <h2 className="text-lg font-semibold mb-1">Unknown file extension</h2>
        <p className="text-sm text-gray-500 mb-4">
          <code className="bg-gray-100 px-1.5 py-0.5 rounded font-mono text-sm">{modal.current}</code> has
          no registered reader. Enter the NuGet package, implement the reader, then recompile.
          <strong className="block mt-1 text-amber-700">
            The app remains blocked until all unknown extensions are resolved.
          </strong>
        </p>
        <p className="text-xs text-gray-400 mb-2">
          You can restart the Cleaning after recompiling to re-scan with the new reader.
        </p>
        <input
          className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          placeholder="e.g. ExcelDataReader"
          value={pkg}
          onChange={e => setPkg(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && handleSave()}
          autoFocus
        />
        <div className="flex gap-2 justify-end mt-4">
          <span className="text-xs text-gray-400 self-center mr-auto">
            {modal.extensions.length} pending
          </span>
          <button disabled={!pkg.trim() || saving} onClick={handleSave}
            className="bg-indigo-600 text-white text-sm px-4 py-2 rounded-lg disabled:opacity-50 hover:bg-indigo-700">
            {saving ? 'Saving…' : 'Register & continue'}
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Command viewer (collapsible) ──────────────────────────────────────────────
function CommandViewer({ commands }: { commands: PromptStepCommandResponse[] }) {
  const [open, setOpen] = useState(false);
  const [selectedLang, setSelectedLang] = useState<string | null>(null);
  if (commands.length === 0) return null;

  const langs = [...new Set(commands.map(c => c.language))];
  const active = selectedLang ?? langs[0] ?? null;
  const cmd = commands.find(c => c.language === active);

  const LANG_STYLE: Record<string, string> = {
    CSharp:     'text-purple-700 bg-purple-50 border-purple-200',
    Cmd:        'text-amber-700 bg-amber-50 border-amber-200',
    PowerShell: 'text-blue-700 bg-blue-50 border-blue-200',
  };

  return (
    <div className="mt-2">
      <button onClick={() => setOpen(o => !o)}
        className="text-xs text-indigo-600 hover:text-indigo-800 flex items-center gap-1">
        {open ? '▾' : '▸'} {langs.length} command{langs.length !== 1 ? 's' : ''} ({langs.join(' · ')})
      </button>
      {open && (
        <div className="mt-2 rounded-lg border border-gray-200 overflow-hidden">
          <div className="flex border-b border-gray-200 bg-gray-50">
            {langs.map(lang => (
              <button key={lang} onClick={() => setSelectedLang(lang)}
                className={`text-xs px-3 py-1.5 font-medium border-r border-gray-200 transition-colors
                  ${active === lang ? (LANG_STYLE[lang] ?? 'bg-white text-gray-700') : 'text-gray-500 hover:text-gray-700'}`}>
                {lang}
                {cmd?.isExecuted && active === lang && !cmd.executionError &&
                  <span className="ml-1 text-green-600">✓</span>}
              </button>
            ))}
            <span className="ml-auto text-xs text-gray-400 self-center pr-2">
              {cmd?.id?.slice(0, 8)}…
            </span>
          </div>
          {cmd && (
            <pre className="text-xs p-3 bg-gray-950 text-green-400 overflow-x-auto max-h-48 font-mono leading-relaxed whitespace-pre-wrap">
              {cmd.commandBody}
            </pre>
          )}
          {cmd?.executionError && (
            <div className="text-xs text-red-600 bg-red-50 px-3 py-2 border-t border-red-200">
              Error: {cmd.executionError}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ── Start form ────────────────────────────────────────────────────────────────
function StartCleaningForm({ onStarted }: { onStarted: (id: string) => void }) {
  const [path, setPath] = useState('');
  const [busy, setBusy] = useState(false);

  async function handleStart() {
    if (!path.trim()) return;
    setBusy(true); currentError.set(null);
    try {
      const res = await api.cleanings.start(path.trim());
      if (res.success && res.data) {
        activeCleaning.set(res.data);
        onStarted(res.data.id);
      } else currentError.set(res.errors?.join(', ') ?? 'Failed');
    } catch (e: any) { currentError.set(e.message); }
    finally { setBusy(false); }
  }

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6">
      <h2 className="font-semibold text-base mb-4">Start a new cleaning</h2>
      <div className="flex gap-3">
        <input
          className="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm font-mono focus:outline-none focus:ring-2 focus:ring-indigo-500"
          placeholder="\\server\share\path  or  C:\Users\files"
          value={path}
          onChange={e => setPath(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && handleStart()}
        />
        <button disabled={!path.trim() || busy} onClick={handleStart}
          className="bg-indigo-600 text-white text-sm px-5 py-2 rounded-lg disabled:opacity-50 hover:bg-indigo-700 whitespace-nowrap">
          {busy ? 'Starting…' : 'Start cleaning'}
        </button>
      </div>
    </div>
  );
}

// ── Workflow panel ────────────────────────────────────────────────────────────
function WorkflowPanel({ cleaningId }: { cleaningId: string }) {
  const cleaning = useStore(activeCleaning);
  const scan = useStore(scanResult);
  const stepList = useStore(steps);
  const tree = useStore(treeComparison);
  const loading = useStore(isLoading);
  const err = useStore(currentError);
  const [activeTab, setActiveTab] = useState<'steps' | 'tree'>('steps');

  const refreshCleaning = useCallback(async () => {
    const res = await api.cleanings.getById(cleaningId);
    if (res.success && res.data) activeCleaning.set(res.data);
  }, [cleaningId]);

  const loadTree = useCallback(async () => {
    const res = await api.cleanings.getTreeComparison(cleaningId);
    if (res.success && res.data) treeComparison.set(res.data);
  }, [cleaningId]);

  async function doScan() {
    isLoading.set(true); currentError.set(null);
    try {
      const res = await api.cleanings.scan(cleaningId);
      if (res.success && res.data) {
        scanResult.set(res.data);
        await refreshCleaning();
        if (res.data.unknownExtensions.length > 0)
          openUnknownExtModal(res.data.unknownExtensions);
      } else currentError.set(res.errors?.join(', ') ?? 'Scan failed');
    } catch (e: any) { currentError.set(e.message); }
    finally { isLoading.set(false); }
  }

  async function doGenerate() {
    isLoading.set(true); currentError.set(null);
    try {
      await api.cleanings.generateSteps(cleaningId);
      const stepsRes = await api.steps.getAll(cleaningId);
      if (stepsRes.success && stepsRes.data) steps.set(stepsRes.data);
      await refreshCleaning();
      await loadTree();
      setActiveTab('tree');
    } catch (e: any) { currentError.set(e.message); }
    finally { isLoading.set(false); }
  }

  async function doApprove(stepId: string) {
    await api.steps.approve(cleaningId, stepId);
    steps.set(stepList.map(s => s.id === stepId ? { ...s, isApproved: true } : s));
    await loadTree();
  }

  async function doExecute() {
    isLoading.set(true); currentError.set(null);
    try {
      await api.cleanings.execute(cleaningId);
      await refreshCleaning();
      const stepsRes = await api.steps.getAll(cleaningId);
      if (stepsRes.success && stepsRes.data) steps.set(stepsRes.data);
      await loadTree();
    } catch (e: any) { currentError.set(e.message); }
    finally { isLoading.set(false); }
  }

  async function doRestart() {
    if (!confirm('Restart this cleaning? All scan data, steps, and commands will be cleared.')) return;
    isLoading.set(true); currentError.set(null);
    try {
      await api.cleanings.restart(cleaningId);
      steps.set([]); scanResult.set(null); treeComparison.set(null);
      await refreshCleaning();
    } catch (e: any) { currentError.set(e.message); }
    finally { isLoading.set(false); }
  }

  if (!cleaning) return null;

  const approvedCount = stepList.filter(s => s.isApproved).length;
  const canRestart   = ['AwaitingExtensionResolution', 'Failed', 'Cancelled'].includes(cleaning.status);
  const canGenerate  = ['Analyzing', 'Scanning'].includes(cleaning.status) && stepList.length === 0;
  const targetReady  = cleaning.executionTarget && cleaning.executionTarget !== '';
  const canExecute   = cleaning.status === 'PromptGenerated' && approvedCount > 0 && targetReady;

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="bg-white rounded-xl border border-gray-200 p-5">
        <div className="flex items-start justify-between gap-4 flex-wrap">
          <div className="min-w-0">
            <div className="flex items-center gap-2 mb-1 flex-wrap">
              <StatusBadge status={cleaning.status} />
              <span className="text-xs text-gray-400 font-mono">{cleaning.id.slice(0,8)}…</span>
              {cleaning.restartCount > 0 && (
                <span className="text-xs bg-teal-100 text-teal-600 px-2 py-0.5 rounded-full">
                  ↺ {cleaning.restartCount}× restarted
                </span>
              )}
            </div>
            <p className="font-mono text-sm text-gray-700 break-all">{cleaning.rootPath}</p>
            {cleaning.executionTarget === 'AlternatePath' && cleaning.alternateExecutionPath && (
              <p className="text-xs text-indigo-600 mt-0.5 font-mono">
                → Executes to: {cleaning.alternateExecutionPath}
              </p>
            )}
            {cleaning.executionTarget === 'SourcePath' && cleaning.status !== 'Completed' && (
              <p className="text-xs text-red-600 mt-0.5 font-semibold">
                ⚠ Will modify source files directly
              </p>
            )}
          </div>

          <div className="flex gap-2 shrink-0 flex-wrap justify-end">
            {canRestart && (
              <button onClick={doRestart} disabled={loading}
                className="text-sm border border-teal-400 text-teal-700 px-3 py-1.5 rounded-lg hover:bg-teal-50 disabled:opacity-50">
                ↺ Restart from beginning
              </button>
            )}
            {cleaning.status === 'Pending' && (
              <button onClick={doScan} disabled={loading}
                className="bg-blue-600 text-white text-sm px-4 py-2 rounded-lg hover:bg-blue-700 disabled:opacity-50">
                {loading ? 'Scanning…' : 'Scan extensions'}
              </button>
            )}
            {canGenerate && (
              <button onClick={doGenerate} disabled={loading}
                className="bg-purple-600 text-white text-sm px-4 py-2 rounded-lg hover:bg-purple-700 disabled:opacity-50">
                {loading ? 'Generating…' : 'Generate steps'}
              </button>
            )}
            {cleaning.status === 'PromptGenerated' && !targetReady && (
              <button onClick={() => openExecTargetModal(cleaningId)}
                className="bg-orange-500 text-white text-sm px-4 py-2 rounded-lg hover:bg-orange-600">
                Set execution target
              </button>
            )}
            {canExecute && (
              <button onClick={doExecute} disabled={loading}
                className={`text-sm px-4 py-2 rounded-lg disabled:opacity-50 text-white transition-colors
                  ${cleaning.executionTarget === 'SourcePath'
                    ? 'bg-red-600 hover:bg-red-700' : 'bg-green-600 hover:bg-green-700'}`}>
                {loading ? 'Executing…' : `Execute ${approvedCount} step${approvedCount !== 1 ? 's' : ''}`}
              </button>
            )}
          </div>
        </div>
      </div>

      {err && (
        <div className="bg-red-50 border border-red-200 rounded-lg px-4 py-3 text-sm text-red-700">{err}</div>
      )}

      {/* Scan results */}
      {scan && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h3 className="font-medium mb-3 text-sm">
            Extensions ({scan.allExtensions.length})
            <span className="text-gray-400 font-normal ml-2">
              {scan.totalFileCount} files · {scan.totalDirectoryCount} dirs
            </span>
          </h3>
          <div className="flex flex-wrap gap-1.5">
            {scan.allExtensions.map(ext => (
              <span key={ext}
                className={`text-xs px-2 py-0.5 rounded-full font-mono
                  ${scan.unknownExtensions.includes(ext)
                    ? 'bg-amber-100 text-amber-800 ring-1 ring-amber-300'
                    : 'bg-gray-100 text-gray-600'}`}>
                {ext}{scan.unknownExtensions.includes(ext) && ' ⚠'}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Steps / Tree tabs */}
      {(stepList.length > 0 || tree) && (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <div className="flex border-b border-gray-100">
            <button onClick={() => setActiveTab('steps')}
              className={`text-sm px-5 py-3 font-medium border-r border-gray-100 transition-colors
                ${activeTab === 'steps' ? 'text-indigo-700 bg-indigo-50' : 'text-gray-500 hover:text-gray-700'}`}>
              Steps ({stepList.length})
            </button>
            <button onClick={() => { setActiveTab('tree'); if (!tree) loadTree(); }}
              className={`text-sm px-5 py-3 font-medium transition-colors
                ${activeTab === 'tree' ? 'text-indigo-700 bg-indigo-50' : 'text-gray-500 hover:text-gray-700'}`}>
              Before / After tree
            </button>
          </div>

          <div className="p-5">
            {activeTab === 'steps' && (
              <div className="space-y-2">
                <p className="text-xs text-gray-400 mb-3">
                  {approvedCount}/{stepList.length} approved. Expand each step to see C#, CMD, and PowerShell commands.
                </p>
                {stepList.map(step => (
                  <div key={step.id}
                    className={`rounded-lg border px-4 py-3 text-sm
                      ${step.isExecuted
                        ? step.executionError ? 'border-red-200 bg-red-50' : 'border-green-200 bg-green-50'
                        : step.isApproved ? 'border-indigo-200 bg-indigo-50' : 'border-gray-200 bg-gray-50'}`}>
                    <div className="flex items-start gap-3">
                      <span className="text-xs text-gray-400 font-mono shrink-0 pt-0.5">
                        #{step.stepOrder}
                      </span>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1 flex-wrap">
                          <span className="text-xs font-medium text-gray-500">{step.stepType}</span>
                          <span className="text-xs text-gray-300 font-mono">{step.id.slice(0,8)}…</span>
                          {step.isExecuted && !step.executionError &&
                            <span className="text-xs text-green-700">✓ Executed</span>}
                          {step.executionError &&
                            <span className="text-xs text-red-700">✗ {step.executionError}</span>}
                        </div>
                        <p className="text-sm text-gray-700 mb-1">{step.promptText}</p>
                        {step.sourcePath &&
                          <p className="text-xs font-mono text-gray-500 truncate">{step.sourcePath}</p>}
                        {step.proposedTargetPath &&
                          <p className="text-xs font-mono text-indigo-600 truncate">→ {step.proposedTargetPath}</p>}
                        <CommandViewer commands={step.commands} />
                      </div>
                      {!step.isApproved && !step.isExecuted && (
                        <button onClick={() => doApprove(step.id)}
                          className="shrink-0 text-xs bg-indigo-600 text-white px-3 py-1.5 rounded-md hover:bg-indigo-700">
                          Approve
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}

            {activeTab === 'tree' && tree && (
              <TreeComparison
                cleaningId={cleaningId}
                before={tree.beforeTree}
                after={tree.afterTree}
                totalRenames={tree.totalRenames}
                totalMoves={tree.totalMoves}
                isAfterProjected={tree.isAfterProjected}
              />
            )}
            {activeTab === 'tree' && !tree && (
              <p className="text-sm text-gray-400 italic">
                Tree comparison will be available after scanning.
              </p>
            )}
          </div>
        </div>
      )}

      <ExecutionTargetModal onTargetSet={refreshCleaning} />
    </div>
  );
}

// ── Root export ───────────────────────────────────────────────────────────────
export default function CleaningDashboard() {
  const [activeId, setActiveId] = useState<string | null>(null);
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight mb-1">File Cleanings</h1>
        <p className="text-sm text-gray-500">
          Scan a path, review AI-generated rename steps with C#/CMD/PowerShell commands, then execute.
        </p>
      </div>
      <StartCleaningForm onStarted={id => setActiveId(id)} />
      {activeId && <WorkflowPanel cleaningId={activeId} />}
      <UnknownExtensionModal />
    </div>
  );
}
