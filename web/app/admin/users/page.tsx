'use client'

import { useState, useEffect, useCallback } from 'react'
import { api } from '@/lib/api'

type VipTier = 'none' | 'vip' | 'vvip' | 'vvvip'
type OptionalField = 'exp' | 'purchaseCount' | 'reviewCount' | 'storeRating'
type ToggleCol    = 'roles' | 'status' | 'actions'
type SortCol      = 'username' | 'roles' | 'vip' | 'status' | 'exp' | 'purchaseCount' | 'reviewCount' | 'storeRating'
type SortDir      = 'asc' | 'desc'

interface UserStats {
  orderStats:   { total: number; completed: number }
  reviewsGiven: number
  storeRating:  { avg: number; count: number } | null
}

interface User {
  _id: string
  username: string
  email?: string
  phone?: string
  roles: string[]
  isActive: boolean
  isSuspicious?: boolean
  vipTier?: VipTier
  exp?: number
  _stats?: UserStats
  createdAt: string
}

interface PageData {
  users: User[]
  // cursor mode
  nextCursor?: string
  // sort/page mode
  page?: number
  totalPages?: number
  totalCount?: number
}

const ROLE_RANK: Record<string, number> = { admin: 0, mod: 1, store_owner: 2, customer: 3 }
function topRole(roles: string[]) {
  return roles.reduce((best, r) => (ROLE_RANK[r] ?? 99) < (ROLE_RANK[best] ?? 99) ? r : best, roles[0] ?? '')
}

const OPTIONAL_FIELDS: { key: OptionalField; label: string }[] = [
  { key: 'exp',           label: 'Điểm EXP' },
  { key: 'purchaseCount', label: 'Số lần mua hàng' },
  { key: 'reviewCount',   label: 'Số lần đánh giá' },
  { key: 'storeRating',   label: 'Điểm chủ quán chấm' },
]

const TOGGLE_COLS: { key: ToggleCol; label: string }[] = [
  { key: 'roles',   label: 'Vai trò' },
  { key: 'status',  label: 'Trạng thái' },
  { key: 'actions', label: 'Thao tác' },
]

const STATS_FIELDS: OptionalField[] = ['purchaseCount', 'reviewCount', 'storeRating']

