'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  LineChart, Line, BarChart, Bar,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
} from 'recharts'
import { api } from '@/lib/api'

type Period = '7d' | '30d' | '90d'

interface OrderDay {
  _id: string
  total: number
  completed: number
  cancelled: number
  revenue: number
}

interface TopStore {
  storeId: string
  storeName?: string
  orderCount: number
  revenue: number
}

interface TopItem {
  _id: string
  name?: string
  totalSold: number
}

interface CancelRate {
  total: number
  cancelled: number
  refunded: number
  cancellationRate: number
  refundRate: number
}

interface AnalyticsData {
  orders: OrderDay[]
  topStores: TopStore[]
  topItems: TopItem[]
  cancelRate: CancelRate
}

function formatDate(iso: string) {
  const [, m, d] = iso.split('-')
  return `${parseInt(d)}/${parseInt(m)}`
}

export default function AdminAnalyticsPage() {
  const [period, setPeriod] = useState<Period>('7d')
  const [data, setData] = useState<AnalyticsData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchAll = useCallback(async (p: Period) => {
    setLoading(true)
    setError(null)
    try {
      const [orders, topStores, topItems, cancelRate] = await Promise.all([
        api.get<OrderDay[]>(`/admin/analytics/orders?period=${p}`),
        api.get<TopStore[]>(`/admin/analytics/top-stores?period=${p}&limit=5`),
        api.get<TopItem[]>(`/admin/analytics/top-items?period=${p}&limit=5`),
        api.get<CancelRate>(`/admin/analytics/cancellation-rate?period=${p}`),
      ])
      setData({ orders, topStores, topItems, cancelRate })
    } catch (e: any) {
      setError(e?.message ?? 'Lỗi tải dữ liệu')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => { fetchAll(period) }, [period, fetchAll])

  const chartOrders = (data?.orders ?? []).map((o) => ({
    date: formatDate(o._id),
    revenue: o.revenue,
    total: o.total,
    completed: o.completed,
    cancelled: o.cancelled,
  }))

  const cancelPct = data
    ? (data.cancelRate.cancellationRate * 100).toFixed(1)
    : '—'

  return (
    <div className="p-6">
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-xl font-bold text-[#1A1200]">Thống kê chi tiết</h1>
        <div className="flex gap-1 rounded-lg border border-gray-200 bg-white p-1">
          {(['7d', '30d', '90d'] as Period[]).map((p) => (
            <button
              key={p}
              onClick={() => setPeriod(p)}
              className={`rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
                period === p
                  ? 'bg-[#F5C842] text-[#3D2800]'
                  : 'text-[#6B5C3E] hover:bg-gray-100'
              }`}
            >
              {p === '7d' ? '7 ngày' : p === '30d' ? '30 ngày' : '90 ngày'}
            </button>
          ))}
        </div>
      </div>

      {error && (
        <div className="mb-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Summary row */}
      <div className="mb-6 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <StatCard
          label="Tỷ lệ huỷ đơn"
          value={loading ? '…' : `${cancelPct}%`}
          sub={data ? `${data.cancelRate.cancelled}/${data.cancelRate.total}` : ''}
          color="text-red-600"
        />
        <StatCard
          label="Đơn hoàn thành"
          value={loading ? '…' : String(data?.orders.reduce((s, o) => s + o.completed, 0) ?? 0)}
          sub="kỳ này"
          color="text-green-600"
        />
        <StatCard
          label="Đơn bị huỷ"
          value={loading ? '…' : String(data?.cancelRate.cancelled ?? 0)}
          sub="kỳ này"
          color="text-amber-600"
        />
        <StatCard
          label="Tổng đơn"
          value={loading ? '…' : String(data?.cancelRate.total ?? 0)}
          sub="kỳ này"
          color="text-blue-600"
        />
      </div>

      {/* Revenue chart */}
      <div className="mb-6 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
        <h2 className="mb-4 text-sm font-semibold text-[#1A1200]">Doanh thu đơn hoàn thành (VNĐ)</h2>
        {loading ? (
          <div className="flex h-[220px] items-center justify-center text-sm text-[#6B5C3E]">Đang tải…</div>
        ) : (
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={chartOrders}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="date" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 12 }} tickFormatter={(v) => `${(v / 1000).toFixed(0)}k`} />
              <Tooltip formatter={(v) => [`${Number(v).toLocaleString('vi-VN')}đ`, 'Doanh thu']} />
              <Line type="monotone" dataKey="revenue" stroke="#F5C842" strokeWidth={2} dot={{ fill: '#F5C842' }} />
            </LineChart>
          </ResponsiveContainer>
        )}
      </div>

      {/* Orders count chart */}
      <div className="mb-6 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
        <h2 className="mb-4 text-sm font-semibold text-[#1A1200]">Tổng đơn theo ngày</h2>
        {loading ? (
          <div className="flex h-[200px] items-center justify-center text-sm text-[#6B5C3E]">Đang tải…</div>
        ) : (
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={chartOrders}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="date" tick={{ fontSize: 12 }} />
              <YAxis tick={{ fontSize: 12 }} />
              <Tooltip formatter={(v, name) => [Number(v), name === 'completed' ? 'Hoàn thành' : name === 'cancelled' ? 'Huỷ' : 'Tổng']} />
              <Bar dataKey="completed" fill="#1D7A4E" radius={[4, 4, 0, 0]} stackId="a" />
              <Bar dataKey="cancelled" fill="#EF4444" radius={[4, 4, 0, 0]} stackId="a" />
            </BarChart>
          </ResponsiveContainer>
        )}
      </div>

      {/* Top stores & items */}
      <div className="grid gap-4 sm:grid-cols-2">
        <RankTable
          title={`Top 5 quán bán chạy (${period === '7d' ? '7' : period === '30d' ? '30' : '90'} ngày)`}
          rows={(data?.topStores ?? []).map((s) => ({
            name: s.storeName ?? s.storeId,
            orders: s.orderCount,
          }))}
          valueLabel="đơn"
          loading={loading}
        />
        <RankTable
          title={`Top 5 món bán chạy (${period === '7d' ? '7' : period === '30d' ? '30' : '90'} ngày)`}
          rows={(data?.topItems ?? []).map((item) => ({
            name: item.name ?? item._id,
            orders: item.totalSold,
          }))}
          valueLabel="lượt"
          loading={loading}
        />
      </div>
    </div>
  )
}

function StatCard({ label, value, sub, color }: { label: string; value: string; sub: string; color: string }) {
  return (
    <div className="rounded-xl border border-gray-100 bg-white p-4 shadow-sm">
      <div className={`text-2xl font-bold ${color}`}>{value}</div>
      <div className="mt-0.5 text-xs text-[#6B5C3E]">{sub}</div>
      <div className="mt-1 text-sm font-medium text-[#1A1200]">{label}</div>
    </div>
  )
}

function RankTable({ title, rows, valueLabel, loading }: {
  title: string
  rows: { name: string; orders: number }[]
  valueLabel: string
  loading: boolean
}) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
      <h2 className="mb-3 text-sm font-semibold text-[#1A1200]">{title}</h2>
      {loading ? (
        <div className="py-4 text-center text-sm text-[#6B5C3E]">Đang tải…</div>
      ) : rows.length === 0 ? (
        <div className="py-4 text-center text-sm text-[#6B5C3E]">Chưa có dữ liệu</div>
      ) : (
        <div className="space-y-2">
          {rows.map((r, i) => (
            <div key={i} className="flex items-center gap-3">
              <span className="w-5 text-center text-xs font-bold text-[#6B5C3E]">{i + 1}</span>
              <span className="flex-1 truncate text-sm text-[#1A1200]">{r.name}</span>
              <span className="text-sm font-semibold text-[#1D7A4E]">{r.orders} {valueLabel}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
