'use client'

import { useState, useEffect, useCallback } from 'react'
import { api } from '@/lib/api'

type MainStatus = 'preparing' | 'delivering' | 'delivered' | 'completed' | 'cancelled' | string
type RefundStatus = 'required' | 'submitted' | 'refunded' | 'disputed' | null

interface Order {
  _id: string
  code: string
  mainStatus: MainStatus
  refundStatus: RefundStatus
  storeName: string
  customerPhone: string
  totalAmount: number
  createdAt: string
  flagReason: string
}

const STATUS_LABEL: Record<string, string> = {
  preparing:        'Đang chuẩn bị',
  delivering:       'Đang giao',
  delivered:        'Đã giao',
  completed:        'Hoàn thành',
  cancelled:        'Đã huỷ',
  disputed:         'Tranh chấp',
  required:         'Cần hoàn tiền',
  submitted:        'Đã gửi HT',
  refunded:         'Đã hoàn',
}

export default function AdminOrdersPage() {
  const [orders, setOrders]       = useState<Order[]>([])
  const [loading, setLoading]     = useState(true)
  const [search, setSearch]       = useState('')
  const [searchResult, setSearchResult] = useState<Order | null | 'not_found'>(null)
  const [actionMsg, setActionMsg] = useState('')
  const [resolveModal, setResolveModal] = useState<Order | null>(null)
  const [reason, setReason]       = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const res = await api.get<{ orders: Order[] }>('/admin/orders/flagged')
      setOrders(res.orders)
    } catch { setOrders([]) }
    finally { setLoading(false) }
  }, [])

  useEffect(() => { load() }, [load])

  async function searchOrder() {
    if (!search.trim()) return
    try {
      const res = await api.get<Order>(`/admin/orders/search?code=${search.trim()}`)
      setSearchResult(res)
    } catch { setSearchResult('not_found') }
  }

  async function forceRefund(order: Order, resolutionReason: string) {
    try {
      await api.post(`/admin/orders/${order._id}/force-refund`, { reason: resolutionReason })
      setActionMsg(`Đã force refund đơn ${order.code}.`)
      setResolveModal(null)
      setReason('')
      load()
    } catch { setActionMsg('Có lỗi xảy ra.') }
  }

  return (
    <div className="p-6">
      <h1 className="mb-6 text-xl font-bold text-[#1A1200]">Đơn hàng cần xử lý</h1>

      {actionMsg && (
        <div className="mb-4 rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm text-green-800">
          {actionMsg} <button className="ml-2 underline" onClick={() => setActionMsg('')}>Đóng</button>
        </div>
      )}

      {/* Manual search */}
      <div className="mb-6 flex gap-2">
        <input
          type="text"
          placeholder="Tra cứu mã đơn (VD: AB251107-456)"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && searchOrder()}
          className="w-72 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-[#1D7A4E] focus:outline-none"
        />
        <button
          onClick={searchOrder}
          className="rounded-lg bg-[#1D7A4E] px-4 py-2 text-sm font-semibold text-white hover:bg-[#165f3c]"
        >
          Tìm
        </button>
      </div>

      {searchResult === 'not_found' && (
        <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          Không tìm thấy đơn hàng với mã đó.
        </div>
      )}
      {searchResult && searchResult !== 'not_found' && (
        <div className="mb-6 rounded-xl border border-blue-200 bg-blue-50 p-4">
          <p className="mb-1 text-xs font-semibold text-blue-600 uppercase">Kết quả tra cứu</p>
          <OrderRow order={searchResult} onResolve={setResolveModal} />
        </div>
      )}

      {/* Flagged orders */}
      <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white shadow-sm">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100 bg-gray-50 text-left text-xs font-semibold text-[#6B5C3E] uppercase">
              <th className="px-4 py-3">Mã đơn</th>
              <th className="px-4 py-3">Quán</th>
              <th className="px-4 py-3">Lý do cảnh báo</th>
              <th className="px-4 py-3">Hoàn tiền</th>
              <th className="px-4 py-3">Thao tác</th>
            </tr>
          </thead>
          <tbody>
            {loading && <tr><td colSpan={5} className="px-4 py-8 text-center text-[#6B5C3E]">Đang tải...</td></tr>}
            {!loading && orders.length === 0 && (
              <tr><td colSpan={5} className="px-4 py-8 text-center text-green-700">Không có đơn nào cần xử lý.</td></tr>
            )}
            {orders.map((o) => (
              <tr key={o._id} className="border-b border-gray-50 hover:bg-gray-50">
                <OrderRow order={o} onResolve={setResolveModal} />
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Resolve modal */}
      {resolveModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="mb-1 text-base font-bold text-[#1A1200]">Xử lý đơn {resolveModal.code}</h2>
            <p className="mb-4 text-sm text-[#6B5C3E]">Refund status: <strong>{resolveModal.refundStatus ?? '—'}</strong></p>
            <textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="Nhập lý do xử lý (bắt buộc ghi audit log)..."
              rows={3}
              className="mb-4 w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-[#1D7A4E] focus:outline-none"
            />
            <div className="flex gap-3">
              <button
                onClick={() => { setResolveModal(null); setReason('') }}
                className="flex-1 rounded-lg border border-gray-200 py-2 text-sm"
              >
                Huỷ
              </button>
              <button
                onClick={() => forceRefund(resolveModal, reason)}
                disabled={!reason.trim()}
                className="flex-1 rounded-lg bg-[#F5C842] py-2 text-sm font-semibold text-[#3D2800] disabled:opacity-50"
              >
                Force Refund
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function OrderRow({ order, onResolve }: { order: Order; onResolve: (o: Order) => void }) {
  return (
    <>
      <td className="px-4 py-3 font-mono text-xs font-bold text-[#1A1200]">
        <span className="text-[#6B5C3E]">{order.code?.slice(0, -3)}</span>
        {order.code?.slice(-3)}
      </td>
      <td className="px-4 py-3 text-[#1A1200]">{order.storeName}</td>
      <td className="px-4 py-3 text-[#6B5C3E]">{order.flagReason}</td>
      <td className="px-4 py-3">
        {order.refundStatus ? (
          <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
            order.refundStatus === 'disputed' ? 'bg-red-100 text-red-700' :
            order.refundStatus === 'required' ? 'bg-amber-100 text-amber-700' :
            'bg-gray-100 text-gray-600'
          }`}>
            {STATUS_LABEL[order.refundStatus] ?? order.refundStatus}
          </span>
        ) : '—'}
      </td>
      <td className="px-4 py-3">
        <button
          onClick={() => onResolve(order)}
          className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-1 text-xs font-medium text-amber-800 hover:bg-amber-100"
        >
          Xử lý
        </button>
      </td>
    </>
  )
}
