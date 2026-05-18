'use client'

import { useState } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { Suspense } from 'react'

function RegisterForm() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const prefillPhone = searchParams.get('phone') ?? ''
  const returnTo     = searchParams.get('returnTo') ?? '/'

  const [phone, setPhone]       = useState(prefillPhone)
  const [password, setPassword] = useState('')
  const [confirm, setConfirm]   = useState('')
  const [error, setError]       = useState('')
  const [loading, setLoading]   = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')

    if (password !== confirm) {
      setError('Mật khẩu xác nhận không khớp.')
      return
    }
    if (password.length < 8) {
      setError('Mật khẩu phải có ít nhất 8 ký tự.')
      return
    }

    setLoading(true)
    try {
      // TODO Phase 2 (RC-7): POST /auth/register tự động link đơn guest theo phone
      const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/auth/register`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone, password }),
      })

      if (!res.ok) {
        const data = await res.json().catch(() => ({}))
        setError(data.message ?? 'Đăng ký thất bại. Vui lòng thử lại.')
        return
      }

      router.push(returnTo)
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
          <p className="mt-1 text-sm text-[#6B5C3E]">Tạo tài khoản</p>
        </div>

        <form onSubmit={handleSubmit} className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium text-[#1A1200]">Số điện thoại</label>
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              required
              pattern="0[0-9]{9}"
              placeholder="09xxxxxxxx"
              className="w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm text-[#1A1200] focus:border-[#1D7A4E] focus:outline-none focus:ring-1 focus:ring-[#1D7A4E]"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium text-[#1A1200]">Mật khẩu</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              minLength={8}
              placeholder="Ít nhất 8 ký tự"
              className="w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm focus:border-[#1D7A4E] focus:outline-none focus:ring-1 focus:ring-[#1D7A4E]"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium text-[#1A1200]">Xác nhận mật khẩu</label>
            <input
              type="password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
              required
              placeholder="Nhập lại mật khẩu"
              className="w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm focus:border-[#1D7A4E] focus:outline-none focus:ring-1 focus:ring-[#1D7A4E]"
            />
          </div>

          {error && (
            <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>
          )}

          <button
            type="submit"
            disabled={loading || !phone || !password || !confirm}
            className="w-full rounded-lg bg-[#F5C842] py-2.5 text-sm font-semibold text-[#3D2800] transition-colors hover:bg-[#D4A820] disabled:cursor-not-allowed disabled:opacity-50"
          >
            {loading ? 'Đang tạo tài khoản...' : 'Tạo tài khoản'}
          </button>
        </form>

        <p className="mt-4 text-center text-sm text-[#6B5C3E]">
          Đã có tài khoản?{' '}
          <Link href="/login" className="font-medium text-[#1D7A4E] hover:underline">Đăng nhập</Link>
        </p>
      </div>
    </div>
  )
}

export default function RegisterPage() {
  return (
    <Suspense>
      <RegisterForm />
    </Suspense>
  )
}
