'use client'

import { useState, useEffect, useCallback } from 'react'
import { api, ApiError } from '@/lib/api'

interface User {
  _id: string
  username: string
  email?: string
  phone?: string
  roles: string[]
  isActive: boolean
  isSuspicious?: boolean
  createdAt: string
}

interface PageData {
  users: User[]
  nextCursor?: string
}

export default function AdminUsersPage() {
  const [search, setSearch]   = useState('')
  const [filter, setFilter]   = useState<'all' | 'active' | 'suspended' | 'mod'>('all')
  const [data, setData]       = useState<PageData>({ users: [] })
  const [loading, setLoading] = useState(true)
  const [error, setError]     = useState('')
  const [modal, setModal]     = useState<{ type: 'reset'; user: User } | null>(null)
  const [tempPw, setTempPw]   = useState('')
  const [actionMsg, setActionMsg] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const params = new URLSearchParams({ limit: '20' })
      if (search) params.set('search', search)
      if (filter !== 'all') params.set('filter', filter)
      const res = await api.get<PageData>(`/admin/users?${params}`)
      setData(res)
    } catch (e: any) {
      setData({ users: [] })
      setError(e?.message ?? 'Lỗi kết nối. Vui lòng thử lại.')
    } finally {
      setLoading(false)
    }
  }, [search, filter])

  useEffect(() => { load() }, [load])

  async function toggleActive(user: User) {
    try {
      await api.patch(`/admin/users/${user._id}/suspend`, { suspend: user.isActive })
      setActionMsg(user.isActive ? 'Đã khoá tài khoản.' : 'Đã mở khoá tài khoản.')
      load()
    } catch (e: any) { setActionMsg(e?.message ?? 'Có lỗi xảy ra.') }
  }

  async function toggleMod(user: User) {
    const hasMod = user.roles.includes('mod')
    try {
      const body = hasMod ? { removeRoles: ['mod'] } : { addRoles: ['mod'] }
      await api.patch(`/admin/users/${user._id}/roles`, body)
      setActionMsg(hasMod ? 'Đã thu hồi quyền Mod.' : 'Đã gán quyền Mod.')
      load()
    } catch (e: any) { setActionMsg(e?.message ?? 'Có lỗi xảy ra.') }
  }

  async function resetPassword(user: User) {
    try {
      const res = await api.post<{ tempPassword: string }>(`/admin/users/${user._id}/reset-password`, {})
      setTempPw(res.tempPassword)
      setModal({ type: 'reset', user })
    } catch { setActionMsg('Có lỗi xảy ra.') }
  }

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
          {error} <button className="ml-2 underline" onClick={load}>Thử lại</button>
        </div>
      )}

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
      </div>

      {/* Table */}
      <div className="overflow-x-auto rounded-xl border border-gray-200 bg-white shadow-sm">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-gray-100 bg-gray-50 text-left text-xs font-semibold text-[#6B5C3E] uppercase">
              <th className="px-4 py-3">Người dùng</th>
              <th className="px-4 py-3">Vai trò</th>
              <th className="px-4 py-3">Trạng thái</th>
              <th className="px-4 py-3">Thao tác</th>
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr><td colSpan={4} className="px-4 py-8 text-center text-[#6B5C3E]">Đang tải...</td></tr>
            )}
            {!loading && data.users.length === 0 && (
              <tr><td colSpan={4} className="px-4 py-8 text-center text-[#6B5C3E]">Không tìm thấy user nào.</td></tr>
            )}
            {data.users.map((u) => (
              <tr key={u._id} className="border-b border-gray-50 hover:bg-gray-50">
                <td className="px-4 py-3">
                  <div className="font-medium text-[#1A1200]">{u.username}</div>
                  <div className="text-xs text-[#6B5C3E]">{u.email ?? u.phone ?? '—'}</div>
                </td>
                <td className="px-4 py-3">
                  <div className="flex flex-wrap gap-1">
                    {u.roles.map((r) => (
                      <span key={r} className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                        r === 'admin' ? 'bg-red-100 text-red-700' :
                        r === 'mod'   ? 'bg-purple-100 text-purple-700' :
                        'bg-gray-100 text-gray-600'
                      }`}>{r}</span>
                    ))}
                  </div>
                </td>
                <td className="px-4 py-3">
                  <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${
                    u.isActive ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
                  }`}>
                    {u.isActive ? 'Hoạt động' : 'Bị khoá'}
                  </span>
                </td>
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
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Reset password modal */}
      {modal?.type === 'reset' && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="mb-2 text-base font-bold text-[#1A1200]">Mật khẩu tạm — {modal.user.username}</h2>
            <p className="mb-4 text-sm text-[#6B5C3E]">Sao chép và gửi cho người dùng qua Zalo/email. Mật khẩu này chỉ hiển thị một lần.</p>
            <div className="mb-4 flex items-center gap-2 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3">
              <code className="flex-1 text-base font-bold text-[#1A1200]">{tempPw}</code>
              <button
                onClick={() => navigator.clipboard.writeText(tempPw)}
                className="text-xs text-[#1D7A4E] underline"
              >
                Copy
              </button>
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
    </div>
  )
}