export default function AdminUsersPage() {
  const [visibleFields, setVisibleFields] = useState<Set<OptionalField>>(new Set())
  const [hiddenCols, setHiddenCols]       = useState<Set<ToggleCol>>(new Set())
  const [search, setSearch]   = useState('')
  const [filter, setFilter]   = useState<'all' | 'active' | 'suspended' | 'mod'>('all')
  const [data, setData]       = useState<PageData>({ users: [] })
  const [loading, setLoading] = useState(true)
  const [error, setError]     = useState('')
  const [modal, setModal]     = useState<{ type: 'reset'; user: User } | { type: 'delete'; user: User } | null>(null)
  const [tempPw, setTempPw]   = useState('')
  const [actionMsg, setActionMsg] = useState('')
  const [sortCol, setSortCol] = useState<SortCol | null>(null)
  const [sortDir, setSortDir] = useState<SortDir>('asc')
  // cursor mode (no sort)
  const [cursor, setCursor]           = useState<string | undefined>(undefined)
  const [prevCursors, setPrevCursors] = useState<string[]>([])
  // page mode (with sort)
  const [sortPage, setSortPage] = useState(1)

  const sortMode = sortCol !== null

  function toggleSort(col: SortCol) {
    if (sortCol === col) {
      setSortDir(d => d === 'asc' ? 'desc' : 'asc')
    } else {
      setSortCol(col)
      setSortDir('asc')
    }
    setSortPage(1)
    setCursor(undefined)
    setPrevCursors([])
  }

  const needsStats = STATS_FIELDS.some(f => visibleFields.has(f))

  const load = useCallback(async (opts: { cursor?: string; page?: number } = {}) => {
    setLoading(true)
    setError('')
    try {
      const params = new URLSearchParams({ limit: '20' })
      if (search) params.set('search', search)
      if (filter !== 'all') params.set('filter', filter)
      if (needsStats) params.set('stats', '1')

      if (sortCol) {
        params.set('sortBy', sortCol)
        params.set('sortDir', sortDir)
        params.set('page', String(opts.page ?? 1))
      } else {
        if (opts.cursor) params.set('cursor', opts.cursor)
      }

      const res = await api.get<PageData>(`/admin/users?${params}`)
      setData(res)
    } catch (e: any) {
      setData({ users: [] })
      setError(e?.message ?? 'Lỗi kết nối. Vui lòng thử lại.')
    } finally {
      setLoading(false)
    }
  }, [search, filter, needsStats, sortCol, sortDir])

  // Reload on search/filter/sort changes
  useEffect(() => {
    setCursor(undefined)
    setPrevCursors([])
    setSortPage(1)
    load({ page: 1 })
  }, [load])

  // ── Cursor-mode pagination ─────────────────────────────────────────────────
  function goNext() {
    if (sortMode) {
      const next = (data.page ?? 1) + 1
      setSortPage(next)
      load({ page: next })
    } else {
      if (!data.nextCursor) return
      const next = data.nextCursor
      setPrevCursors(prev => [...prev, cursor ?? ''])
      setCursor(next)
      load({ cursor: next })
    }
  }

  function goPrev() {
    if (sortMode) {
      const prev = Math.max((data.page ?? 1) - 1, 1)
      setSortPage(prev)
      load({ page: prev })
    } else {
      if (prevCursors.length === 0) return
      const last = prevCursors[prevCursors.length - 1]
      const prev = last === '' ? undefined : last
      setPrevCursors(s => s.slice(0, -1))
      setCursor(prev)
      load({ cursor: prev })
    }
  }

  const currentPage  = sortMode ? (data.page ?? 1) : prevCursors.length + 1
  const totalPages   = sortMode ? (data.totalPages ?? 1) : undefined
  const hasNext      = sortMode ? currentPage < (totalPages ?? 1) : !!data.nextCursor
  const hasPrev      = currentPage > 1

  function toggleField(field: OptionalField) {
    setVisibleFields(prev => {
      const next = new Set(prev)
      if (next.has(field)) next.delete(field)
      else next.add(field)
      return next
    })
  }

  function toggleCol(col: ToggleCol) {
    setHiddenCols(prev => {
      const next = new Set(prev)
      if (next.has(col)) next.delete(col)
      else next.add(col)
      return next
    })
  }

  function reloadCurrentPage() {
    if (sortMode) load({ page: currentPage })
    else load({ cursor })
  }

  async function toggleActive(user: User) {
    try {
      await api.patch(`/admin/users/${user._id}/suspend`, { suspend: user.isActive })
      setActionMsg(user.isActive ? 'Đã khoá tài khoản.' : 'Đã mở khoá tài khoản.')
      reloadCurrentPage()
    } catch (e: any) { setActionMsg(e?.message ?? 'Có lỗi xảy ra.') }
  }

  async function toggleMod(user: User) {
    const hasMod = user.roles.includes('mod')
    try {
      const body = hasMod ? { removeRoles: ['mod'] } : { addRoles: ['mod'] }
      await api.patch(`/admin/users/${user._id}/roles`, body)
      setActionMsg(hasMod ? 'Đã thu hồi quyền Mod.' : 'Đã gán quyền Mod.')
      reloadCurrentPage()
    } catch (e: any) { setActionMsg(e?.message ?? 'Có lỗi xảy ra.') }
  }

  async function resetPassword(user: User) {
    try {
      const res = await api.post<{ success: boolean; data: { newPassword: string } }>(`/admin/users/${user._id}/reset-password`, {})
      setTempPw(res.data.newPassword)
      setModal({ type: 'reset', user })
    } catch { setActionMsg('Có lỗi xảy ra.') }
  }

  async function updateVipTier(user: User, tier: string) {
    try {
      await api.patch(`/admin/users/${user._id}/vip-tier`, { tier })
      const label = tier === 'none' ? 'Thường' : tier.toUpperCase()
      setActionMsg(`Đã cập nhật VIP cho "${user.username}": ${label}.`)
      reloadCurrentPage()
    } catch (e: any) { setActionMsg(e?.message ?? 'Có lỗi xảy ra.') }
  }

  async function confirmDelete() {
    if (modal?.type !== 'delete') return
    try {
      await api.delete(`/admin/users/${modal.user._id}`)
      setActionMsg(`Đã xóa người dùng "${modal.user.username}".`)
      setModal(null)
      reloadCurrentPage()
    } catch (e: any) {
      setModal(null)
      setActionMsg(e?.message ?? 'Có lỗi xảy ra khi xóa.')
    }
  }

  const showRoles   = !hiddenCols.has('roles')
  const showStatus  = !hiddenCols.has('status')
  const showActions = !hiddenCols.has('actions')

  const totalCols =
    2
    + (showRoles   ? 1 : 0)
    + visibleFields.size
    + (showStatus  ? 1 : 0)
    + (showActions ? 1 : 0)

  return (
    <div className="p-6">
      <h1 className="mb-6 text-xl font-bold text-[#1A1200]">Quản lý người dùng</h1>

      {actionMsg && (
        <div className="mb-4 rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm text-green-800">
          {actionMsg} <button className="ml-2 underline" onClick={() => setActionMsg('')}>Đóng</button>
        </div>
      )}

      {error && (
        <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error} <button className="ml-2 underline" onClick={reloadCurrentPage}>Thử lại</button>
        </div>
      )}

      {/* Column selector */}
      <div className="mb-4 rounded-xl border border-gray-200 bg-gray-50 px-4 py-3 space-y-2">
        <div className="flex flex-wrap items-center gap-x-5 gap-y-1.5">
          <span className="text-xs font-semibold uppercase text-[#6B5C3E] w-24 shrink-0">Thêm cột:</span>
          {OPTIONAL_FIELDS.map(({ key, label }) => (
            <label key={key} className="flex cursor-pointer items-center gap-1.5 select-none">
              <input
                type="checkbox"
                checked={visibleFields.has(key)}
                onChange={() => toggleField(key)}
                className="h-4 w-4 accent-[#1D7A4E]"
              />
              <span className="text-sm text-[#1A1200]">{label}</span>
            </label>
          ))}
        </div>
        <div className="flex flex-wrap items-center gap-x-5 gap-y-1.5">
          <span className="text-xs font-semibold uppercase text-[#6B5C3E] w-24 shrink-0">Ẩn cột:</span>
          {TOGGLE_COLS.map(({ key, label }) => (
            <label key={key} className="flex cursor-pointer items-center gap-1.5 select-none">
              <input
                type="checkbox"
                checked={hiddenCols.has(key)}
                onChange={() => toggleCol(key)}
                className="h-4 w-4 accent-[#6B5C3E]"
              />
              <span className="text-sm text-[#1A1200]">{label}</span>
            </label>
          ))}
        </div>
      </div>

      {/* Toolbar */}
      <div className="mb-4 flex flex-wrap gap-3">
        <input
          type="text"
          placeholder="Tìm username, email, SĐT..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-64 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-[#1D7A4E] focus:outline-none"
        />
        <select
          value={filter}
          onChange={(e) => setFilter(e.target.value as typeof filter)}
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-[#1D7A4E] focus:outline-none"
        >
          <option value="all">Tất cả</option>
          <option value="active">Đang hoạt động</option>
          <option value="suspended">Đã khoá</option>
          <option value="mod">Mod</option>
        </select>
        {sortCol && (
          <button
            onClick={() => { setSortCol(null); setSortPage(1); setCursor(undefined); setPrevCursors([]) }}
            className="rounded-lg border border-gray-200 px-3 py-2 text-sm text-[#6B5C3E] hover:bg-gray-50"
          >
            ✕ Bỏ sort
          </button>
        )}
      </div>

      {/* Table */}
      <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white shadow-sm">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100 bg-gray-50 text-left text-xs font-semibold uppercase text-[#6B5C3E]">
              <Th col="username" label="Người dùng" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
              {showRoles   && <Th col="roles"   label="Vai trò"    sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />}
              {visibleFields.has('exp')           && <Th col="exp"           label="Điểm EXP"     sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />}
              {visibleFields.has('purchaseCount') && <Th col="purchaseCount" label="Mua hàng"      sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />}
              {visibleFields.has('reviewCount')   && <Th col="reviewCount"   label="Đánh giá"      sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />}
              {visibleFields.has('storeRating')   && <Th col="storeRating"   label="Chủ quán chấm" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />}
              <Th col="vip" label="VIP" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />
              {showStatus  && <Th col="status"  label="Trạng thái" sortCol={sortCol} sortDir={sortDir} onSort={toggleSort} />}
              {showActions && <th className="px-4 py-3">Thao tác</th>}
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr><td colSpan={totalCols} className="px-4 py-8 text-center text-[#6B5C3E]">Đang tải...</td></tr>
            )}
            {!loading && data.users.length === 0 && (
              <tr><td colSpan={totalCols} className="px-4 py-8 text-center text-[#6B5C3E]">Không tìm thấy user nào.</td></tr>
            )}
            {data.users.map((u) => (
              <tr key={u._id} className="border-b border-gray-50 hover:bg-gray-50">
                <td className="px-4 py-3">
                  <div className={`font-medium ${
                    u.roles.includes('admin') ? 'text-red-600' :
                    u.roles.includes('mod')   ? 'text-purple-700' :
                    'text-[#1A1200]'
                  }`}>{u.username}</div>
                  <div className="text-xs text-[#6B5C3E]">{u.email ?? u.phone ?? '—'}</div>
                </td>
                {showRoles && (
                  <td className="px-4 py-3">
                    <div className="flex flex-wrap gap-1">
                      {u.roles.map((r) => (
                        <span key={r} className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                          r === 'admin'       ? 'bg-red-100 text-red-700' :
                          r === 'mod'         ? 'bg-purple-100 text-purple-700' :
                          r === 'store_owner' ? 'bg-blue-100 text-blue-700' :
                          'bg-gray-100 text-gray-600'
                        }`}>{r}</span>
                      ))}
                    </div>
                  </td>
                )}
                {visibleFields.has('exp') && (
                  <td className="px-4 py-3 font-medium text-[#1D7A4E]">{u.exp ?? 0}</td>
                )}
                {visibleFields.has('purchaseCount') && (
                  <td className="px-4 py-3 text-[#1A1200]">
                    {u._stats
                      ? <span>{u._stats.orderStats.completed}<span className="text-xs text-[#6B5C3E]">/{u._stats.orderStats.total}</span></span>
                      : <span className="text-gray-300">—</span>}
                  </td>
                )}
                {visibleFields.has('reviewCount') && (
                  <td className="px-4 py-3 text-[#1A1200]">
                    {u._stats ? u._stats.reviewsGiven : <span className="text-gray-300">—</span>}
                  </td>
                )}
                {visibleFields.has('storeRating') && (
                  <td className="px-4 py-3">
                    {u._stats?.storeRating
                      ? <span className="font-medium text-amber-700">{u._stats.storeRating.avg}<span className="text-xs text-[#6B5C3E] font-normal"> ({u._stats.storeRating.count})</span></span>
                      : <span className="text-gray-300">—</span>}
                  </td>
                )}
                <td className="px-4 py-3">
                  <select
                    value={u.vipTier ?? 'none'}
                    onChange={(e) => updateVipTier(u, e.target.value)}
                    className={`rounded-lg border px-2 py-1 text-xs focus:outline-none ${
                      u.vipTier === 'vip'   ? 'border-amber-300 bg-amber-50 text-amber-800 font-semibold' :
                      u.vipTier === 'vvip'  ? 'border-gray-300 bg-gray-100 text-gray-700 font-semibold' :
                      u.vipTier === 'vvvip' ? 'border-purple-300 bg-purple-50 text-purple-800 font-semibold' :
                      'border-gray-200 text-gray-500'
                    }`}
                  >
                    <option value="none">Thường</option>
                    <option value="vip">VIP</option>
                    <option value="vvip">VVIP</option>
                    <option value="vvvip">VVVIP</option>
                  </select>
                </td>
                {showStatus && (
                  <td className="px-4 py-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                      u.isActive ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
                    }`}>
                      {u.isActive ? 'Hoạt động' : 'Bị khoá'}
                    </span>
                  </td>
                )}
                {showActions && (
                  <td className="px-4 py-3">
                    <div className="flex flex-wrap gap-2">
                      <button
                        onClick={() => toggleActive(u)}
                        className="rounded-lg border border-gray-200 px-2 py-1 text-xs hover:bg-gray-100"
                      >
                        {u.isActive ? 'Khoá' : 'Mở khoá'}
                      </button>
                      {!u.roles.includes('admin') && (
                        <button
                          onClick={() => toggleMod(u)}
                          className="rounded-lg border border-purple-200 px-2 py-1 text-xs text-purple-700 hover:bg-purple-50"
                        >
                          {u.roles.includes('mod') ? 'Thu hồi Mod' : 'Gán Mod'}
                        </button>
                      )}
                      <button
                        onClick={() => resetPassword(u)}
                        className="rounded-lg border border-amber-200 px-2 py-1 text-xs text-amber-700 hover:bg-amber-50"
                      >
                        Reset mật khẩu
                      </button>
                      {!u.roles.includes('admin') && (
                        <button
                          onClick={() => setModal({ type: 'delete', user: u })}
                          className="rounded-lg border border-red-200 px-2 py-1 text-xs text-red-700 hover:bg-red-50"
                        >
                          Xóa
                        </button>
                      )}
                    </div>
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      <div className="mt-4 flex items-center justify-between">
        <span className="text-sm text-[#6B5C3E]">
          Trang {currentPage}{totalPages ? `/${totalPages}` : ''}
          {data.totalCount != null && <span className="ml-2 text-xs">({data.totalCount} user)</span>}
        </span>
        <div className="flex gap-2">
          <button
            onClick={goPrev}
            disabled={!hasPrev || loading}
            className="rounded-lg border border-gray-200 px-3 py-1.5 text-sm text-[#1A1200] hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed"
          >
            ← Trước
          </button>
          <button
            onClick={goNext}
            disabled={!hasNext || loading}
            className="rounded-lg border border-gray-200 px-3 py-1.5 text-sm text-[#1A1200] hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed"
          >
            Tiếp →
          </button>
        </div>
      </div>

      {/* Reset password modal */}
      {modal?.type === 'reset' && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="mb-2 text-base font-bold text-[#1A1200]">Mật khẩu tạm — {modal.user.username}</h2>
            <p className="mb-4 text-sm text-[#6B5C3E]">Sao chép và gửi cho người dùng qua Zalo/email. Mật khẩu này chỉ hiển thị một lần.</p>
            <div className="mb-4 flex items-center gap-2 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3">
              <code className="flex-1 text-base font-bold text-[#1A1200]">{tempPw}</code>
              <button onClick={() => navigator.clipboard.writeText(tempPw)} className="text-xs text-[#1D7A4E] underline">Copy</button>
            </div>
            <button
              onClick={() => { setModal(null); setTempPw('') }}
              className="w-full rounded-lg bg-[#1D7A4E] py-2.5 text-sm font-semibold text-white hover:bg-[#165f3c]"
            >
              Đã gửi cho người dùng
            </button>
          </div>
        </div>
      )}

      {/* Delete confirm modal */}
      {modal?.type === 'delete' && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="mb-2 text-base font-bold text-[#1A1200]">Xóa người dùng</h2>
            <p className="mb-4 text-sm text-[#6B5C3E]">
              Bạn có chắc muốn xóa tài khoản <span className="font-semibold text-[#1A1200]">"{modal.user.username}"</span>? Hành động này không thể hoàn tác.
            </p>
            <div className="flex gap-3">
              <button onClick={() => setModal(null)} className="flex-1 rounded-lg border border-gray-200 py-2 text-sm">Huỷ</button>
              <button onClick={confirmDelete} className="flex-1 rounded-lg bg-red-600 py-2 text-sm font-semibold text-white hover:bg-red-700">Xóa</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function Th({ col, label, sortCol, sortDir, onSort }: {
  col: SortCol; label: string
  sortCol: SortCol | null; sortDir: SortDir
  onSort: (col: SortCol) => void
}) {
  const active = sortCol === col
  return (
    <th className="cursor-pointer select-none px-4 py-3 hover:text-[#1A1200]" onClick={() => onSort(col)}>
      <span className="inline-flex items-center gap-1">
        {label}
        <span className="text-[10px] leading-none">{active ? (sortDir === 'asc' ? '▲' : '▼') : '⇅'}</span>
      </span>
    </th>
  )
}
