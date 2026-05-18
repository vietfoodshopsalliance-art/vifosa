'use client'

import { useState, useEffect, useCallback } from 'react'
import Link from 'next/link'
import { api } from '@/lib/api'

interface Store {
  _id: string
  name: string
  ownerUsername: string
  isActive: boolean
  isSuspended: boolean
  isAdLockedByAdmin: boolean
  menuLocked?: boolean
  ordersThisMonth: number
  rating: number
  vipTier?: string
}

interface PageData {
  stores: Store[]
  nextCursor?: string
}

type Filter = 'all' | 'active' | 'suspended' | 'locked' | 'vip'

export default function AdminStoresPage() {
  const [filter, setFilter]       = useState<Filter>('all')
  const [search, setSearch]       = useState('')
  const [data, setData]           = useState<PageData>({ stores: [] })
  const [loading, setLoading]     = useState(true)
  const [selected, setSelected]   = useState<Set<string>>(new Set())
  const [actionMsg, setActionMsg] = useState('')
  const [transferModal, setTransferModal] = useState<Store | null>(null)
  const [newOwner, setNewOwner]   = useState('')
  const [deleteTarget, setDeleteTarget] = useState<Store | null>(null)
  const [deleteError, setDeleteError]   = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const params = new URLSearchParams({ limit: '20' })
      if (search) params.set('search', search)
      if (filter !== 'all') params.set('filter', filter)
      const res = await api.get<PageData>(`/admin/stores?${params}`)
      setData(res)
    } catch {
      setData({ stores: [] })
    } finally {
      setLoading(false)
    }
  }, [search, filter])

  useEffect(() => { load() }, [load])

  function toggleSelect(id: string) {
    setSelected((prev) => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  async function bulkAction(action: string) {
    const ids = [...selected]
    if (!ids.length) return
    try {
      await api.post(`/admin/stores/bulk`, { ids, action })
      setActionMsg(`Đã thực hiện: ${action} (${ids.length} quán).`)
      setSelected(new Set())
      load()
    } catch { setActionMsg('Có lỗi xảy ra.') }
  }

  async function deleteStore() {
    if (!deleteTarget) return
    setDeleteError('')
    try {
      await api.post(`/admin/stores/bulk`, { ids: [deleteTarget._id], action: 'delete' })
      setActionMsg(`Đã xoá quán "${deleteTarget.name}".`)
      setDeleteTarget(null)
      load()
    } catch (e: any) { setDeleteError(e?.message ?? 'Có lỗi xảy ra.') }
  }

  async function transfer() {
    if (!transferModal || !newOwner.trim()) return
    try {
      await api.post(`/admin/stores/${transferModal._id}/transfer`, { username: newOwner.trim() })
      setActionMsg(`Đã chuyển nhượng quán ${transferModal.name} cho ${newOwner}.`)
      setTransferModal(null)
      setNewOwner('')
      load()
    } catch { setActionMsg('Có lỗi xảy ra.') }
  }

  return (
    <div className="p-6">
      <h1 className="mb-6 text-xl font-bold text-[#1A1200]">Quản lý quán</h1>

      {actionMsg && (
        <div className="mb-4 rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm text-green-800">
          {actionMsg} <button className="ml-2 underline" onClick={() => setActionMsg('')}>Đóng</button>
        </div>
      )}

      {/* Toolbar */}
      <div className="mb-4 flex flex-wrap gap-3">
        <input
          type="text"
          placeholder="Tìm tên quán, owner..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-64 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-[#1D7A4E] focus:outline-none"
        />
        <select
          value={filter}
          onChange={(e) => setFilter(e.target.value as Filter)}
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none"
        >
          <option value="all">Tất cả</option>
          <option value="active">Đang hoạt động</option>
          <option value="suspended">Bị khoá</option>
          <option value="locked">Khoá đăng tin</option>
          <option value="vip">VIP</option>
        </select>
        {selected.size > 0 && (
          <div className="flex gap-2">
            <button onClick={() => bulkAction('lock_ad')} className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-1.5 text-xs font-medium text-amber-800 hover:bg-amber-100">Tắt đăng tin</button>
            <button onClick={() => bulkAction('unlock_ad')} className="rounded-lg border border-green-200 bg-green-50 px-3 py-1.5 text-xs font-medium text-green-800 hover:bg-green-100">Mở đăng tin</button>
            <button onClick={() => bulkAction('suspend')} className="rounded-lg border border-red-200 bg-red-50 px-3 py-1.5 text-xs font-medium text-red-800 hover:bg-red-100">Khoá bán hàng</button>
            <button
              onClick={() => { if (confirm(`Xoá ${selected.size} quán đã chọn? Không thể hoàn tác.`)) bulkAction('delete') }}
              className="rounded-lg border border-red-300 bg-red-100 px-3 py-1.5 text-xs font-bold text-red-900 hover:bg-red-200"
            >
              Xoá quán
            </button>
          </div>
        )}
      </div>

      {/* Table */}
      <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white shadow-sm">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100 bg-gray-50 text-left text-xs font-semibold text-[#6B5C3E] uppercase">
              <th className="px-3 py-3"><input type="checkbox" onChange={(e) => {
                if (e.target.checked) setSelected(new Set(data.stores.map(s => s._id)))
                else setSelected(new Set())
              }} /></th>
              <th className="px-4 py-3">Quán</th>
              <th className="px-4 py-3">Owner</th>
              <th className="px-4 py-3">Đơn/tháng</th>
              <th className="px-4 py-3">Rating</th>
              <th className="px-4 py-3">Trạng thái</th>
              <th className="px-4 py-3">Thao tác</th>
            </tr>
          </thead>
          <tbody>
            {loading && <tr><td colSpan={7} className="px-4 py-8 text-center text-[#6B5C3E]">Đang tải...</td></tr>}
            {!loading && data.stores.length === 0 && <tr><td colSpan={7} className="px-4 py-8 text-center text-[#6B5C3E]">Không tìm thấy quán nào.</td></tr>}
            {data.stores.map((s) => (
              <tr key={s._id} className="border-b border-gray-50 hover:bg-gray-50">
                <td className="px-3 py-3">
                  <input type="checkbox" checked={selected.has(s._id)} onChange={() => toggleSelect(s._id)} />
                </td>
                <td className="px-4 py-3 font-medium text-[#1A1200]">{s.name}</td>
                <td className="px-4 py-3 text-[#6B5C3E]">{s.ownerUsername}</td>
                <td className="px-4 py-3">{s.ordersThisMonth}</td>
                <td className="px-4 py-3">{s.rating?.toFixed(1) ?? '—'}</td>
                <td className="px-4 py-3">
                  <div className="flex flex-wrap gap-1">
                    {s.isSuspended && <Badge color="red">Khoá</Badge>}
                    {s.isAdLockedByAdmin && <Badge color="amber">Tắt đăng tin</Badge>}
                    {!s.isSuspended && !s.isAdLockedByAdmin && <Badge color="green">Hoạt động</Badge>}
                  </div>
                </td>
                <td className="px-4 py-3">
                  <div className="flex gap-2">
                    <Link
                      href={`/admin/stores/${s._id}/menu`}
                      className="rounded-lg border border-blue-200 px-2 py-1 text-xs text-blue-700 hover:bg-blue-50"
                    >
                      Quản lý quán
                    </Link>
                    <button
                      onClick={() => setTransferModal(s)}
                      className="rounded-lg border border-gray-200 px-2 py-1 text-xs hover:bg-gray-100"
                    >
                      Chuyển nhượng
                    </button>
                    <button
                      onClick={() => setDeleteTarget(s)}
                      className="rounded-lg border border-red-200 px-2 py-1 text-xs text-red-700 hover:bg-red-50"
                    >
                      Xoá
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Delete confirm modal */}
      {deleteTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="mb-2 text-base font-bold text-[#1A1200]">Xoá quán: {deleteTarget.name}</h2>
            <p className="mb-4 text-sm text-[#6B5C3E]">
              Quán sẽ bị ẩn hoàn toàn khỏi hệ thống. Hành động này không thể hoàn tác.
            </p>
            {deleteError && (
              <p className="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{deleteError}</p>
            )}
            <div className="flex gap-3">
              <button
                onClick={() => { setDeleteTarget(null); setDeleteError('') }}
                className="flex-1 rounded-lg border border-gray-200 py-2 text-sm"
              >
                Huỷ
              </button>
              <button
                onClick={deleteStore}
                className="flex-1 rounded-lg bg-red-600 py-2 text-sm font-semibold text-white hover:bg-red-700"
              >
                Xác nhận xoá
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Transfer modal */}
      {transferModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="mb-2 text-base font-bold text-[#1A1200]">Chuyển nhượng: {transferModal.name}</h2>
            <p className="mb-4 text-sm text-[#6B5C3E]">Nhập username chủ mới:</p>
            <input
              type="text"
              value={newOwner}
              onChange={(e) => setNewOwner(e.target.value)}
              className="mb-4 w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-[#1D7A4E] focus:outline-none"
              placeholder="username"
            />
            <div className="flex gap-3">
              <button
                onClick={() => { setTransferModal(null); setNewOwner('') }}
                className="flex-1 rounded-lg border border-gray-200 py-2 text-sm"
              >
                Huỷ
              </button>
              <button
                onClick={transfer}
                disabled={!newOwner.trim()}
                className="flex-1 rounded-lg bg-[#F5C842] py-2 text-sm font-semibold text-[#3D2800] disabled:opacity-50"
              >
                Xác nhận
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function Badge({ color, children }: { color: 'red' | 'green' | 'amber'; children: React.ReactNode }) {
  const cls = {
    red:   'bg-red-100 text-red-700',
    green: 'bg-green-100 text-green-700',
    amber: 'bg-amber-100 text-amber-700',
  }[color]
  return <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${cls}`}>{children}</span>
}
