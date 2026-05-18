'use server'

import { cookies } from 'next/headers'

export async function loginAction(identifier: string, password: string) {
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identifier, password }),
    cache: 'no-store',
  })

  if (res.status === 429) return { error: 'Quá nhiều lần thử, vui lòng thử lại sau.' }
  if (!res.ok) return { error: 'Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.' }

  const data = await res.json()
  const roles: string[] = data?.data?.user?.roles ?? []
  const username: string = data?.data?.user?.username ?? ''

  const cookieStore = await cookies()
  cookieStore.set('userRoles', roles.join(','), { path: '/', maxAge: 1800, sameSite: 'lax' })
  cookieStore.set('userName', username, { path: '/', maxAge: 1800, sameSite: 'lax' })

  if (roles.includes('admin')) return { redirect: '/admin' }
  if (roles.includes('store_owner') || roles.includes('mod')) return { redirect: '/store' }
  return { error: 'Tài khoản không có quyền truy cập dashboard.' }
}
