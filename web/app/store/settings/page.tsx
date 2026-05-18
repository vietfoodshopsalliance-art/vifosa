'use client'

import { useState, useEffect } from 'react'
import { api } from '@/lib/api'

interface DaySchedule { closed: boolean; open: string; close: string }
type WeekSchedule = Record<string, DaySchedule>

interface StoreSettings {
  _id: string
  name: string
  description?: string
  shipFeeA: number
  shipFeeB: number
  shipFeeC: number
  autoConfirmMin: number
  autoCancelMin: number
  emergencyClosed: boolean
  paymentMethods: { transfer: boolean; cod: boolean; halfhalf: boolean }
  bankAccount?: { number: string; bank: string; holder: string }
  schedule: WeekSchedule
  roles?: string[]
}

const DAYS = ['Thứ 2','Thứ 3','Thứ 4','Thứ 5','Thứ 6','Thứ 7','Chủ nhật']
const DAY_KEYS = ['mon','tue','wed','thu','fri','sat','sun']

const DEFAULT_SCHEDULE: WeekSchedule = Object.fromEntries(
  DAY_KEYS.map((k) => [k, { closed: false, open: '08:00', close: '22:00' }])
)

const BANKS = ['Vietcombank','Techcombank','BIDV','Agribank','MB Bank','TPBank','VPBank','ACB','Sacombank','HDBank']

function getCookie(name: string): string {
  if (typeof document === 'undefined') return ''
  const match = document.cookie.match(new RegExp('(?:^|; )' + name + '=([^;]*)'))
  return match ? decodeURIComponent(match[1]) : ''
}

