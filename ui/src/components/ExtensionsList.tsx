// src/components/ExtensionsList.tsx
import { useState, useEffect } from 'react';
import { api, type FileExtensionRecord } from '../lib/api';

const STATUS_LABELS: Record<string, { label: string; color: string }> = {
  '0': { label: 'Known', color: 'bg-green-100 text-green-700' },
  '1': { label: 'Unknown', color: 'bg-amber-100 text-amber-700' },
  '2': { label: 'Pending package', color: 'bg-blue-100 text-blue-700' },
  Known: { label: 'Known', color: 'bg-green-100 text-green-700' },
  Unknown: { label: 'Unknown', color: 'bg-amber-100 text-amber-700' },
  PendingPackage: { label: 'Pending package', color: 'bg-blue-100 text-blue-700' },
};

export default function ExtensionsList() {
  const [records, setRecords] = useState<FileExtensionRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState<'all' | 'unknown'>('all');

  useEffect(() => {
    api.extensions.getAll().then(res => {
      if (res.success && res.data) setRecords(res.data);
      setLoading(false);
    });
  }, []);

  const filtered = filter === 'unknown'
    ? records.filter(r => r.status === 'Unknown' || r.status === '1')
    : records;

  const unknownCount = records.filter(r => r.status === 'Unknown' || r.status === '1').length;

  if (loading) return <p className="text-sm text-gray-400">Loading…</p>;

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight mb-1">File Extensions</h1>
        <p className="text-sm text-gray-500">
          Master list of all extensions encountered across cleanings.
          {unknownCount > 0 && (
            <span className="ml-1 text-amber-600 font-medium">
              {unknownCount} unknown — register NuGet packages to enable reading.
            </span>
          )}
        </p>
      </div>

      <div className="flex gap-2">
        <button
          onClick={() => setFilter('all')}
          className={`text-sm px-3 py-1.5 rounded-lg transition-colors ${
            filter === 'all' ? 'bg-gray-900 text-white' : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
          }`}>
          All ({records.length})
        </button>
        <button
          onClick={() => setFilter('unknown')}
          className={`text-sm px-3 py-1.5 rounded-lg transition-colors ${
            filter === 'unknown' ? 'bg-amber-600 text-white' : 'bg-white border border-gray-200 text-gray-600 hover:bg-gray-50'
          }`}>
          Unknown ({unknownCount})
        </button>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100 bg-gray-50">
              <th className="text-left font-medium text-gray-500 px-4 py-3">Extension</th>
              <th className="text-left font-medium text-gray-500 px-4 py-3">Status</th>
              <th className="text-left font-medium text-gray-500 px-4 py-3">NuGet package</th>
              <th className="text-right font-medium text-gray-500 px-4 py-3">Seen</th>
              <th className="text-right font-medium text-gray-500 px-4 py-3">Last seen</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map(r => {
              const s = STATUS_LABELS[r.status] ?? { label: r.status, color: 'bg-gray-100 text-gray-500' };
              return (
                <tr key={r.id} className="border-b border-gray-50 hover:bg-gray-50 transition-colors">
                  <td className="px-4 py-2.5 font-mono font-medium">{r.extension}</td>
                  <td className="px-4 py-2.5">
                    <span className={`text-xs px-2 py-0.5 rounded-full ${s.color}`}>{s.label}</span>
                  </td>
                  <td className="px-4 py-2.5 text-gray-500 font-mono text-xs">
                    {r.readerNuGetPackage ?? <span className="text-gray-300">—</span>}
                  </td>
                  <td className="px-4 py-2.5 text-right text-gray-500">
                    {r.totalTimesEncountered.toLocaleString()}
                  </td>
                  <td className="px-4 py-2.5 text-right text-gray-400 text-xs">
                    {new Date(r.lastSeenUtc).toLocaleDateString()}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
        {filtered.length === 0 && (
          <p className="text-center text-sm text-gray-400 py-8">No records found.</p>
        )}
      </div>
    </div>
  );
}
