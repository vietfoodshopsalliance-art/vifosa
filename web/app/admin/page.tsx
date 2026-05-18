import { cookies } from 'next/headers'
import Link from 'next/link'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Admin Dashboard — Vifosa' }

const MOCK_STATS = {
  ordersToday: 0,
  activeStores: 0,
  openTickets: 0,
  openReports: 0,
  alerts: [] as { type: string; message: string; href: string }[],
}

async function getDashboardStats() {
  const cookieStore = await cookies()
  try {
    const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/admin/dashboard-stats`, {
      headers: { Cookie: cookieStore.toString() },
      cache: 'no-store',
    })
    if (res.ok) return res.json()
  } catch {}
  return MOCK_STATS
}

export default async function AdminDashboardPage() {
  const stats = await getDashboardStats()

  const alerts: { type: string; message: string; href: string }[] = stats.alerts ?? []

  return (
    <div className="p-6">
      <h1 className="mb-6 text-xl font-bold text-[#1A1200]">Tổng quan</h1>

      {/* Alert panel */}
      {alerts.length > 0 && (
        <section className="mb-6 space-y-2">
          {alerts.map((a, i) => (
            <Link
              key={i}
              href={a.href}
              className="flex items-center gap-3 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-medium text-red-800 hover:bg-red-100 transition-colors"
            >
              <span className="text-base">⚠️</span>
              {a.message}
              <span className="ml-auto text-red-400">→</span>
            </Link>
          ))}
        </section>
      )}

      {alerts.length === 0 && (
        <div className="mb-6 flex items-center gap-3 rounded-xl border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-700">
          <span>✅</span> Không có cảnh báo nào cần xử lý.
        </div>
      )}

      {/* 4 metrics */}
      <section className="mb-8 grid grid-cols-2 gap-4 sm:grid-cols-4">
        <MetricCard label="Đơn hôm nay" value={stats.ordersToday ?? 0} color="text-blue-600" />
        <MetricCard label="Quán đang hoạt động" value={stats.activeStores ?? 0} color="text-green-600" />
        <MetricCard label="Support chưa đọc" value={stats.openTickets ?? 0} color="text-amber-600" alert={(stats.openTickets ?? 0) > 0} />
        <MetricCard label="Vi phạm mới" value={stats.openReports ?? 0} color="text-red-600" alert={(stats.openReports ?? 0) > 0} />
      </section>

      {/* Shortcuts */}
      <section>
        <h2 className="mb-3 text-sm font-semibold text-[#6B5C3E] uppercase tracking-wider">Truy cập nhanh</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          {[
            { href: '/admin/analytics', label: 'Thống kê chi tiết' },
            { href: '/admin/orders',    label: 'Đơn cần xử lý' },
            { href: '/admin/reports',   label: 'Báo cáo vi phạm' },
            { href: '/admin/support',   label: 'Support Tickets' },
            { href: '/admin/users',     label: 'Người dùng' },
          ].map(({ href, label }) => (
            <Link
              key={href}
              href={href}
              className="rounded-xl border border-gray-200 bg-white px-4 py-3 text-center text-sm font-medium text-[#1A1200] shadow-sm transition-all hover:border-[#F5C842] hover:shadow-md"
            >
              {label}
            </Link>
          ))}
        </div>
      </section>

    </div>
  )
}

function MetricCard({ label, value, color, alert = false }: {
  label: string; value: number; color: string; alert?: boolean
}) {
  return (
    <div className={`rounded-xl border bg-white p-4 shadow-sm ${alert ? 'border-red-200 ring-1 ring-red-200' : 'border-gray-100'}`}>
      <div className={`text-2xl font-bold ${color}`}>{value}</div>
      <div className="mt-1 text-xs text-[#6B5C3E]">{label}</div>
    </div>
  )
}
