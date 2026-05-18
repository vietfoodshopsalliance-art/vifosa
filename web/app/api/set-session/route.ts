import { NextResponse } from 'next/server'

export async function POST(request: Request) {
  const { accessToken } = await request.json()
  const res = NextResponse.json({ ok: true })
  const secure = process.env.NODE_ENV === 'production'
  if (accessToken) {
    res.cookies.set('accessToken', accessToken, {
      path: '/', maxAge: 900, sameSite: 'lax', secure, httpOnly: true,
    })
  }
  return res
}
