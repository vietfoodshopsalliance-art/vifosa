// Client-side: route through /api/proxy (Next.js API route, same origin, no CORS).
// Server-side: call Render directly.
const API = typeof window !== 'undefined'
  ? '/api/proxy'
  : (process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8080')

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE'

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message)
  }
}

async function request<T>(method: Method, path: string, body?: unknown, extraHeaders?: Record<string, string>): Promise<T> {
  const res = await fetch(`${API}${path}`, {
    method,
    credentials: 'include',
    headers: { ...(body ? { 'Content-Type': 'application/json' } : {}), ...extraHeaders },
    body: body ? JSON.stringify(body) : undefined,
  })

  if (!res.ok) {
    let message = `HTTP ${res.status}`
    try {
      const data = await res.json()
      message = data?.message ?? message
    } catch {}
    throw new ApiError(res.status, message)
  }

  if (res.status === 204) return undefined as T
  return res.json()
}

export const api = {
  get:    <T>(path: string, h?: Record<string, string>) => request<T>('GET', path, undefined, h),
  post:   <T>(path: string, body: unknown, h?: Record<string, string>) => request<T>('POST', path, body, h),
  put:    <T>(path: string, body: unknown, h?: Record<string, string>) => request<T>('PUT', path, body, h),
  patch:  <T>(path: string, body: unknown, h?: Record<string, string>) => request<T>('PATCH', path, body, h),
  delete: <T>(path: string, h?: Record<string, string>) => request<T>('DELETE', path, undefined, h),
}
