import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl
  // accessToken is scoped to the backend domain (onrender.com) — never visible here.
  // userRoles is set by the web app after successful login and serves as the session signal.
  const roles = request.cookies.get('userRoles')?.value ?? ''

  if (!roles) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  if (pathname.startsWith('/admin') && !roles.includes('admin')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  if (
    pathname.startsWith('/store') &&
    !roles.includes('store_owner') &&
    !roles.includes('mod')
  ) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/admin/:path*', '/store/:path*'],
}
