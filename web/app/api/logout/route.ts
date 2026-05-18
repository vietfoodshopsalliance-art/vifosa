import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'

export async function POST(request: NextRequest) {
  const cookieStore = await cookies()

  try {
    await fetch(`${process.env.NEXT_PUBLIC_API_URL}/auth/logout`, {
      method: 'POST',
      headers: { Cookie: cookieStore.toString() },
    })
  } catch {}

  const res = NextResponse.redirect(new URL('/login', request.url))
  res.cookies.set('userRoles', '', { maxAge: 0, path: '/' })
  res.cookies.set('userName', '', { maxAge: 0, path: '/' })
  return res
}
