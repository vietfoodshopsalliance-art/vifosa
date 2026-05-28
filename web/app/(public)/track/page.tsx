'use client'

import { useState, Suspense } from 'react'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

function TrackForm() {
  const router = useRouter()
  const [code, setCode]     = useState('')
  const [phone, setPhone]   = useState('')
  const [error, setError]   = useState('')
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_API_URL}/orders/track`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ code: code.trim().toUpperCase(), phone: phone.trim() }),
        },
      )

      if (!res.ok) {
        setError('Không tìm thấy đơn hàng với thông tin đã nhập.')
        return
      }

      const data = await res.json()
      router.push(`/track/${data.code}?t=${data.trackingToken}`)
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
          <Link href="/" className="text-3xl font-bold text-[#1D7A4E]">Viet Shops</Link>
          <p className="mt-2 text-sm text-[#6B5C3E]">Tra cứu đơn hàng</p>
        </div>

        <form onSubmit={handleSubmit} className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm space-y-4">
          <div>
            <label className="mb-1 block text-sm font-medium text-[#1A1200]">Mã đơn hàng</label>
            <input
              type="text"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              required
              placeholder="VD: AB251107-456"
              className="w-full rounded-lg border border-gray-300 px-3 py-2.5 font-mono text-sm text-[#1A1200] uppercase focus:border-[#1D7A4E] focus:outline-none focus:ring-1 focus:ring-[#1D7A4E]"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium text-[#1A1200]">Số điện thoại đặt đơn</label>
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              required
              placeholder="09xxxxxxxx"
              className="w-full rounded-lg border border-gray-300 px-3 py-2.5 text-sm text-[#1A1200] focus:border-[#1D7A4E] focus:outline-none focus:ring-1 focus:ring-[#1D7A4E]"
            />
          </div>

          {error && (
            <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{error}</p>
          )}

          <button
            type="submit"
            disabled={loading || !code || !phone}
            className="w-full rounded-lg bg-[#F5C842] py-2.5 text-sm font-semibold text-[#3D2800] transition-colors hover:bg-[#D4A820] disabled:opacity-50"
          >
            {loading ? 'Đang tìm kiếm...' : 'Tra cứu'}
          </button>
        </form>

        <p className="mt-6 text-center text-xs text-[#6B5C3E]">
          <Link href="/" className="hover:underline">← Về trang chủ</Link>
        </p>
      </div>
    </div>
  )
}

export default function TrackPage() {
  return (
    <Suspense>
      <TrackForm />
    </Suspense>
  )
}
