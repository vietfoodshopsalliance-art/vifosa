'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { api } from '@/lib/api'

// ── Types ─────────────────────────────────────────────────────────────────────

interface Store {
  _id: string
  name: string
  vipTier: 'none' | 'vip' | 'vvip' | 'vvvip'
  vipExpiresAt: string | null
}

interface VipPlan {
  _id: string
  tier: 'vip' | 'vvip' | 'vvvip'
  name: string
  durationDays: number
  price: number
  benefits: string[]
}

interface BankInfo {
  bankNumber: string
  bankName: string
  bankHolder: string
  content: string
  note: string
}

interface Subscription {
  _id: string
  status: 'pending_payment' | 'active' | 'expired' | 'cancelled' | 'failed'
  tier: string
  pricePaid: number
  durationDays: number
  sePayOrderCode: string
  startedAt?: string
  expiresAt?: string
}

interface SubscribeResponse {
  subscription: Subscription
  bankInfo: BankInfo
}

interface SubStatusResponse {
  subscription: Subscription | null
  store: { vipTier: string; vipExpiresAt: string | null }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const TIER_LABEL: Record<string, string> = {
  none: 'Chưa có',
  vip: 'VIP',
  vvip: 'VVIP',
  vvvip: 'VVVIP',
}

const TIER_COLOR: Record<string, string> = {
  none:  'bg-gray-100 text-gray-500',
  vip:   'bg-yellow-100 text-yellow-800',
  vvip:  'bg-gray-200 text-gray-700',
  vvvip: 'bg-purple-100 text-purple-800',
}

function fmtDate(iso: string | null) {
  if (!iso) return '—'
  const d = new Date(iso)
  return `${d.getDate().toString().padStart(2, '0')}/${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getFullYear()}`
}

function fmtMoney(n: number) {
  return n.toLocaleString('vi-VN') + ' đ'
}

function getCookie(name: string): string {
  if (typeof document === 'undefined') return ''
  const m = document.cookie.match(new RegExp('(?:^|; )' + name + '=([^;]*)'))
  return m ? decodeURIComponent(m[1]) : ''
}

// ── Component ─────────────────────────────────────────────────────────────────

export default function StoreVipPage() {
  const [stores, setStores]       = useState<Store[]>([])
  const [plans, setPlans]         = useState<VipPlan[]>([])
  const [loading, setLoading]     = useState(true)
  const [error, setError]         = useState('')

  // Trạng thái flow đăng ký
  const [selectedStore, setSelectedStore] = useState<Store | null>(null)
  const [selectedPlan, setSelectedPlan]   = useState<VipPlan | null>(null)
  const [pending, setPending]             = useState<{ sub: Subscription; bankInfo: BankInfo } | null>(null)
  const [subscribing, setSubscribing]     = useState(false)
  const [subError, setSubError]           = useState('')

  // Polling
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const stopPoll = useCallback(() => {
    if (pollRef.current) { clearInterval(pollRef.current); pollRef.current = null }
  }, [])

  const startPoll = useCallback((storeId: string) => {
    stopPoll()
    pollRef.current = setInterval(async () => {
      try {
        const res = await api.get<SubStatusResponse>(`/me/stores/${storeId}/vip/subscription`)
        if (res.subscription?.status === 'active') {
          stopPoll()
          // Refresh store list để cập nhật vipTier
          const fresh = await api.get<Store[]>('/me/stores')
          setStores(fresh)
          setPending(null)
          setSelectedPlan(null)
          setSelectedStore(null)
        }
      } catch { /* ignore */ }
    }, 5000)
  }, [stopPoll])

  useEffect(() => () => stopPoll(), [stopPoll])

  useEffect(() => {
    async function load() {
      try {
        const [storesRes, plansRes] = await Promise.all([
          api.get<Store[]>('/me/stores'),
          api.get<VipPlan[]>('/vip/plans'),
        ])
        setStores(storesRes)
        setPlans(plansRes)

        // Chọn sẵn quán theo cookie storeId nếu có
        const sid = getCookie('storeId')
        if (sid) {
          const found = storesRes.find((s) => s._id === sid)
          if (found) setSelectedStore(found)
        }
      } catch (e: any) {
        setError(e?.message ?? 'Lỗi kết nối')
      } finally {
        setLoading(false)
      }
    }
    load()
  }, [])

  async function handleSubscribe() {
    if (!selectedStore || !selectedPlan) return
    setSubscribing(true)
    setSubError('')
    try {
      const res = await api.post<SubscribeResponse>(
        `/me/stores/${selectedStore._id}/vip/subscribe`,
        { planId: selectedPlan._id }
      )
      setPending({ sub: res.subscription, bankInfo: res.bankInfo })
      startPoll(selectedStore._id)
    } catch (e: any) {
      setSubError(e?.message ?? 'Đăng ký thất bại')
    } finally {
      setSubscribing(false)
    }
  }

  function handleCancelPending() {
    stopPoll()
    setPending(null)
    setSelectedPlan(null)
  }

  if (loading) return <div className="p-6 text-sm text-[#6B5C3E]">Đang tải...</div>

  if (error) return (
    <div className="p-6">
      <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
    </div>
  )

  // ── Trạng thái chờ thanh toán ────────────────────────────────────────────────
  if (pending) {
    const { sub, bankInfo } = pending
    return (
      <div className="p-6 max-w-lg">
        <h1 className="mb-1 text-xl font-bold text-[#1A1200]">Chờ xác nhận thanh toán</h1>
        <p className="mb-6 text-sm text-[#6B5C3E]">
          Chuyển khoản đúng thông tin bên dưới. Hệ thống tự động kích hoạt VIP sau khi nhận tiền.
        </p>

        <div className="mb-4 rounded-xl border border-yellow-300 bg-yellow-50 p-5 space-y-3">
          <Row label="Ngân hàng"   value={bankInfo.bankName} />
          <Row label="Số tài khoản" value={bankInfo.bankNumber} copyable />
          <Row label="Chủ TK"      value={bankInfo.bankHolder} />
          <Row label="Số tiền"     value={fmtMoney(sub.pricePaid)} />
          <div className="border-t border-yellow-200 pt-3">
            <p className="mb-1 text-xs font-semibold text-yellow-900 uppercase tracking-wide">Nội dung chuyển khoản</p>
            <CopyBlock text={bankInfo.content} />
            <p className="mt-1 text-xs text-yellow-700">{bankInfo.note}</p>
          </div>
        </div>

        <div className="flex items-center gap-2 text-sm text-[#6B5C3E]">
          <SpinnerIcon />
          <span>Đang chờ xác nhận từ Sepay...</span>
        </div>

        <button
          onClick={handleCancelPending}
          className="mt-4 text-xs text-gray-400 underline hover:text-gray-600"
        >
          Huỷ / Quay lại
        </button>
      </div>
    )
  }

  // ── Màn hình chọn quán & gói ─────────────────────────────────────────────────
  return (
    <div className="p-6 max-w-2xl">
      <div className="mb-6">
        <h1 className="text-xl font-bold text-[#1A1200]">Đăng ký VIP quán</h1>
        <p className="mt-1 text-sm text-[#6B5C3E]">
          Nâng cấp VIP để được ưu tiên hiển thị và mở khóa tính năng cao cấp. Thanh toán tự động qua Sepay.
        </p>
      </div>

      {/* Trạng thái VIP hiện tại */}
      <section className="mb-6 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
        <h2 className="mb-3 text-sm font-semibold text-[#1A1200]">Trạng thái VIP quán của bạn</h2>
        {stores.length === 0 ? (
          <p className="text-sm text-[#6B5C3E]">Bạn chưa có quán nào.</p>
        ) : (
          <div className="space-y-2">
            {stores.map((s) => (
              <div key={s._id} className="flex items-center justify-between rounded-lg border border-gray-100 px-4 py-3">
                <div>
                  <p className="text-sm font-medium text-[#1A1200]">{s.name}</p>
                  {s.vipTier !== 'none' && s.vipExpiresAt && (
                    <p className="text-xs text-[#6B5C3E]">Hết hạn: {fmtDate(s.vipExpiresAt)}</p>
                  )}
                </div>
                <span className={`rounded-full px-2.5 py-0.5 text-xs font-semibold ${TIER_COLOR[s.vipTier]}`}>
                  {TIER_LABEL[s.vipTier]}
                </span>
              </div>
            ))}
          </div>
        )}
      </section>

      {/* Chọn quán */}
      {stores.length > 0 && (
        <section className="mb-4 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
          <h2 className="mb-3 text-sm font-semibold text-[#1A1200]">Chọn quán muốn đăng ký</h2>
          <div className="flex flex-wrap gap-2">
            {stores.map((s) => (
              <button
                key={s._id}
                onClick={() => { setSelectedStore(s); setSelectedPlan(null) }}
                className={`rounded-lg border px-4 py-2 text-sm font-medium transition-colors ${
                  selectedStore?._id === s._id
                    ? 'border-[#F5C842] bg-[#FFF9E0] text-[#3D2800]'
                    : 'border-gray-200 bg-white text-[#1A1200] hover:bg-gray-50'
                }`}
              >
                {s.name}
              </button>
            ))}
          </div>
        </section>
      )}

      {/* Chọn gói */}
      {selectedStore && (
        <section className="mb-6 rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
          <h2 className="mb-3 text-sm font-semibold text-[#1A1200]">Chọn gói VIP</h2>
          {plans.length === 0 ? (
            <p className="text-sm text-[#6B5C3E]">Chưa có gói nào. Vui lòng liên hệ admin.</p>
          ) : (
            <div className="grid gap-3 sm:grid-cols-2">
              {plans.map((p) => (
                <button
                  key={p._id}
                  onClick={() => setSelectedPlan(p)}
                  className={`rounded-xl border p-4 text-left transition-all ${
                    selectedPlan?._id === p._id
                      ? 'border-[#F5C842] bg-[#FFF9E0] shadow'
                      : 'border-gray-200 bg-white hover:border-[#F5C842]/60'
                  }`}
                >
                  <div className="flex items-center justify-between mb-1">
                    <span className={`rounded-full px-2 py-0.5 text-xs font-bold ${TIER_COLOR[p.tier]}`}>
                      {TIER_LABEL[p.tier]}
                    </span>
                    <span className="text-sm font-bold text-[#1A1200]">{fmtMoney(p.price)}</span>
                  </div>
                  <p className="text-sm font-semibold text-[#1A1200]">{p.name}</p>
                  <p className="text-xs text-[#6B5C3E]">{p.durationDays} ngày</p>
                  {p.benefits.length > 0 && (
                    <ul className="mt-2 space-y-0.5">
                      {p.benefits.map((b, i) => (
                        <li key={i} className="flex items-start gap-1 text-xs text-[#6B5C3E]">
                          <span className="mt-0.5 text-green-500">✓</span> {b}
                        </li>
                      ))}
                    </ul>
                  )}
                </button>
              ))}
            </div>
          )}
        </section>
      )}

      {/* Nút đăng ký */}
      {selectedStore && selectedPlan && (
        <>
          {subError && (
            <div className="mb-3 rounded-lg border border-red-200 bg-red-50 px-4 py-2 text-sm text-red-700">
              {subError}
            </div>
          )}
          <button
            onClick={handleSubscribe}
            disabled={subscribing}
            className="rounded-xl bg-[#F5C842] px-6 py-3 text-sm font-bold text-[#3D2800] shadow hover:bg-[#D4A820] disabled:opacity-50 transition-colors"
          >
            {subscribing ? 'Đang xử lý...' : `Đăng ký ${TIER_LABEL[selectedPlan.tier]} cho "${selectedStore.name}"`}
          </button>
        </>
      )}
    </div>
  )
}

// ── Sub-components ────────────────────────────────────────────────────────────

function Row({ label, value, copyable }: { label: string; value: string; copyable?: boolean }) {
  const [copied, setCopied] = useState(false)
  function copy() {
    navigator.clipboard.writeText(value).then(() => { setCopied(true); setTimeout(() => setCopied(false), 2000) })
  }
  return (
    <div className="flex items-center justify-between">
      <span className="text-xs text-yellow-800">{label}</span>
      <div className="flex items-center gap-2">
        <span className="text-sm font-semibold text-[#1A1200]">{value}</span>
        {copyable && (
          <button onClick={copy} className="text-xs text-yellow-700 underline hover:text-yellow-900">
            {copied ? 'Đã copy' : 'Copy'}
          </button>
        )}
      </div>
    </div>
  )
}

function CopyBlock({ text }: { text: string }) {
  const [copied, setCopied] = useState(false)
  function copy() {
    navigator.clipboard.writeText(text).then(() => { setCopied(true); setTimeout(() => setCopied(false), 2000) })
  }
  return (
    <div
      onClick={copy}
      className="flex cursor-pointer items-center justify-between rounded-lg border border-yellow-300 bg-white px-3 py-2 hover:bg-yellow-50"
    >
      <span className="font-mono text-sm font-bold tracking-wide text-[#1A1200]">{text}</span>
      <span className="ml-3 text-xs text-yellow-700">{copied ? '✓ Đã copy' : 'Tap để copy'}</span>
    </div>
  )
}

function SpinnerIcon() {
  return (
    <svg className="h-4 w-4 animate-spin text-[#F5C842]" viewBox="0 0 24 24" fill="none">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4l3-3-3-3v4a8 8 0 00-8 8h4z" />
    </svg>
  )
}
