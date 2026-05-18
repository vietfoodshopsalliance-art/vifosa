import { NextResponse } from 'next/server'

export async function POST(request: Request) {
  const { roles, username } = await request.json()
  const res = NextResponse.json({ ok: true })
  const opts = { path: '/', maxAge: 1800, sameSite: 'lax' as const, httpOnly: false }
  res.cookies.set('userRoles', Array.isArray(roles) ? roles.join(',') : '', opts)
  res.cookies.set('userName', username ?? '', opts)
  return res
}
