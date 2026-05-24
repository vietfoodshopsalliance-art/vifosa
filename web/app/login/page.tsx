'use client'

import { useState } from 'react'

const API = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8080'

export default function LoginPage() {
  const [identifier, setIdentifier] = useState('')
  const [password, setPassword]     = useState('')
  const [error, setError]           = useState('')
  const [loading, setLoading]       = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      // Browser fetch trực tiếp → backend set httpOnly accessToken cookie lên browser
      const res = await fetch(`${API}/auth/login`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier, password }),
      })

      if (res.status === 429) {
        setError('Quá nhiều lần thử, vui lòng thử lại sau.')
        return
      }
      if (!res.ok) {
        setError('Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.')
        return
      }

      const data = await res.json()
      const roles: string[]        = data?.data?.user?.roles ?? []
      const username: string       = data?.data?.user?.username ?? ''
      const storeId: string        = data?.data?.user?.storeId ?? ''
      const accessToken: string    = data?.data?.accessToken ?? ''

      if (!roles.includes('admin') && !roles.includes('store_owner') && !roles.includes('mod')) {
        setError('Tài khoản không có quyền truy cập dashboard.')
        return
      }

      // Lưu accessToken vào cookie Vercel-domain để proxy dùng
      if (accessToken) {
        await fetch('/api/set-session', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ accessToken }),
        })
      }

      // Gửi roles+username+storeId qua auth-callback để set web cookies, sau đó redirect
      const payload = { roles, username, storeId, exp: Date.now() + 30_000 }
      const token   = btoa(JSON.stringify(payload))
      window.location.href = `/api/auth-callback?t=${encodeURIComponent(token)}`
    } catch {
      setError('Không thể kết nối tới server. Vui lòng thử lại.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#FDFAF3] px-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <h1 className="text-3xl font-bold text-[#1D7A4E]">Viet Shops</h1>
          <p className="mt-1 text-sm text-[#6B5C3E]">Đăng nhập để quản lý</p>
        </div>

        <form onSubmit={handleSubmit} className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium text-[#1A1200]">
              Username, email hoặc số điện thoại
            </label>
            <input
              type="text"
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              autoComplete="username"
              required
              className="w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm text-[#1A1200] placeholder-[#6B5C3E] focus:border-[#1D7A4E] focus:outline-none focus:ring-1 focus:ring-[#1D7A4E]"
              placeholder="Nhập username, email hoặc SĐT"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium text-[#1A1200]">
              Mật khẩu
            </label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
              className="w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm text-[#1A1200] placeholder-[#6B5C3E] focus:border-[#1D7A4E] focus:outline-none focus:ring-1 focus:ring-[#1D7A4E]"
              placeholder="Mật khẩu"
            />
          </div>

          {error && (
            <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
              {error}
            </p>
          )}

          <button
            type="submit"
            disabled={loading || !identifier || !password}
            className="w-full rounded-lg bg-[#F5C842] py-2.5 text-sm font-semibold text-[#3D2800] transition-colors hover:bg-[#D4A820] disabled:cursor-not-allowed disabled:opacity-50"
          >
            {loading ? 'Đang đăng nhập...' : 'Đăng nhập'}
          </button>
        </form>

        <p className="mt-6 text-center text-xs text-[#6B5C3E]">
          Dành cho chủ quán quản lý cửa hàng và xem báo cáo
        </p>
      </div>
    </div>
  )
}
