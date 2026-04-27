// src/components/TreeComparison.tsx
import { useState } from 'react';
import type { TreeNodeResponse } from '../lib/api';

// ── Tree node renderer ────────────────────────────────────────────────────────

type ChangeKind = 'renamed' | 'moved' | 'added' | 'removed' | 'unchanged';

interface NodeProps {
  node: TreeNodeResponse;
  other?: TreeNodeResponse;
  side: 'before' | 'after';
  depth?: number;
}

function getNodeChange(node: TreeNodeResponse, other?: TreeNodeResponse): ChangeKind {
  if (!other) return 'unchanged';
  if (!findByPath(other, node.fullPath)) {
    // The path doesn't exist on the other side — renamed or removed/added
    return 'renamed';
  }
  return 'unchanged';
}

function findByPath(root: TreeNodeResponse, path: string): TreeNodeResponse | undefined {
  if (root.fullPath === path) return root;
  for (const child of root.children) {
    const found = findByPath(child, path);
    if (found) return found;
  }
}

const CHANGE_COLORS: Record<ChangeKind, string> = {
  renamed:   'text-amber-700 bg-amber-50',
  moved:     'text-blue-700 bg-blue-50',
  added:     'text-green-700 bg-green-50',
  removed:   'text-red-600 bg-red-50 line-through opacity-60',
  unchanged: 'text-gray-700',
};

function TreeNode({ node, other, side, depth = 0 }: NodeProps) {
  const [expanded, setExpanded] = useState(depth < 2);
  const otherRoot = other;
  const change = getNodeChange(node, otherRoot);
  const hasChildren = node.children.length > 0 || node.files.length > 0;
  const indent = depth * 16;

  return (
    <div>
      <div
        className={`flex items-center gap-1 py-0.5 px-1 rounded cursor-pointer hover:bg-gray-100 text-sm ${CHANGE_COLORS[change]}`}
        style={{ paddingLeft: `${indent + 4}px` }}
        onClick={() => hasChildren && setExpanded(e => !e)}
      >
        {hasChildren ? (
          <span className="text-gray-400 w-3 text-xs select-none">
            {expanded ? '▾' : '▸'}
          </span>
        ) : (
          <span className="w-3" />
        )}
        <span className="mr-1 text-gray-400">📁</span>
        <span className="font-medium truncate">{node.name}</span>
        {node.fileCount > 0 && (
          <span className="ml-1 text-xs text-gray-400">({node.fileCount})</span>
        )}
        {change !== 'unchanged' && (
          <span className={`ml-auto text-xs px-1.5 py-0.5 rounded-full font-medium
            ${change === 'renamed' ? 'bg-amber-100 text-amber-700' : ''}
            ${change === 'added' ? 'bg-green-100 text-green-700' : ''}
            ${change === 'removed' ? 'bg-red-100 text-red-600' : ''}
          `}>
            {change}
          </span>
        )}
      </div>

      {expanded && (
        <>
          {node.files.map(f => (
            <div
              key={f}
              className="flex items-center gap-1 py-0.5 text-xs text-gray-500"
              style={{ paddingLeft: `${indent + 24}px` }}
            >
              <span className="text-gray-300">📄</span>
              <span className="truncate">{f.split(/[/\\]/).pop()}</span>
            </div>
          ))}
          {node.children.map(child => (
            <TreeNode
              key={child.fullPath}
              node={child}
              other={otherRoot}
              side={side}
              depth={depth + 1}
            />
          ))}
        </>
      )}
    </div>
  );
}

// ── Tree panel ────────────────────────────────────────────────────────────────

function TreePanel({
  title, subtitle, node, other, side, badge
}: {
  title: string;
  subtitle?: string;
  node?: TreeNodeResponse;
  other?: TreeNodeResponse;
  side: 'before' | 'after';
  badge?: React.ReactNode;
}) {
  if (!node) {
    return (
      <div className="flex-1 min-w-0 bg-gray-50 rounded-xl border border-gray-200 p-4">
        <div className="flex items-center gap-2 mb-3">
          <span className="font-medium text-sm">{title}</span>
          {badge}
        </div>
        <p className="text-xs text-gray-400 italic">Not yet available.</p>
      </div>
    );
  }

  return (
    <div className="flex-1 min-w-0 bg-white rounded-xl border border-gray-200 overflow-hidden">
      <div className="px-4 py-3 border-b border-gray-100 flex items-center gap-2">
        <span className="font-medium text-sm">{title}</span>
        {subtitle && <span className="text-xs text-gray-400">{subtitle}</span>}
        {badge}
      </div>
      <div className="p-2 overflow-auto max-h-96 font-mono text-xs">
        <TreeNode node={node} other={other} side={side} />
      </div>
    </div>
  );
}

// ── Main export ───────────────────────────────────────────────────────────────

interface TreeComparisonProps {
  cleaningId: string;
  before?: TreeNodeResponse;
  after?: TreeNodeResponse;
  totalRenames: number;
  totalMoves: number;
  isAfterProjected: boolean;
}

export default function TreeComparison({
  cleaningId, before, after, totalRenames, totalMoves, isAfterProjected
}: TreeComparisonProps) {
  return (
    <div className="space-y-3">
      <div className="flex items-center gap-3">
        <h3 className="font-medium text-sm">Directory tree</h3>
        <div className="flex gap-2 text-xs">
          <span className="bg-amber-100 text-amber-700 px-2 py-0.5 rounded-full">
            {totalRenames} rename{totalRenames !== 1 ? 's' : ''}
          </span>
          <span className="bg-blue-100 text-blue-700 px-2 py-0.5 rounded-full">
            {totalMoves} move{totalMoves !== 1 ? 's' : ''}
          </span>
          {isAfterProjected && (
            <span className="bg-purple-100 text-purple-700 px-2 py-0.5 rounded-full">
              After is projected
            </span>
          )}
        </div>
      </div>

      <div className="flex gap-3">
        <TreePanel
          title="Before"
          node={before}
          other={after}
          side="before"
          badge={<span className="text-xs bg-gray-100 text-gray-500 px-2 py-0.5 rounded-full">Original</span>}
        />
        <TreePanel
          title="After"
          subtitle={isAfterProjected ? '(projected from approved steps)' : undefined}
          node={after}
          other={before}
          side="after"
          badge={
            isAfterProjected
              ? <span className="text-xs bg-purple-100 text-purple-600 px-2 py-0.5 rounded-full">Projected</span>
              : <span className="text-xs bg-green-100 text-green-600 px-2 py-0.5 rounded-full">Executed</span>
          }
        />
      </div>
    </div>
  );
}