export default function StoreSettingsPage() {
  const [storeId, setStoreId]     = useState('')
  const [form, setForm]           = useState<Partial<StoreSettings>>({})
  const [loading, setLoading]     = useState(true)
  const [error, setError]         = useState('')
  const [saving, setSaving]       = useState(false)
  const [actionMsg, setActionMsg] = useState('')
  const [isMod, setIsMod]         = useState(false)
  const [transferModal, setTransferModal] = useState(false)
  const [newOwner, setNewOwner]   = useState('')

  useEffect(() => {
    async function load() {
      const sid = getCookie('storeId')
      setStoreId(sid)
      setError('')
      try {
        const [storesRes, meRes] = await Promise.all([
          api.get<{ stores: StoreSettings[] }>('/me/stores'),
          api.get<{ roles: string[] }>('/me'),
        ])
        const store = sid
          ? storesRes.stores.find((s) => s._id === sid) ?? storesRes.stores[0]
          : storesRes.stores[0]
        if (store) {
          setStoreId(store._id)
          setForm({ ...store, schedule: store.schedule ?? DEFAULT_SCHEDULE })
        }
        setIsMod(meRes.roles?.includes('mod') ?? false)
      } catch (e: any) {
        setError(e?.message ?? 'Lỗi kết nối. Vui lòng thử lại.')
      } finally { setLoading(false) }
    }
    load()
  }, [])

  function set<K extends keyof StoreSettings>(key: K, value: StoreSettings[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  async function save() {
    if (!storeId) return
    setSaving(true)
    try {
      await api.patch(`/stores/${storeId}`, form)
      setActionMsg('Đã lưu cài đặt.')
    } catch (e: any) { setActionMsg(e?.message ?? 'Lưu thất bại.') }
    finally { setSaving(false) }
  }

  async function transfer() {
    if (!newOwner.trim() || !storeId) return
    try {
      await api.post(`/stores/${storeId}/transfer`, { username: newOwner.trim() })
      setActionMsg('Đã chuyển nhượng quán. Bạn sẽ mất quyền truy cập.')
      setTransferModal(false)
    } catch (e: any) { setActionMsg(e?.message ?? 'Chuyển nhượng thất bại.') }
  }

  if (loading) return <div className="p-6 text-[#6B5C3E]">Đang tải...</div>

  if (error) return (
    <div className="p-6">
      <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
    </div>
  )

  const schedule = (form.schedule ?? DEFAULT_SCHEDULE) as WeekSchedule

  return (
    <div className="p-6 max-w-2xl">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-xl font-bold text-[#1A1200]">Cài đặt quán</h1>
        <button onClick={save} disabled={saving} className="rounded-lg bg-[#F5C842] px-4 py-2 text-sm font-semibold text-[#3D2800] disabled:opacity-50 hover:bg-[#D4A820]">
          {saving ? 'Đang lưu...' : 'Lưu tất cả'}
        </button>
      </div>

      {actionMsg && (
        <div className="mb-4 rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm text-green-800">
          {actionMsg} <button className="ml-2 underline" onClick={() => setActionMsg('')}>Đóng</button>
        </div>
      )}

      {/* Đóng cửa khẩn cấp */}
      <section className="mb-6 rounded-xl border border-red-200 bg-red-50 p-4">
        <div className="flex items-center justify-between">
          <div>
            <p className="font-semibold text-red-800">Đóng cửa khẩn cấp</p>
            <p className="text-xs text-red-600">Khi bật, quán ngừng nhận đơn ngay lập tức.</p>
          </div>
          <button
            onClick={() => set('emergencyClosed', !form.emergencyClosed)}
            className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${form.emergencyClosed ? 'bg-red-500' : 'bg-gray-300'}`}
          >
            <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${form.emergencyClosed ? 'translate-x-6' : 'translate-x-1'}`} />
          </button>
        </div>
      </section>

      {/* Thông tin cơ bản */}
      <section className="mb-6 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
        <h2 className="mb-3 text-sm font-semibold text-[#1A1200]">Thông tin cơ bản</h2>
        <div className="space-y-3">
          <div>
            <label className="mb-1 block text-xs text-[#6B5C3E]">Tên quán</label>
            <input type="text" value={form.name ?? ''} onChange={(e) => set('name', e.target.value)}
              className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none" />
          </div>
          <div>
            <label className="mb-1 block text-xs text-[#6B5C3E]">Mô tả</label>
            <textarea value={form.description ?? ''} onChange={(e) => set('description', e.target.value)}
              rows={3} className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none" />
          </div>
        </div>
      </section>

      {/* Giờ mở cửa */}
      <section className="mb-6 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
        <h2 className="mb-3 text-sm font-semibold text-[#1A1200]">Giờ mở cửa</h2>
        <div className="space-y-2">
          {DAY_KEYS.map((key, i) => {
            const day = schedule[key] ?? { closed: false, open: '08:00', close: '22:00' }
            return (
              <div key={key} className="flex flex-wrap items-center gap-3">
                <span className="w-16 text-sm text-[#1A1200]">{DAYS[i]}</span>
                <label className="flex items-center gap-1.5 text-xs text-[#6B5C3E]">
                  <input type="checkbox" checked={day.closed} onChange={(e) => set('schedule', { ...schedule, [key]: { ...day, closed: e.target.checked } })} />
                  Đóng cả ngày
                </label>
                {!day.closed && (
                  <>
                    <input type="time" value={day.open} onChange={(e) => set('schedule', { ...schedule, [key]: { ...day, open: e.target.value } })}
                      className="rounded-lg border border-gray-300 px-2 py-1 text-sm focus:outline-none" />
                    <span className="text-xs text-[#6B5C3E]">–</span>
                    <input type="time" value={day.close} onChange={(e) => set('schedule', { ...schedule, [key]: { ...day, close: e.target.value } })}
                      className="rounded-lg border border-gray-300 px-2 py-1 text-sm focus:outline-none" />
                  </>
                )}
              </div>
            )
          })}
        </div>
      </section>

      {/* Phí ship */}
      <section className="mb-6 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
        <h2 className="mb-3 text-sm font-semibold text-[#1A1200]">Cấu hình phí ship</h2>
        <div className="grid grid-cols-3 gap-3">
          {[
            { label: 'A — Phí cố định (đ)', key: 'shipFeeA' as const },
            { label: 'B — Đơn giá/km (đ)', key: 'shipFeeB' as const },
            { label: 'C — Phụ phí cao điểm (%)', key: 'shipFeeC' as const },
          ].map(({ label, key }) => (
            <div key={key}>
              <label className="mb-1 block text-xs text-[#6B5C3E]">{label}</label>
              <input type="number" value={(form[key] as number) ?? 0} onChange={(e) => set(key, parseFloat(e.target.value))}
                className="w-full rounded-lg border border-gray-300 px-2 py-1.5 text-sm focus:outline-none" min={0} />
            </div>
          ))}
        </div>
        <div className="mt-3 grid grid-cols-2 gap-3">
          <div>
            <label className="mb-1 block text-xs text-[#6B5C3E]">Auto-confirm (phút, 0 = thủ công)</label>
            <input type="number" value={form.autoConfirmMin ?? 0} onChange={(e) => set('autoConfirmMin', parseInt(e.target.value))}
              className="w-full rounded-lg border border-gray-300 px-2 py-1.5 text-sm focus:outline-none" min={0} />
          </div>
          <div>
            <label className="mb-1 block text-xs text-[#6B5C3E]">Auto-cancel (phút)</label>
            <input type="number" value={form.autoCancelMin ?? 15} onChange={(e) => set('autoCancelMin', parseInt(e.target.value))}
              className="w-full rounded-lg border border-gray-300 px-2 py-1.5 text-sm focus:outline-none" min={1} />
          </div>
        </div>
      </section>

      {/* Thanh toán */}
      <section className="mb-6 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
        <h2 className="mb-3 text-sm font-semibold text-[#1A1200]">Phương thức thanh toán</h2>
        <div className="space-y-2">
          {[
            { key: 'transfer' as const, label: 'Chuyển khoản trước' },
            { key: 'cod' as const,      label: 'COD (tiền mặt khi giao)' },
            { key: 'halfhalf' as const, label: '50-50 (nửa trước, nửa khi giao)' },
          ].map(({ key, label }) => (
            <label key={key} className="flex items-center gap-3 text-sm text-[#1A1200]">
              <input
                type="checkbox"
                checked={form.paymentMethods?.[key] ?? false}
                onChange={(e) => set('paymentMethods', { ...(form.paymentMethods ?? { transfer: false, cod: false, halfhalf: false }), [key]: e.target.checked })}
              />
              {label}
            </label>
          ))}
        </div>

        <h3 className="mb-2 mt-4 text-xs font-semibold text-[#6B5C3E]">Tài khoản ngân hàng</h3>
        <div className="space-y-2">
          <input type="text" placeholder="Số tài khoản"
            value={form.bankAccount?.number ?? ''} onChange={(e) => set('bankAccount', { ...(form.bankAccount ?? { number: '', bank: '', holder: '' }), number: e.target.value })}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none" />
          <select value={form.bankAccount?.bank ?? ''} onChange={(e) => set('bankAccount', { ...(form.bankAccount ?? { number: '', bank: '', holder: '' }), bank: e.target.value })}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none">
            <option value="">Chọn ngân hàng</option>
            {BANKS.map((b) => <option key={b} value={b}>{b}</option>)}
          </select>
          <input type="text" placeholder="Chủ tài khoản"
            value={form.bankAccount?.holder ?? ''} onChange={(e) => set('bankAccount', { ...(form.bankAccount ?? { number: '', bank: '', holder: '' }), holder: e.target.value })}
            className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none" />
        </div>
      </section>

      {/* Chuyển nhượng — chỉ mod */}
      {isMod && (
        <section className="rounded-xl border border-red-200 bg-red-50 p-4">
          <h2 className="mb-1 text-sm font-semibold text-red-800">Chuyển nhượng quán</h2>
          <p className="mb-3 text-xs text-red-600">Sau khi chuyển nhượng, bạn sẽ mất quyền truy cập ngay lập tức.</p>
          <button onClick={() => setTransferModal(true)} className="rounded-lg border border-red-300 bg-white px-4 py-2 text-sm font-medium text-red-700 hover:bg-red-100">
            Chuyển nhượng quán
          </button>
        </section>
      )}

      {/* Transfer modal */}
      {transferModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="mb-2 text-base font-bold text-[#1A1200]">Chuyển nhượng quán</h2>
            <p className="mb-4 text-sm text-[#6B5C3E]">Nhập username của chủ mới:</p>
            <input type="text" value={newOwner} onChange={(e) => setNewOwner(e.target.value)}
              placeholder="username" className="mb-4 w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none" />
            <div className="flex gap-3">
              <button onClick={() => { setTransferModal(false); setNewOwner('') }} className="flex-1 rounded-lg border border-gray-200 py-2 text-sm">Huỷ</button>
              <button onClick={transfer} disabled={!newOwner.trim()} className="flex-1 rounded-lg bg-red-500 py-2 text-sm font-semibold text-white disabled:opacity-50">Xác nhận</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
