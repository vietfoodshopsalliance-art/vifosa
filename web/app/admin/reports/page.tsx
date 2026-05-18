'use client'

import { useState, useEffect, useCallback } from 'react'
import { api } from '@/lib/api'

type ReportStatus = 'open' | 'in_review' | 'resolved' | 'rejected'

interface Report {
  _id: string
  targetType: string
  reason: string
  description?: string
  reporterUsername: string
  reporterNickname?: string
  status: ReportStatus
  createdAt: string
  resolution?: string
}

const TAB_STATUS: Record<string, ReportStatus[]> = {
  Mới:          ['open'],
  'Đang xử lý': ['in_review'],
  'Đã xử lý':   ['resolved', 'rejected'],
}

export default function AdminReportsPage() {
  const [tab, setTab]             = useState('Mới')
  const [reports, setReports]     = useState<Report[]>([])
  const [loading, setLoading]     = useState(true)
  const [error, setError]         = useState('')
  const [selected, setSelected]   = useState<Report | null>(null)
  const [resolution, setResolution] = useState('')
  const [actionMsg, setActionMsg] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const statuses = TAB_STATUS[tab].join(',')
      const res = await api.get<{ reports: Report[] }>(`/admin/reports?status=${statuses}&limit=20`)
      setReports(res.reports)
    } catch (e: any) {
      setReports([])
      setError(e?.message ?? 'Lỗi kết nối. Vui lòng thử lại.')
    } finally { setLoading(false) }
  }, [tab])

  useEffect(() => { load() }, [load])

  async function doAction(action: 'in_review' | 'resolved' | 'rejected') {
    if (!selected) return
    try {
      await api.patch(`/admin/reports/${selected._id}/status`, { status: action, resolution })
      setActionMsg(`Báo cáo đã được cập nhật: ${action}.`)
      setSelected(null)
      setResolution('')
      load()
    } catch { setActionMsg('Có lỗi xảy ra.') }
  }

  return (
    <div className="p-6">
      <h1 className="mb-6 text-xl font-bold text-[#1A1200]">Báo cáo vi phạm</h1>

      {actionMsg && (
        <div className="mb-4 rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm text-green-800">
          {actionMsg} <button className="ml-2 underline" onClick={() => setActionMsg('')}>Đóng</button>
        </div>
      )}

      {/* Tabs */}
      <div className="mb-4 flex gap-1 border-b border-gray-200">
        {Object.keys(TAB_STATUS).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`px-4 py-2 text-sm font-medium transition-colors ${
              tab === t
                ? 'border-b-2 border-[#F5C842] text-[#1A1200]'
                : 'text-[#6B5C3E] hover:text-[#1A1200]'
            }`}
          >
            {t}
          </button>
        ))}
      </div>

      {/* List */}
      <div className="space-y-3">
        {loading && <p className="text-center text-sm text-[#6B5C3E]">Đang tải...</p>}
        {!loading && error && (
          <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error} <button className="ml-2 underline" onClick={load}>Thử lại</button>
          </div>
        )}
        {!loading && !error && reports.length === 0 && <p className="text-center text-sm text-[#6B5C3E]">Không có báo cáo nào.</p>}
        {reports.map((r) => (
          <div
            key={r._id}
            className="cursor-pointer rounded-xl border border-gray-200 bg-white p-4 shadow-sm hover:border-[#F5C842] transition-colors"
            onClick={() => setSelected(r)}
          >
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div>
                <span className="text-sm font-semibold text-[#1A1200]">{r.reason}</span>
                <span className="ml-2 rounded-full bg-gray-100 px-2 py-0.5 text-xs text-[#6B5C3E]">{r.targetType}</span>
              </div>
              <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                r.status === 'open'      ? 'bg-red-100 text-red-700' :
                r.status === 'in_review' ? 'bg-amber-100 text-amber-700' :
                r.status === 'resolved'  ? 'bg-green-100 text-green-700' :
                'bg-gray-100 text-gray-600'
              }`}>{r.status}</span>
            </div>
            <p className="mt-1 text-xs text-[#6B5C3E]">
              Người báo cáo: <strong>{r.reporterNickname ?? r.reporterUsername}</strong> (@{r.reporterUsername}) — {new Date(r.createdAt).toLocaleDateString('vi-VN')}
            </p>
            {r.description && <p className="mt-1 line-clamp-2 text-sm text-[#1A1200]">{r.description}</p>}
          </div>
        ))}
      </div>

      {/* Detail modal */}
      {selected && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-lg rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="mb-1 text-base font-bold text-[#1A1200]">{selected.reason}</h2>
            <p className="mb-1 text-xs text-[#6B5C3E]">Loại: {selected.targetType} | Người báo cáo: @{selected.reporterUsername}</p>
            {selected.description && <p className="mb-4 rounded-lg bg-gray-50 p-3 text-sm text-[#1A1200]">{selected.description}</p>}

            <textarea
              value={resolution}
              onChange={(e) => setResolution(e.target.value)}
              placeholder="Nhập ghi chú xử lý..."
              rows={3}
              className="mb-4 w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none"
            />

            <div className="flex flex-wrap gap-2">
              <button onClick={() => { setSelected(null); setResolution('') }} className="rounded-lg border border-gray-200 px-4 py-2 text-sm">Đóng</button>
              {selected.status === 'open' && (
                <button onClick={() => doAction('in_review')} className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-2 text-sm font-medium text-amber-800">Chuyển in_review</button>
              )}
              <button onClick={() => doAction('resolved')} className="rounded-lg bg-[#1D7A4E] px-4 py-2 text-sm font-semibold text-white">Resolved</button>
              <button onClick={() => doAction('rejected')} className="rounded-lg border border-red-200 bg-red-50 px-4 py-2 text-sm font-medium text-red-700">Rejected</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
