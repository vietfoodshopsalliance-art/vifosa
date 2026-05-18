import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  const token = request.cookies.get('accessToken')?.value
  const { pathname } = request.nextUrl

  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  const roles = request.cookies.get('userRoles')?.value ?? ''

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
