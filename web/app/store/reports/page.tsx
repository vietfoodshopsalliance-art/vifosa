'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts'
import * as XLSX from 'xlsx'
import { api } from '@/lib/api'

// ── Types ──────────────────────────────────────────────────────────────────

interface StoreStats {
  revenueThisMonth: number
  completedOrdersThisMonth: number
  pendingOrders: number
  activeOrders: number
  ordersToday: number
  avgRating: number
  totalReviews: number
}

interface Order {
  _id: string
  code: string
  createdAt: string
  totalAmount: number
  itemsTotal: number
  shipFee: number
  paidAmount: number
  paymentMethod: string
  paymentStatus: string
  mainStatus: string
}

// ── Helpers ────────────────────────────────────────────────────────────────

function getCookie(name: string): string {
  if (typeof document === 'undefined') return ''
  const match = document.cookie.match(new RegExp('(?:^|; )' + name + '=([^;]*)'))
  return match ? decodeURIComponent(match[1]) : ''
}

function formatVND(n: number) {
  return n.toLocaleString('vi-VN') + 'đ'
}

function fmtDate(iso: string) {
  const d = new Date(iso)
  return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`
}

function fmtDateTime(iso: string) {
  const d = new Date(iso)
  return (
    `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()} ` +
    `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  )
}

const PAYMENT_METHOD_LABEL: Record<string, string> = {
  bank_transfer: 'Chuyển khoản',
  cod:           'COD (tiền mặt)',
  fifty_fifty:   '50/50',
}

const PAYMENT_STATUS_LABEL: Record<string, string> = {
  unpaid:         'Chưa TT',
  reported_paid:  'Đã báo CK',
  partial:        'Nhận 1 phần',
  paid_full:      'Đã nhận đủ',
  cod_pending:    'COD chờ thu',
  cod_collected:  'Đã thu COD',
}

const PAYMENT_STATUS_COLOR: Record<string, string> = {
  unpaid:         'bg-red-50 text-red-700',
  reported_paid:  'bg-amber-50 text-amber-700',
  partial:        'bg-amber-50 text-amber-700',
  paid_full:      'bg-green-50 text-green-700',
  cod_pending:    'bg-blue-50 text-blue-700',
  cod_collected:  'bg-green-50 text-green-700',
}

function todayISO() {
  return new Date().toISOString().slice(0, 10)
}

function firstDayOfMonthISO() {
  const d = new Date()
  d.setDate(1)
  return d.toISOString().slice(0, 10)
}

// Group orders by day and sum revenue
function buildChartData(orders: Order[], dateFrom: string, dateTo: string) {
  const map: Record<string, number> = {}
  const start = new Date(dateFrom)
  const end   = new Date(dateTo)
  // init all days in range
  for (const d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    map[d.toISOString().slice(0, 10)] = 0
  }
  for (const o of orders) {
    if (o.mainStatus !== 'completed') continue
    const day = o.createdAt.slice(0, 10)
    if (map[day] !== undefined) map[day] += o.totalAmount
  }
  return Object.entries(map).map(([date, revenue]) => ({
    date: date.slice(5).replace('-', '/'), // MM/DD
    revenue,
  }))
}

// ── Component ──────────────────────────────────────────────────────────────

const PAGE_SIZE = 20

