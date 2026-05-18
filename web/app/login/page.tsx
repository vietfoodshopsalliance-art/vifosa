'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import type { Metadata } from 'next'

export default function LoginPage() {
  const router = useRouter()
  const [identifier, setIdentifier] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      const loginRes = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/auth/login`,
        {
          method: 'POST',
          credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ identifier, password }),
        },
      )

      if (loginRes.status === 429) {
        setError('Quá nhiều lần thử, vui lòng thử lại sau.')
        return
      }
      if (!loginRes.ok) {
        setError('Đăng nhập thất bại. Vui lòng kiểm tra lại thông tin.')
        return
      }

      const loginData = await loginRes.json()
      const roles: string[] = loginData?.data?.user?.roles ?? []

      // Lưu roles vào cookie để middleware đọc (không sensitive — bảo mật thực qua httpOnly token)
      document.cookie = `userRoles=${roles.join(',')}; path=/; max-age=1800; SameSite=Strict`

      if (roles.includes('admin')) {
        router.push('/admin')
      } else if (roles.includes('store_owner') || roles.includes('mod')) {
        router.push('/store')
      } else {
        setError('Tài khoản không có quyền truy cập dashboard.')
        document.cookie = 'userRoles=; path=/; max-age=0'
      }
    } catch {
      setError('Có lỗi xảy ra. Vui lòng thử lại.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-[#FDFAF3] px-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <h1 className="text-3xl font-bold text-[#1D7A4E]">Vifosa</h1>
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
          Vifosa — Dành cho quản trị viên và chủ quán
        </p>
      </div>
    </div>
  )
}
