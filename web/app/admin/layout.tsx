import Link from 'next/link'
import { UserDisplay } from './UserDisplay'

const NAV = [
  { href: '/admin',           label: 'Tổng quan' },
  { href: '/admin/analytics', label: 'Thống kê' },
  { href: '/admin/orders',    label: 'Đơn hàng' },
  { href: '/admin/stores',    label: 'Quán' },
  { href: '/admin/users',     label: 'Người dùng' },
  { href: '/admin/products',  label: 'Sản phẩm' },
  { href: '/admin/reports',   label: 'Vi phạm' },
  { href: '/admin/support',   label: 'Hỗ trợ' },
  { href: '/admin/audit-log', label: 'Nhật ký' },
  { href: '/admin/settings',  label: 'Cài đặt' },
]

// Auth is enforced by middleware.ts — no cookies() call here to avoid
// implicit Set-Cookie side effects in Next.js 16 server component rendering
export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-screen bg-[#FDFAF3]">
      <aside className="hidden w-52 flex-shrink-0 flex-col border-r border-gray-200 bg-white lg:flex">
        <div className="flex h-14 items-center border-b border-gray-100 px-4">
          <span className="text-lg font-bold text-[#1D7A4E]">Vifosa</span>
          <span className="ml-2 rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-700">Admin</span>
        </div>

        <nav className="flex-1 space-y-0.5 p-2">
          {NAV.map(({ href, label }) => (
            <Link
              key={href}
              href={href}
              className="flex items-center rounded-lg px-3 py-2 text-sm font-medium text-[#1A1200] transition-colors hover:bg-[#F5C842]/10 hover:text-[#1D7A4E]"
            >
              {label}
            </Link>
          ))}
        </nav>

        <div className="border-t border-gray-100 p-3">
          <p className="mb-2 truncate text-xs text-[#6B5C3E]"><UserDisplay /></p>
          <form action="/api/logout" method="POST">
            <button
              type="submit"
              className="block w-full rounded-lg px-3 py-1.5 text-left text-xs text-gray-500 hover:bg-gray-100"
            >
              Đăng xuất
            </button>
          </form>
        </div>
      </aside>

      <main className="flex-1 overflow-auto">{children}</main>
    </div>
  )
}