export default function StoreReportsPage() {
  const [storeId, setStoreId] = useState('')
  const [stats, setStats]     = useState<StoreStats | null>(null)
  const [orders, setOrders]   = useState<Order[]>([])
  const [total, setTotal]     = useState(0)
  const [page, setPage]       = useState(1)
  const [dateFrom, setDateFrom] = useState(firstDayOfMonthISO())
  const [dateTo, setDateTo]     = useState(todayISO())
  const [loading, setLoading] = useState(true)
  const [loadingOrders, setLoadingOrders] = useState(false)
  const [error, setError]     = useState('')
  const [exporting, setExporting] = useState(false)

  // Load stats once on mount
  useEffect(() => {
    const sid = getCookie('storeId')
    setStoreId(sid)
    if (!sid) { setLoading(false); return }
    api.get<StoreStats>(`/me/stores/${sid}/stats`)
      .then(data => setStats(data))
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [])

  // Load orders when storeId / filters / page change
  const loadOrders = useCallback(async (sid: string, from: string, to: string, pg: number) => {
    if (!sid) return
    setLoadingOrders(true)
    try {
      const toEnd = to + 'T23:59:59.999Z'
      const res = await api.get<{ orders: Order[]; total: number }>(
        `/me/stores/${sid}/orders?tab=history&dateFrom=${from}&dateTo=${toEnd}&page=${pg}&limit=${PAGE_SIZE}`
      )
      setOrders(res.orders)
      setTotal(res.total)
    } catch (e: any) {
      setError(e?.message ?? 'Không tải được dữ liệu')
    } finally {
      setLoadingOrders(false)
    }
  }, [])

  useEffect(() => {
    if (storeId) loadOrders(storeId, dateFrom, dateTo, page)
  }, [storeId, dateFrom, dateTo, page, loadOrders])

  // Re-fetch from page 1 when date changes
  function applyFilter() {
    setPage(1)
    loadOrders(storeId, dateFrom, dateTo, 1)
  }

  // ── Excel export ─────────────────────────────────────────────────────────
  async function exportExcel() {
    if (!storeId) return
    setExporting(true)
    try {
      const toEnd = dateTo + 'T23:59:59.999Z'
      // Fetch all pages
      let allOrders: Order[] = []
      let pg = 1
      while (true) {
        const res = await api.get<{ orders: Order[]; total: number }>(
          `/me/stores/${storeId}/orders?tab=history&dateFrom=${dateFrom}&dateTo=${toEnd}&page=${pg}&limit=200`
        )
        allOrders = allOrders.concat(res.orders)
        if (allOrders.length >= res.total) break
        pg++
      }

      const rows = allOrders.map((o) => ({
        'Mã đơn':            o.code,
        'Ngày đặt':          fmtDateTime(o.createdAt),
        'PTTT':              PAYMENT_METHOD_LABEL[o.paymentMethod] ?? o.paymentMethod,
        'Tiền hàng (đ)':     o.itemsTotal,
        'Phí ship (đ)':      o.shipFee,
        'Tổng tiền (đ)':     o.totalAmount,
        'Đã nhận (đ)':       o.paidAmount,
        'Trạng thái TT':     PAYMENT_STATUS_LABEL[o.paymentStatus] ?? o.paymentStatus,
        'Trạng thái đơn':    o.mainStatus,
      }))

      // Summary rows
      const completed = allOrders.filter(o => o.mainStatus === 'completed')
      const totalRevenue = completed.reduce((s, o) => s + o.totalAmount, 0)
      const totalReceived = allOrders.reduce((s, o) => s + o.paidAmount, 0)

      const summaryRows = [
        {},
        { 'Mã đơn': '--- TÓM TẮT ---' },
        { 'Mã đơn': 'Tổng đơn trong kỳ', 'Ngày đặt': allOrders.length },
        { 'Mã đơn': 'Đơn hoàn thành', 'Ngày đặt': completed.length },
        { 'Mã đơn': 'Doanh thu (đơn hoàn thành)', 'Ngày đặt': totalRevenue },
        { 'Mã đơn': 'Tổng đã thu', 'Ngày đặt': totalReceived },
        { 'Mã đơn': 'Kỳ báo cáo', 'Ngày đặt': `${dateFrom} → ${dateTo}` },
      ]

      const ws = XLSX.utils.json_to_sheet([...rows, ...summaryRows])
      // Column widths
      ws['!cols'] = [
        { wch: 16 }, { wch: 20 }, { wch: 18 }, { wch: 16 },
        { wch: 14 }, { wch: 16 }, { wch: 14 }, { wch: 18 }, { wch: 18 },
      ]
      const wb = XLSX.utils.book_new()
      XLSX.utils.book_append_sheet(wb, ws, 'Báo cáo')
      XLSX.writeFile(wb, `bao-cao-${dateFrom}-${dateTo}.xlsx`)
    } catch (e: any) {
      alert('Xuất file thất bại: ' + (e?.message ?? ''))
    } finally {
      setExporting(false)
    }
  }

  // ── Derived data ──────────────────────────────────────────────────────────
  const chartData = buildChartData(orders, dateFrom, dateTo)
  const totalPages = Math.ceil(total / PAGE_SIZE)

  // ── Render ────────────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center text-[#6B5C3E]">
        Đang tải...
      </div>
    )
  }

  if (!storeId) {
    return (
      <div className="flex h-64 items-center justify-center text-[#6B5C3E]">
        Không tìm thấy thông tin quán.
      </div>
    )
  }

  return (
    <div className="space-y-6 p-6">
      <h1 className="text-xl font-bold text-[#1A1200]">Báo cáo</h1>

      {error && (
        <div className="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
      )}

      {/* ── Summary cards (this month) ─────────────────────────────────── */}
      {stats && (
        <div>
          <p className="mb-2 text-xs font-medium uppercase tracking-wide text-[#6B5C3E]">
            Tháng này
          </p>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <StatCard
              label="Doanh thu"
              value={formatVND(stats.revenueThisMonth)}
              color="text-[#1D7A4E]"
            />
            <StatCard
              label="Đơn hoàn thành"
              value={String(stats.completedOrdersThisMonth)}
              color="text-[#1D7A4E]"
            />
            <StatCard
              label="Đơn hôm nay"
              value={String(stats.ordersToday)}
              color="text-blue-600"
            />
            <StatCard
              label="Đánh giá TB"
              value={stats.avgRating ? `${stats.avgRating} ★` : '—'}
              color="text-amber-600"
              sub={stats.totalReviews ? `${stats.totalReviews} đánh giá` : undefined}
            />
          </div>
        </div>
      )}

      {/* ── Date filter ───────────────────────────────────────────────────── */}
      <div className="flex flex-wrap items-end gap-3">
        <div>
          <label className="mb-1 block text-xs text-[#6B5C3E]">Từ ngày</label>
          <input
            type="date"
            value={dateFrom}
            max={dateTo}
            onChange={(e) => setDateFrom(e.target.value)}
            className="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-sm text-[#1A1200] focus:outline-none focus:ring-2 focus:ring-[#1D7A4E]/30"
          />
        </div>
        <div>
          <label className="mb-1 block text-xs text-[#6B5C3E]">Đến ngày</label>
          <input
            type="date"
            value={dateTo}
            min={dateFrom}
            max={todayISO()}
            onChange={(e) => setDateTo(e.target.value)}
            className="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-sm text-[#1A1200] focus:outline-none focus:ring-2 focus:ring-[#1D7A4E]/30"
          />
        </div>
        <button
          onClick={applyFilter}
          className="rounded-lg bg-[#1D7A4E] px-4 py-1.5 text-sm font-medium text-white hover:bg-[#166040]"
        >
          Lọc
        </button>
        <button
          onClick={exportExcel}
          disabled={exporting || loadingOrders}
          className="ml-auto rounded-lg border border-[#1D7A4E] px-4 py-1.5 text-sm font-medium text-[#1D7A4E] hover:bg-[#1D7A4E]/5 disabled:opacity-50"
        >
          {exporting ? 'Đang xuất...' : 'Xuất Excel'}
        </button>
      </div>

      {/* ── Revenue chart ────────────────────────────────────────────────── */}
      {chartData.length > 0 && (
        <div className="rounded-xl border border-gray-100 bg-white p-4">
          <p className="mb-3 text-sm font-semibold text-[#1A1200]">
            Doanh thu theo ngày (đơn hoàn thành)
          </p>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={chartData} margin={{ top: 0, right: 8, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis
                dataKey="date"
                tick={{ fontSize: 11, fill: '#6B5C3E' }}
                tickLine={false}
                axisLine={false}
                interval="preserveStartEnd"
              />
              <YAxis
                tick={{ fontSize: 11, fill: '#6B5C3E' }}
                tickLine={false}
                axisLine={false}
                tickFormatter={(v) => v >= 1000 ? `${(v / 1000).toFixed(0)}k` : String(v)}
                width={48}
              />
              <Tooltip
                formatter={(value) => [formatVND(Number(value ?? 0)), 'Doanh thu']}
                labelFormatter={(label) => `Ngày ${label}`}
                contentStyle={{ fontSize: 12, borderRadius: 8, border: '1px solid #e5e7eb' }}
              />
              <Bar dataKey="revenue" fill="#1D7A4E" radius={[3, 3, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* ── Orders table ─────────────────────────────────────────────────── */}
      <div className="rounded-xl border border-gray-100 bg-white">
        <div className="flex items-center justify-between border-b border-gray-100 px-4 py-3">
          <p className="text-sm font-semibold text-[#1A1200]">
            Lịch sử đơn hàng
            {total > 0 && (
              <span className="ml-2 text-xs font-normal text-[#6B5C3E]">({total} đơn)</span>
            )}
          </p>
          {loadingOrders && (
            <span className="text-xs text-[#6B5C3E]">Đang tải...</span>
          )}
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 text-xs font-medium uppercase tracking-wide text-[#6B5C3E]">
                <th className="px-4 py-2 text-left">Mã đơn</th>
                <th className="px-4 py-2 text-left">Ngày đặt</th>
                <th className="px-4 py-2 text-left">PTTT</th>
                <th className="px-4 py-2 text-right">Tiền hàng</th>
                <th className="px-4 py-2 text-right">Phí ship</th>
                <th className="px-4 py-2 text-right">Tổng tiền</th>
                <th className="px-4 py-2 text-right">Đã nhận</th>
                <th className="px-4 py-2 text-left">Trạng thái TT</th>
              </tr>
            </thead>
            <tbody>
              {orders.length === 0 && !loadingOrders && (
                <tr>
                  <td colSpan={8} className="px-4 py-8 text-center text-[#6B5C3E]">
                    Không có đơn hàng trong khoảng thời gian này.
                  </td>
                </tr>
              )}
              {orders.map((o) => (
                <tr key={o._id} className="border-b border-gray-50 hover:bg-[#FDFAF3]/60">
                  <td className="px-4 py-2.5 font-mono text-xs text-[#1D7A4E]">{o.code}</td>
                  <td className="px-4 py-2.5 text-xs text-[#6B5C3E]">{fmtDate(o.createdAt)}</td>
                  <td className="px-4 py-2.5 text-xs">
                    {PAYMENT_METHOD_LABEL[o.paymentMethod] ?? o.paymentMethod}
                  </td>
                  <td className="px-4 py-2.5 text-right text-xs">{o.itemsTotal.toLocaleString('vi-VN')}</td>
                  <td className="px-4 py-2.5 text-right text-xs">{o.shipFee.toLocaleString('vi-VN')}</td>
                  <td className="px-4 py-2.5 text-right text-xs font-semibold">{o.totalAmount.toLocaleString('vi-VN')}</td>
                  <td className="px-4 py-2.5 text-right text-xs text-[#1D7A4E]">{o.paidAmount.toLocaleString('vi-VN')}</td>
                  <td className="px-4 py-2.5">
                    <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${PAYMENT_STATUS_COLOR[o.paymentStatus] ?? 'bg-gray-50 text-gray-600'}`}>
                      {PAYMENT_STATUS_LABEL[o.paymentStatus] ?? o.paymentStatus}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between border-t border-gray-100 px-4 py-2">
            <span className="text-xs text-[#6B5C3E]">
              Trang {page}/{totalPages}
            </span>
            <div className="flex gap-1">
              <button
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page === 1}
                className="rounded px-2 py-1 text-xs text-[#1D7A4E] hover:bg-[#1D7A4E]/5 disabled:opacity-40"
              >
                ← Trước
              </button>
              <button
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                disabled={page === totalPages}
                className="rounded px-2 py-1 text-xs text-[#1D7A4E] hover:bg-[#1D7A4E]/5 disabled:opacity-40"
              >
                Sau →
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

// ── Sub-components ─────────────────────────────────────────────────────────

function StatCard({
  label, value, color, sub,
}: {
  label: string; value: string; color: string; sub?: string
}) {
  return (
    <div className="rounded-xl border border-gray-100 bg-white p-4">
      <p className="text-xs text-[#6B5C3E]">{label}</p>
      <p className={`mt-1 text-xl font-bold ${color}`}>{value}</p>
      {sub && <p className="mt-0.5 text-xs text-[#6B5C3E]">{sub}</p>}
    </div>
  )
}
