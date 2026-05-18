'use server'

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

  if (!roles.includes('admin') && !roles.includes('store_owner') && !roles.includes('mod')) {
    return { error: 'Tài khoản không có quyền truy cập dashboard.' }
  }

  // Encode roles+username in a short-lived token and redirect through /api/auth-callback.
  // The Route Handler sets Set-Cookie + redirects in one response, guaranteeing the browser
  // commits cookies before navigating — unlike Server Action cookies().set() which is unreliable.
  const payload = { roles, username, exp: Date.now() + 30_000 }
  const token = Buffer.from(JSON.stringify(payload)).toString('base64url')
  return { redirect: `/api/auth-callback?t=${encodeURIComponent(token)}` }
}
