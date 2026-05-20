'use client'

import { useState, useEffect, useCallback } from 'react'
import { api } from '@/lib/api'

type SortCol = 'name' | 'price' | 'status' | 'stock' | 'soldAllTime' | 'sold30d' | 'storeName'

interface Product {
  _id: string
  storeId: string
  storeName?: string
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

function Th({
  label,
  col,
  sortCol,
  sortDir,
  onSort,
}: {
  label: string
  col: SortCol
  sortCol: SortCol | null
  sortDir: 'asc' | 'desc'
  onSort: (col: SortCol) => void
}) {
  const active = sortCol === col
  return (
    <th
      className="cursor-pointer select-none px-4 py-3 hover:bg-gray-100 transition-colors"
      onClick={() => onSort(col)}
    >
      <span className="flex items-center gap-1 whitespace-nowrap">
        {label}
        <span className="text-[10px] text-gray-400">
          {active ? (sortDir === 'asc' ? '▲' : '▼') : '⇅'}
        </span>
      </span>
    </th>
  )
}

export default function AdminProductsPage() {
  const [items, setItems]     = useState<Product[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch]   = useState('')
  const [status, setStatus]   = useState('')
  const [sortCol, setSortCol] = useState<SortCol | null>(null)
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc')
  const [nextCursor, setNextCursor] = useState<string | undefined>()

  // soldAllTime / sold30d là real-time từ orders nên sort client-side
  const isClientSort = sortCol === 'soldAllTime' || sortCol === 'sold30d'

  const load = useCallback(async (cursor?: string) => {
    setLoading(true)
    try {
      const params = new URLSearchParams({ limit: '50' })
      if (search) params.set('search', search)
      if (status) params.set('status', status)
      if (sortCol && !isClientSort) {
        params.set('sortBy', sortCol)
        params.set('sortDir', sortDir)
      }
      if (cursor && (!sortCol || isClientSort)) params.set('cursor', cursor)
      const res = await api.get<{ items: Product[]; nextCursor?: string }>(`/admin/products?${params}`)
      const fetched = res.items ?? []
      setItems(cursor ? (prev) => [...prev, ...fetched] : fetched)
      setNextCursor(res.nextCursor)
    } catch {
      setItems([])
    } finally {
      setLoading(false)
    }
  }, [search, status, sortCol, sortDir, isClientSort])

  useEffect(() => { load() }, [load])

  function handleSort(col: SortCol) {
    if (sortCol === col) {
      setSortDir((d) => (d === 'asc' ? 'desc' : 'asc'))
    } else {
      setSortCol(col)
      setSortDir('desc')
    }
    setNextCursor(undefined)
  }

  function clearSort() {
    setSortCol(null)
    setSortDir('desc')
    setNextCursor(undefined)
  }

  const displayItems = isClientSort
    ? [...items].sort((a, b) => {
        const va = sortCol === 'soldAllTime' ? (a.soldCount?.allTime ?? 0) : (a.soldCount?.last30d ?? 0)
        const vb = sortCol === 'soldAllTime' ? (b.soldCount?.allTime ?? 0) : (b.soldCount?.last30d ?? 0)
        return sortDir === 'asc' ? va - vb : vb - va
      })
    : items

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
        {sortCol && (
          <button
            onClick={clearSort}
            className="rounded-lg border border-gray-300 px-3 py-2 text-sm text-[#6B5C3E] hover:bg-gray-50"
          >
            Bỏ sắp xếp ✕
          </button>
        )}
      </div>

      <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white shadow-sm">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100 bg-gray-50 text-left text-xs font-semibold text-[#6B5C3E] uppercase">
              <Th label="Tên sản phẩm"   col="name"        sortCol={sortCol} sortDir={sortDir} onSort={handleSort} />
              <Th label="Giá"            col="price"       sortCol={sortCol} sortDir={sortDir} onSort={handleSort} />
              <Th label="Trạng thái"     col="status"      sortCol={sortCol} sortDir={sortDir} onSort={handleSort} />
              <Th label="Tồn kho"        col="stock"       sortCol={sortCol} sortDir={sortDir} onSort={handleSort} />
              <Th label="Đã bán (tổng)"  col="soldAllTime" sortCol={sortCol} sortDir={sortDir} onSort={handleSort} />
              <Th label="Đã bán (30 ngày)" col="sold30d"  sortCol={sortCol} sortDir={sortDir} onSort={handleSort} />
              <Th label="Quán"           col="storeName"   sortCol={sortCol} sortDir={sortDir} onSort={handleSort} />
            </tr>
          </thead>
          <tbody>
            {loading && items.length === 0 && (
              <tr><td colSpan={7} className="px-4 py-8 text-center text-[#6B5C3E]">Đang tải...</td></tr>
            )}
            {!loading && items.length === 0 && (
              <tr><td colSpan={7} className="px-4 py-8 text-center text-[#6B5C3E]">Không có dữ liệu.</td></tr>
            )}
            {displayItems.map((p) => (
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
                  {p.soldCount?.allTime ?? 0}
                </td>
                <td className="px-4 py-3 text-xs text-[#6B5C3E]">
                  {p.soldCount?.last30d ?? 0}
                </td>
                <td className="px-4 py-3 text-sm text-[#1A1200]">
                  {p.storeName ?? String(p.storeId).slice(-8)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {nextCursor && !sortCol && (
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
