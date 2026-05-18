import { NextResponse } from 'next/server'
import { cookies } from 'next/headers'

export async function GET() {
  const cookieStore = await cookies()

  // Gọi backend để clear httpOnly cookie phía server
  try {
    await fetch(`${process.env.NEXT_PUBLIC_API_URL}/auth/logout`, {
      method: 'POST',
      credentials: 'include',
      headers: { Cookie: cookieStore.toString() },
    })
  } catch {}

  const res = NextResponse.redirect(
    new URL('/login', process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000'),
  )

  // Clear client-readable cookies
  res.cookies.set('userRoles', '', { maxAge: 0, path: '/' })

  return res
}
