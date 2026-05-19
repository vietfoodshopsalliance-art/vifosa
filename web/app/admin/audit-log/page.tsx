'use client'

import { useState, useEffect, useCallback } from 'react'
import { api } from '@/lib/api'

interface AuditEntry {
  _id: string
  actorId: string
  actorRole: string
  action: string
  targetType: string
  targetId: string
  before?: Record<string, unknown>
  after?: Record<string, unknown>
  ip?: string
  createdAt: string
}

export default function AdminAuditLogPage() {
  const [entries, setEntries]   = useState<AuditEntry[]>([])
  const [loading, setLoading]   = useState(true)
  const [actorId, setActorId]   = useState('')
  const [targetType, setTargetType] = useState('')
  const [dateFrom, setDateFrom] = useState('')
  const [dateTo, setDateTo]     = useState('')
  const [expanded, setExpanded] = useState<string | null>(null)

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const params = new URLSearchParams({ limit: '50' })
      if (actorId)    params.set('actorId', actorId)
      if (targetType) params.set('targetType', targetType)
      if (dateFrom)   params.set('from', dateFrom)
      if (dateTo)     params.set('to', dateTo)
      const res = await api.get<{ entries: AuditEntry[] }>(`/admin/audit-log?${params}`)
      setEntries(res.entries ?? [])
    } catch { setEntries([]) }
    finally { setLoading(false) }
  }, [actorId, targetType, dateFrom, dateTo])

  useEffect(() => { load() }, [load])

  return (
    <div className="p-6">
      <h1 className="mb-6 text-xl font-bold text-[#1A1200]">Nhật ký hành động</h1>

      {/* Filters */}
      <div className="mb-4 flex flex-wrap gap-3">
        <input
          type="text"
          placeholder="Actor ID"
          value={actorId}
          onChange={(e) => setActorId(e.target.value)}
          className="w-44 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-[#1D7A4E] focus:outline-none"
        />
        <select
          value={targetType}
          onChange={(e) => setTargetType(e.target.value)}
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none"
        >
          <option value="">Tất cả loại</option>
          {['user', 'store', 'order', 'report', 'settings', 'menu'].map((t) => (
            <option key={t} value={t}>{t}</option>
          ))}
        </select>
        <input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none" />
        <input type="date" value={dateTo}   onChange={(e) => setDateTo(e.target.value)}   className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none" />
      </div>

      {/* Table */}
      <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white shadow-sm">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100 bg-gray-50 text-left text-xs font-semibold text-[#6B5C3E] uppercase">
              <th className="px-4 py-3">Thời gian</th>
              <th className="px-4 py-3">Actor</th>
              <th className="px-4 py-3">Action</th>
              <th className="px-4 py-3">Target</th>
              <th className="px-4 py-3">Chi tiết</th>
            </tr>
          </thead>
          <tbody>
            {loading && <tr><td colSpan={5} className="px-4 py-8 text-center text-[#6B5C3E]">Đang tải...</td></tr>}
            {!loading && entries.length === 0 && <tr><td colSpan={5} className="px-4 py-8 text-center text-[#6B5C3E]">Không có dữ liệu.</td></tr>}
            {entries.map((e) => (
              <>
                <tr key={e._id} className="border-b border-gray-50 hover:bg-gray-50">
                  <td className="px-4 py-3 text-xs text-[#6B5C3E]">
                    {new Date(e.createdAt).toLocaleString('vi-VN')}
                  </td>
                  <td className="px-4 py-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                      e.actorRole === 'admin' ? 'bg-red-100 text-red-700' : 'bg-purple-100 text-purple-700'
                    }`}>{e.actorRole}</span>
                    <div className="mt-0.5 font-mono text-xs text-[#6B5C3E]">{e.actorId?.slice(-8)}</div>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs font-semibold text-[#1A1200]">{e.action}</td>
                  <td className="px-4 py-3 text-xs text-[#6B5C3E]">
                    <span>{e.targetType}</span>
                    <div className="font-mono">{e.targetId?.slice(-8)}</div>
                  </td>
                  <td className="px-4 py-3">
                    {(e.before || e.after) && (
                      <button
                        onClick={() => setExpanded(expanded === e._id ? null : e._id)}
                        className="text-xs text-blue-600 underline"
                      >
                        {expanded === e._id ? 'Ẩn' : 'Xem diff'}
                      </button>
                    )}
                  </td>
                </tr>
                {expanded === e._id && (
                  <tr key={`${e._id}-diff`} className="bg-gray-50">
                    <td colSpan={5} className="px-4 py-3">
                      <div className="grid gap-3 sm:grid-cols-2">
                        <div>
                          <p className="mb-1 text-xs font-semibold text-red-600">Before</p>
                          <pre className="overflow-x-auto rounded-lg border border-red-100 bg-red-50 p-2 text-xs text-[#1A1200]">
                            {JSON.stringify(e.before, null, 2)}
                          </pre>
                        </div>
                        <div>
                          <p className="mb-1 text-xs font-semibold text-green-600">After</p>
                          <pre className="overflow-x-auto rounded-lg border border-green-100 bg-green-50 p-2 text-xs text-[#1A1200]">
                            {JSON.stringify(e.after, null, 2)}
                          </pre>
                        </div>
                      </div>
                    </td>
                  </tr>
                )}
              </>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
