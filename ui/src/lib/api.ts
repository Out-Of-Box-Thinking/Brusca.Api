// src/lib/api.ts
const BASE_URL = import.meta.env.PUBLIC_API_URL ?? 'http://localhost:5000/api';

function getAuthHeader(): Record<string, string> {
  const token = localStorage.getItem('brusca_token');
  return token ? { Authorization: `Bearer ${token}` } : {};
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...getAuthHeader() },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }));
    throw new Error(err?.errors?.[0] ?? err?.error ?? `HTTP ${res.status}`);
  }
  if (res.status === 204) return undefined as T;
  return res.json() as T;
}

// ── Types ─────────────────────────────────────────────────────────────────────

export interface ApiResult<T> { success: boolean; data?: T; errors?: string[]; }

export interface CleaningResponse {
  id: string; rootPath: string; status: string;
  createdAtUtc: string; completedAtUtc?: string;
  restartCount: number;
  executionTarget: string;
  alternateExecutionPath?: string;
  totalFiles: number;
  extensions: ExtensionResponse[];
  promptSteps: PromptStepResponse[];
}

export interface ExtensionResponse {
  extension: string; fileCount: number; status: string;
  suggestedNuGetPackage?: string;
}

export interface PromptStepCommandResponse {
  id: string; promptStepId: string; language: string;
  commandBody: string; commandOrder: number;
  isExecuted: boolean; executionError?: string;
}

export interface PromptStepResponse {
  id: string; stepOrder: number; stepType: string; promptText: string;
  generatedResponse?: string; sourcePath?: string; proposedTargetPath?: string;
  isApproved: boolean; isExecuted: boolean; executionError?: string;
  commands: PromptStepCommandResponse[];
}

export interface ExtensionScanResponse {
  allExtensions: string[]; unknownExtensions: string[];
  totalFileCount: number; totalDirectoryCount: number;
}

export interface FileExtensionRecord {
  id: string; extension: string; status: string;
  description?: string; readerNuGetPackage?: string;
  totalTimesEncountered: number; lastSeenUtc: string;
}

export interface TreeNodeResponse {
  fullPath: string; name: string; depth: number; fileCount: number;
  extensions: string[]; files: string[]; children: TreeNodeResponse[];
}

export interface TreeComparisonResponse {
  cleaningId: string;
  beforeTree?: TreeNodeResponse;
  afterTree?: TreeNodeResponse;
  totalRenames: number; totalMoves: number; isAfterProjected: boolean;
}

// ── API ───────────────────────────────────────────────────────────────────────

export const api = {
  cleanings: {
    start: (rootPath: string, notes?: string) =>
      request<ApiResult<CleaningResponse>>('POST', '/cleanings', { rootPath, notes }),
    getById: (id: string) =>
      request<ApiResult<CleaningResponse>>('GET', `/cleanings/${id}`),
    scan: (id: string) =>
      request<ApiResult<ExtensionScanResponse>>('POST', `/cleanings/${id}/scan`),
    generateSteps: (id: string) =>
      request<void>('POST', `/cleanings/${id}/generate-steps`),
    setExecutionTarget: (id: string, target: string, alternatePath?: string) =>
      request<void>('POST', `/cleanings/${id}/set-execution-target`, { target, alternatePath }),
    execute: (id: string) =>
      request<void>('POST', `/cleanings/${id}/execute`),
    restart: (id: string) =>
      request<void>('POST', `/cleanings/${id}/restart`),
    getTreeComparison: (id: string) =>
      request<ApiResult<TreeComparisonResponse>>('GET', `/cleanings/${id}/tree-comparison`),
  },
  steps: {
    getAll: (cleaningId: string) =>
      request<ApiResult<PromptStepResponse[]>>('GET', `/cleanings/${cleaningId}/steps`),
    approve: (cleaningId: string, stepId: string) =>
      request<void>('POST', `/cleanings/${cleaningId}/steps/${stepId}/approve`),
  },
  extensions: {
    getAll: () =>
      request<ApiResult<FileExtensionRecord[]>>('GET', '/fileextensions'),
    registerPackage: (extension: string, nuGetPackage: string) =>
      request<void>('POST', '/fileextensions/register-package', { extension, nuGetPackage }),
  },
};
