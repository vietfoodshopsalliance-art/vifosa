'use client'

import { useState, useEffect, useCallback } from 'react'
import { api } from '@/lib/api'

interface Product {
  _id: string
  storeId: string
  name: string
  description: string
  price: number
  status: 'active' | 'closed' | 'paused'
  stock: number | null
  soldCount: { allTime: number; last30d: number }
  createdAt: string
}

const STATUS_LABEL: Record<string, string> = {
  active: 'Đang bán',
  paused: 'Tạm dừng',
  closed: 'Đóng',
}

const STATUS_COLOR: Record<string, string> = {
  active: 'bg-green-100 text-green-700',
  paused: 'bg-yellow-100 text-yellow-700',
  closed: 'bg-red-100 text-red-700',
}

export default function AdminProductsPage() {
  const [items, setItems]       = useState<Product[]>([])
  const [loading, setLoading]   = useState(true)
  const [search, setSearch]     = useState('')
  const [status, setStatus]     = useState('')
  const [nextCursor, setNextCursor] = useState<string | undefined>()

  const load = useCallback(async (cursor?: string) => {
    setLoading(true)
    try {
      const params = new URLSearchParams({ limit: '50' })
      if (search) params.set('search', search)
      if (status) params.set('status', status)
      if (cursor) params.set('cursor', cursor)
      const res = await api.get<{ items: Product[]; nextCursor?: string }>(`/admin/products?${params}`)
      const fetched = res.items ?? []
      setItems(cursor ? (prev) => [...prev, ...fetched] : fetched)
      setNextCursor(res.nextCursor)
    } catch { setItems([]) }
    finally { setLoading(false) }
  }, [search, status])

  useEffect(() => { load() }, [load])

  return (
    <div className="p-6">
      <h1 className="mb-6 text-xl font-bold text-[#1A1200]">Sản phẩm</h1>

      <div className="mb-4 flex flex-wrap gap-3">
        <input
          type="text"
          placeholder="Tìm tên sản phẩm..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-56 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-[#1D7A4E] focus:outline-none"
        />
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value)}
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none"
        >
          <option value="">Tất cả trạng thái</option>
          <option value="active">Đang bán</option>
          <option value="paused">Tạm dừng</option>
          <option value="closed">Đóng</option>
        </select>
      </div>

      <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white shadow-sm">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100 bg-gray-50 text-left text-xs font-semibold text-[#6B5C3E] uppercase">
              <th className="px-4 py-3">Tên sản phẩm</th>
              <th className="px-4 py-3">Giá</th>
              <th className="px-4 py-3">Trạng thái</th>
              <th className="px-4 py-3">Tồn kho</th>
              <th className="px-4 py-3">Đã bán (30 ngày)</th>
              <th className="px-4 py-3">Quán</th>
            </tr>
          </thead>
          <tbody>
            {loading && items.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-[#6B5C3E]">Đang tải...</td></tr>
            )}
            {!loading && items.length === 0 && (
              <tr><td colSpan={6} className="px-4 py-8 text-center text-[#6B5C3E]">Không có dữ liệu.</td></tr>
            )}
            {items.map((p) => (
              <tr key={p._id} className="border-b border-gray-50 hover:bg-gray-50">
                <td className="px-4 py-3 font-medium text-[#1A1200]">
                  {p.name}
                  {p.description && (
                    <div className="mt-0.5 text-xs text-[#6B5C3E] line-clamp-1">{p.description}</div>
                  )}
                </td>
                <td className="px-4 py-3 text-[#1A1200]">
                  {p.price.toLocaleString('vi-VN')}₫
                </td>
                <td className="px-4 py-3">
                  <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${STATUS_COLOR[p.status] ?? ''}`}>
                    {STATUS_LABEL[p.status] ?? p.status}
                  </span>
                </td>
                <td className="px-4 py-3 text-xs text-[#6B5C3E]">
                  {p.stock === null ? '∞' : p.stock}
                </td>
                <td className="px-4 py-3 text-xs text-[#6B5C3E]">
                  {p.soldCount?.last30d ?? 0}
                </td>
                <td className="px-4 py-3 font-mono text-xs text-[#6B5C3E]">
                  {String(p.storeId).slice(-8)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {nextCursor && (
        <div className="mt-4 flex justify-center">
          <button
            onClick={() => load(nextCursor)}
            disabled={loading}
            className="rounded-lg border border-gray-300 px-4 py-2 text-sm text-[#1A1200] hover:bg-gray-50 disabled:opacity-50"
          >
            {loading ? 'Đang tải...' : 'Tải thêm'}
          </button>
        </div>
      )}
    </div>
  )
}
