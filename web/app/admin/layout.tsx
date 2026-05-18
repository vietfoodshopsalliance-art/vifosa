import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import Link from 'next/link'

const NAV = [
  { href: '/admin',           label: 'Tổng quan' },
  { href: '/admin/analytics', label: 'Thống kê' },
  { href: '/admin/orders',    label: 'Đơn hàng' },
  { href: '/admin/stores',    label: 'Quán' },
  { href: '/admin/users',     label: 'Người dùng' },
  { href: '/admin/reports',   label: 'Vi phạm' },
  { href: '/admin/support',   label: 'Hỗ trợ' },
  { href: '/admin/audit-log', label: 'Nhật ký' },
  { href: '/admin/settings',  label: 'Cài đặt' },
]

async function getMe() {
  const cookieStore = await cookies()
  const token = cookieStore.get('accessToken')?.value
  if (!token) return null
  try {
    const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/me`, {
      headers: { Cookie: cookieStore.toString() },
      cache: 'no-store',
    })
    if (!res.ok) return null
    return res.json()
  } catch {
    return null
  }
}

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const me = await getMe()
  if (!me || !me.roles?.includes('admin')) redirect('/login')

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
          <p className="mb-2 truncate text-xs text-[#6B5C3E]">{me.username}</p>
          <Link
            href="/api/logout"
            className="block rounded-lg px-3 py-1.5 text-xs text-gray-500 hover:bg-gray-100"
          >
            Đăng xuất
          </Link>
        </div>
      </aside>

      <main className="flex-1 overflow-auto">{children}</main>
    </div>
  )
}
