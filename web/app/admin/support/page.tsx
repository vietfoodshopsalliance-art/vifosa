'use client'

import { useState, useEffect, useCallback } from 'react'
import { api } from '@/lib/api'

type TicketStatus = 'open' | 'replied' | 'closed'

interface Ticket {
  _id: string
  subject: string
  body: string
  images?: string[]
  relatedOrderCode?: string
  userId?: string
  guestPhone?: string
  status: TicketStatus
  adminReply?: string
  repliedAt?: string
  createdAt: string
}

const STATUS_TABS: TicketStatus[] = ['open', 'replied', 'closed']
const STATUS_LABEL: Record<TicketStatus, string> = {
  open:    'Chưa trả lời',
  replied: 'Đã trả lời',
  closed:  'Đã đóng',
}

export default function AdminSupportPage() {
  const [status, setStatus]   = useState<TicketStatus>('open')
  const [tickets, setTickets] = useState<Ticket[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError]     = useState('')
  const [selected, setSelected] = useState<Ticket | null>(null)
  const [reply, setReply]     = useState('')
  const [actionMsg, setActionMsg] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await api.get<{ tickets: Ticket[] }>(`/admin/support/tickets?status=${status}&limit=20`)
      setTickets(res.tickets)
    } catch (e: any) {
      setTickets([])
      setError(e?.message ?? 'Lỗi kết nối. Vui lòng thử lại.')
    } finally { setLoading(false) }
  }, [status])

  useEffect(() => { load() }, [load])

  async function sendReply() {
    if (!selected || !reply.trim()) return
    try {
      await api.patch(`/admin/support/tickets/${selected._id}`, { adminReply: reply, status: 'replied' })
      setActionMsg('Đã gửi trả lời.')
      setSelected(null)
      setReply('')
      load()
    } catch (e: any) { setActionMsg(e?.message ?? 'Có lỗi xảy ra.') }
  }

  async function closeTicket(ticket: Ticket) {
    try {
      await api.patch(`/admin/support/tickets/${ticket._id}`, { status: 'closed' })
      setActionMsg('Ticket đã đóng.')
      setSelected(null)
      load()
    } catch (e: any) { setActionMsg(e?.message ?? 'Có lỗi xảy ra.') }
  }

  return (
    <div className="p-6">
      <h1 className="mb-6 text-xl font-bold text-[#1A1200]">Support Tickets</h1>

      {actionMsg && (
        <div className="mb-4 rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm text-green-800">
          {actionMsg} <button className="ml-2 underline" onClick={() => setActionMsg('')}>Đóng</button>
        </div>
      )}

      {/* Tabs */}
      <div className="mb-4 flex gap-1 border-b border-gray-200">
        {STATUS_TABS.map((s) => (
          <button
            key={s}
            onClick={() => setStatus(s)}
            className={`px-4 py-2 text-sm font-medium transition-colors ${
              status === s
                ? 'border-b-2 border-[#F5C842] text-[#1A1200]'
                : 'text-[#6B5C3E] hover:text-[#1A1200]'
            }`}
          >
            {STATUS_LABEL[s]}
          </button>
        ))}
      </div>

      {/* Ticket list */}
      <div className="space-y-3">
        {loading && <p className="text-center text-sm text-[#6B5C3E]">Đang tải...</p>}
        {!loading && error && (
          <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            {error} <button className="ml-2 underline" onClick={load}>Thử lại</button>
          </div>
        )}
        {!loading && !error && tickets.length === 0 && <p className="text-center text-sm text-[#6B5C3E]">Không có ticket nào.</p>}
        {tickets.map((t) => (
          <div
            key={t._id}
            className="cursor-pointer rounded-xl border border-gray-200 bg-white p-4 shadow-sm hover:border-[#F5C842] transition-colors"
            onClick={() => { setSelected(t); setReply(t.adminReply ?? '') }}
          >
            <div className="flex items-start justify-between gap-2">
              <p className="font-semibold text-[#1A1200]">{t.subject}</p>
              <span className={`shrink-0 rounded-full px-2 py-0.5 text-xs font-semibold ${
                t.status === 'open'    ? 'bg-red-100 text-red-700' :
                t.status === 'replied' ? 'bg-blue-100 text-blue-700' :
                'bg-gray-100 text-gray-600'
              }`}>{STATUS_LABEL[t.status]}</span>
            </div>
            <p className="mt-1 line-clamp-2 text-sm text-[#6B5C3E]">{t.body}</p>
            <div className="mt-2 flex gap-3 text-xs text-[#6B5C3E]">
              {t.relatedOrderCode && <span>Đơn: {t.relatedOrderCode}</span>}
              {t.guestPhone && <span>SĐT: {t.guestPhone}</span>}
              <span>{new Date(t.createdAt).toLocaleDateString('vi-VN')}</span>
            </div>
          </div>
        ))}
      </div>

      {/* Detail modal */}
      {selected && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-lg rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="mb-2 text-base font-bold text-[#1A1200]">{selected.subject}</h2>
            <div className="mb-4 rounded-lg bg-gray-50 p-3 text-sm text-[#1A1200]">{selected.body}</div>

            {selected.images && selected.images.length > 0 && (
              <div className="mb-4 flex gap-2">
                {selected.images.map((img, i) => (
                  <a key={i} href={img} target="_blank" rel="noreferrer" className="text-xs text-blue-600 underline">Ảnh {i + 1}</a>
                ))}
              </div>
            )}

            <textarea
              value={reply}
              onChange={(e) => setReply(e.target.value)}
              placeholder="Nhập nội dung trả lời..."
              rows={4}
              className="mb-4 w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none"
            />

            <div className="flex flex-wrap gap-2">
              <button onClick={() => { setSelected(null); setReply('') }} className="rounded-lg border border-gray-200 px-4 py-2 text-sm">Đóng</button>
              <button onClick={sendReply} disabled={!reply.trim()} className="rounded-lg bg-[#1D7A4E] px-4 py-2 text-sm font-semibold text-white disabled:opacity-50">Gửi trả lời</button>
              {selected.status !== 'closed' && (
                <button onClick={() => closeTicket(selected)} className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-[#6B5C3E]">Đóng ticket</button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
