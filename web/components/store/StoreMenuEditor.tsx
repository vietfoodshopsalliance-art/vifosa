'use client'

import { useState, useEffect, useCallback } from 'react'
import { api } from '@/lib/api'

interface Category {
  _id: string
  name: string
  displayOrder: number
}

interface MenuItem {
  _id: string
  categoryId: string
  name: string
  description?: string
  price: number
  status: 'active' | 'closed' | 'paused'
  stock?: number
  images?: string[]
  isDeleted?: boolean
}

interface StoreMenuEditorProps {
  storeId: string
  isAdminMode?: boolean
}

const STATUS_LABEL = { active: 'Đang bán', closed: 'Đóng', paused: 'Tạm dừng' }
const STATUS_COLOR = {
  active: 'bg-green-100 text-green-700',
  closed: 'bg-red-100 text-red-700',
  paused: 'bg-amber-100 text-amber-700',
}

const EMPTY_ITEM = { name: '', description: '', price: 0, status: 'active' as const, stock: undefined as number | undefined }

export default function StoreMenuEditor({ storeId, isAdminMode = false }: StoreMenuEditorProps) {
  const [categories, setCategories] = useState<Category[]>([])
  const [items, setItems]           = useState<MenuItem[]>([])
  const [activeCat, setActiveCat]   = useState<string | null>(null)
  const [loading, setLoading]       = useState(true)
  const [catModal, setCatModal]     = useState<Partial<Category> | null>(null)
  const [itemModal, setItemModal]   = useState<Partial<MenuItem> | null>(null)
  const [actionMsg, setActionMsg]   = useState('')

  const adminHeaders = isAdminMode ? { 'X-Admin-Override': 'true' } : undefined

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const res = await api.get<{ categories: Array<Category & { items: MenuItem[] }> }>(`/stores/${storeId}/menu`)
      const cats: Category[] = []
      const allItems: MenuItem[] = []
      for (const cat of res.categories) {
        const { items, ...catData } = cat as any
        cats.push(catData)
        allItems.push(...(items ?? []))
      }
      setCategories(cats)
      setItems(allItems)
      if (!activeCat && cats.length > 0) setActiveCat(cats[0]._id)
    } catch {}
    finally { setLoading(false) }
  }, [storeId, activeCat])

  useEffect(() => { load() }, [storeId])

  async function saveCategory() {
    if (!catModal?.name?.trim()) return
    try {
      if (catModal._id) {
        await api.patch(`/stores/${storeId}/categories/${catModal._id}`, { name: catModal.name }, adminHeaders)
      } else {
        await api.post(`/stores/${storeId}/categories`, { name: catModal.name, displayOrder: categories.length }, adminHeaders)
      }
      setCatModal(null)
      load()
    } catch { setActionMsg('Lưu danh mục thất bại.') }
  }

  async function deleteCategory(id: string) {
    if (!confirm('Xoá danh mục này?')) return
    try {
      await api.delete(`/stores/${storeId}/categories/${id}`, adminHeaders)
      load()
    } catch { setActionMsg('Xoá thất bại.') }
  }

  async function saveItem() {
    if (!itemModal?.name?.trim() || !itemModal.price) return
    try {
      const body = { ...itemModal, categoryId: activeCat }
      if (itemModal._id) {
        await api.patch(`/stores/${storeId}/items/${itemModal._id}`, body, adminHeaders)
      } else {
        await api.post(`/stores/${storeId}/items`, body, adminHeaders)
      }
      setItemModal(null)
      load()
    } catch { setActionMsg('Lưu món thất bại.') }
  }

  async function softDeleteItem(id: string) {
    if (!confirm('Xoá món này?')) return
    try {
      await api.delete(`/stores/${storeId}/items/${id}`, adminHeaders)
      load()
    } catch { setActionMsg('Xoá thất bại.') }
  }

  const catItems = items.filter((i) => i.categoryId === activeCat)

  if (loading) return <div className="p-6 text-[#6B5C3E]">Đang tải menu...</div>

  return (
    <div className="flex h-full min-h-0 flex-col p-6">
      {actionMsg && (
        <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-2 text-sm text-red-700">
          {actionMsg} <button className="ml-2 underline" onClick={() => setActionMsg('')}>Đóng</button>
        </div>
      )}

      <div className="flex flex-1 gap-4 overflow-hidden">
        {/* Category sidebar */}
        <div className="w-48 shrink-0">
          <div className="mb-2 flex items-center justify-between">
            <p className="text-xs font-semibold text-[#6B5C3E] uppercase">Danh mục</p>
            <button onClick={() => setCatModal({})} className="text-xs text-[#1D7A4E] underline">+ Thêm</button>
          </div>
          <div className="space-y-1">
            {categories.map((c) => (
              <div
                key={c._id}
                className={`flex items-center gap-1 rounded-lg px-3 py-2 text-sm cursor-pointer transition-colors ${
                  activeCat === c._id ? 'bg-[#F5C842]/20 font-semibold text-[#3D2800]' : 'hover:bg-gray-100 text-[#1A1200]'
                }`}
                onClick={() => setActiveCat(c._id)}
              >
                <span className="flex-1 truncate">{c.name}</span>
                <button onClick={(e) => { e.stopPropagation(); setCatModal(c) }} className="text-xs text-gray-400 hover:text-gray-600">✏️</button>
                <button onClick={(e) => { e.stopPropagation(); deleteCategory(c._id) }} className="text-xs text-gray-400 hover:text-red-500">🗑</button>
              </div>
            ))}
            {categories.length === 0 && <p className="text-xs text-[#6B5C3E]">Chưa có danh mục.</p>}
          </div>
        </div>

        {/* Items */}
        <div className="flex-1 overflow-y-auto">
          <div className="mb-3 flex items-center justify-between">
            <p className="text-sm font-semibold text-[#1A1200]">
              {categories.find((c) => c._id === activeCat)?.name ?? 'Chọn danh mục'}
            </p>
            {activeCat && (
              <button
                onClick={() => setItemModal({ ...EMPTY_ITEM })}
                className="rounded-lg bg-[#F5C842] px-3 py-1.5 text-xs font-semibold text-[#3D2800] hover:bg-[#D4A820]"
              >
                + Thêm món
              </button>
            )}
          </div>

          <div className="space-y-2">
            {catItems.length === 0 && <p className="text-sm text-[#6B5C3E]">Chưa có món trong danh mục này.</p>}
            {catItems.map((item) => (
              <div key={item._id} className="flex items-center gap-3 rounded-xl border border-gray-200 bg-white p-3 shadow-sm">
                {item.images?.[0] && (
                  <img src={item.images[0]} alt={item.name} className="h-12 w-12 rounded-lg object-cover" />
                )}
                <div className="flex-1 min-w-0">
                  <p className="font-medium text-[#1A1200]">{item.name}</p>
                  <p className="text-xs text-[#6B5C3E]">{item.price.toLocaleString('vi-VN')}đ{item.stock !== undefined ? ` · Tồn: ${item.stock}` : ''}</p>
                </div>
                <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${STATUS_COLOR[item.status]}`}>
                  {STATUS_LABEL[item.status]}
                </span>
                <button onClick={() => setItemModal(item)} className="text-xs text-gray-400 hover:text-gray-600">✏️</button>
                <button onClick={() => softDeleteItem(item._id)} className="text-xs text-gray-400 hover:text-red-500">🗑</button>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Category modal */}
      {catModal !== null && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="mb-4 text-base font-bold text-[#1A1200]">{catModal._id ? 'Sửa danh mục' : 'Thêm danh mục'}</h2>
            <input
              type="text"
              value={catModal.name ?? ''}
              onChange={(e) => setCatModal({ ...catModal, name: e.target.value })}
              placeholder="Tên danh mục"
              className="mb-4 w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none"
            />
            <div className="flex gap-3">
              <button onClick={() => setCatModal(null)} className="flex-1 rounded-lg border border-gray-200 py-2 text-sm">Huỷ</button>
              <button onClick={saveCategory} className="flex-1 rounded-lg bg-[#F5C842] py-2 text-sm font-semibold text-[#3D2800]">Lưu</button>
            </div>
          </div>
        </div>
      )}

      {/* Item modal */}
      {itemModal !== null && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="mb-4 text-base font-bold text-[#1A1200]">{itemModal._id ? 'Sửa món' : 'Thêm món'}</h2>
            <div className="space-y-3">
              <input type="text" placeholder="Tên món *" value={itemModal.name ?? ''} onChange={(e) => setItemModal({ ...itemModal, name: e.target.value })}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none" />
              <textarea placeholder="Mô tả" value={itemModal.description ?? ''} onChange={(e) => setItemModal({ ...itemModal, description: e.target.value })}
                rows={2} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none" />
              <div className="flex gap-3">
                <div className="flex-1">
                  <label className="mb-1 block text-xs text-[#6B5C3E]">Giá (VNĐ) *</label>
                  <input type="number" value={itemModal.price ?? 0} onChange={(e) => setItemModal({ ...itemModal, price: parseInt(e.target.value) })}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none" />
                </div>
                <div className="flex-1">
                  <label className="mb-1 block text-xs text-[#6B5C3E]">Tồn kho (trống = không quản lý)</label>
                  <input type="number" value={itemModal.stock ?? ''} onChange={(e) => setItemModal({ ...itemModal, stock: e.target.value ? parseInt(e.target.value) : undefined })}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none" min={0} />
                </div>
              </div>
              <div>
                <label className="mb-1 block text-xs text-[#6B5C3E]">Trạng thái</label>
                <select value={itemModal.status ?? 'active'} onChange={(e) => setItemModal({ ...itemModal, status: e.target.value as MenuItem['status'] })}
                  className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none">
                  <option value="active">Đang bán</option>
                  <option value="paused">Tạm dừng</option>
                  <option value="closed">Đóng</option>
                </select>
              </div>
            </div>
            <div className="mt-4 flex gap-3">
              <button onClick={() => setItemModal(null)} className="flex-1 rounded-lg border border-gray-200 py-2 text-sm">Huỷ</button>
              <button onClick={saveItem} className="flex-1 rounded-lg bg-[#F5C842] py-2 text-sm font-semibold text-[#3D2800]">Lưu</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
