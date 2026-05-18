import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'

const BACKEND = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8080'

async function proxy(req: NextRequest, path: string): Promise<NextResponse> {
  const cookieStore = await cookies()
  const token = cookieStore.get('accessToken')?.value

  const url = `${BACKEND}/${path}${req.nextUrl.search}`

  const headers: Record<string, string> = {}
  const ct = req.headers.get('content-type')
  if (ct) headers['Content-Type'] = ct
  if (token) headers['Authorization'] = `Bearer ${token}`

  const hasBody = req.method !== 'GET' && req.method !== 'HEAD'
  const body = hasBody ? await req.text() : undefined

  const upstream = await fetch(url, { method: req.method, headers, body })

  const text = await upstream.text()
  return new NextResponse(text, {
    status: upstream.status,
    headers: { 'Content-Type': upstream.headers.get('content-type') ?? 'application/json' },
  })
}

function handler(req: NextRequest, ctx: { params: Promise<{ path: string[] }> }) {
  return ctx.params.then(({ path }) => proxy(req, path.join('/')))
}

export const GET     = handler
export const POST    = handler
export const PUT     = handler
export const PATCH   = handler
export const DELETE  = handler
