import { NextResponse } from 'next/server'

// Receives a short-lived base64 token from loginAction, sets session cookies,
// and redirects to /admin or /store. This GET redirect chain guarantees the
// browser commits Set-Cookie headers before navigating — unlike Server Action
// cookie mutations which are not reliably committed before client navigation.
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const token = searchParams.get('t')

  if (!token) {
    return NextResponse.redirect(`${origin}/login`)
  }

  try {
    const payload: { roles: string[]; username: string; exp: number } = JSON.parse(
      Buffer.from(token, 'base64url').toString('utf-8'),
    )

    if (Date.now() > payload.exp) {
      return NextResponse.redirect(`${origin}/login`)
    }

    const { roles, username } = payload
    if (!roles.includes('admin') && !roles.includes('store_owner') && !roles.includes('mod')) {
      return NextResponse.redirect(`${origin}/login`)
    }

    const secure = process.env.NODE_ENV === 'production'
    const destination = roles.includes('admin') ? `${origin}/admin` : `${origin}/store`

    const response = NextResponse.redirect(destination)
    response.cookies.set('userRoles', roles.join('|'), {
      path: '/', maxAge: 1800, sameSite: 'lax', secure, httpOnly: true,
    })
    response.cookies.set('userName', username, {
      path: '/', maxAge: 1800, sameSite: 'lax', secure, httpOnly: false,
    })
    return response
  } catch {
    return NextResponse.redirect(`${origin}/login`)
  }
}
