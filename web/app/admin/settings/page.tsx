'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { api } from '@/lib/api'

interface SettingField {
  key: string
  label: string
  description: string
  type: 'number' | 'toggle'
  default: number | boolean
}

const FIELDS: SettingField[] = [
  { key: 'home_feed_per_group',          label: 'Số quán mỗi nhóm trang chủ',       description: 'Số quán hiển thị mỗi nhóm category trên trang chủ app.',        type: 'number',  default: 2 },
  { key: 'home_default_radius_km',       label: 'Bán kính tìm quán mặc định (km)',   description: 'Bán kính mặc định khi app tìm quán gần khách.',                  type: 'number',  default: 5 },
  { key: 'ship_fee_default_a',           label: 'Phí ship cố định (đồng)',           description: 'Phần phí ship cố định không phụ thuộc khoảng cách.',             type: 'number',  default: 12000 },
  { key: 'ship_fee_default_b',           label: 'Đơn giá/km (đồng)',                 description: 'Phí ship tính thêm theo từng km.',                               type: 'number',  default: 5000 },
  { key: 'ship_fee_default_c',           label: 'Phụ phí cao điểm (%)',              description: 'Phần trăm phụ phí áp dụng giờ cao điểm.',                        type: 'number',  default: 0 },
  { key: 'service_radius_max_km',        label: 'Bán kính tối đa toàn hệ thống (km)', description: 'Quán không thể phục vụ khách ngoài bán kính này.',              type: 'number',  default: 25 },
  { key: 'service_radius_warn_km',       label: 'Ngưỡng cảnh báo xa (km)',           description: 'Hiện cảnh báo khi khách đặt xa hơn ngưỡng này.',                 type: 'number',  default: 10 },
  { key: 'auto_cancel_pending_min',      label: 'Auto-cancel quán không nhận (phút)', description: 'Phút chờ tối đa trước khi tự động huỷ đơn quán chưa nhận.',     type: 'number',  default: 15 },
  { key: 'auto_cancel_payment_min',      label: 'Auto-cancel chưa thanh toán (phút)', description: 'Phút chờ tối đa để xác nhận tiền vào TK.',                      type: 'number',  default: 10 },
  { key: 'auto_complete_after_delivered_h', label: 'Auto-complete sau giao (giờ)',   description: 'Giờ tự động chuyển sang completed sau khi delivered.',            type: 'number',  default: 3 },
  { key: 'ttl_preparing_alert_h',        label: 'Alert TTL đang chuẩn bị (giờ)',     description: 'Số giờ tối đa ở trạng thái preparing trước khi alert admin.',    type: 'number',  default: 3 },
  { key: 'auto_refunded_after_h',        label: 'Auto-refunded sau khi quán submit (giờ)', description: 'Giờ tự động xác nhận hoàn tiền nếu khách không phản hồi.', type: 'number',  default: 48 },
  { key: 'pre_order_no_action_h',        label: 'Pre-order chưa nhận → cancel (giờ)', description: 'Số giờ pre-order chờ quán nhận trước khi tự huỷ.',              type: 'number',  default: 2 },
  { key: 'commission_tier_500',          label: 'Commission bậc 1 (≥500 đơn/tháng)', description: 'Tỷ lệ hoa hồng % áp dụng khi quán đạt ≥500 đơn/tháng.',         type: 'number',  default: 0.01 },
  { key: 'commission_tier_1000',         label: 'Commission bậc 2 (≥1000 đơn/tháng)', description: 'Tỷ lệ hoa hồng % áp dụng khi quán đạt ≥1000 đơn/tháng.',       type: 'number',  default: 0.03 },
  { key: 'commission_tier_5000',         label: 'Commission bậc 3 (≥5000 đơn/tháng)', description: 'Tỷ lệ hoa hồng % áp dụng khi quán đạt ≥5000 đơn/tháng.',       type: 'number',  default: 0.05 },
  { key: 'commission_enabled',           label: 'Bật thu commission',               description: 'Khi tắt, hệ thống không thu hoa hồng từ quán.',                   type: 'toggle',  default: false },
  { key: 'guest_orders_enabled',         label: 'Cho phép khách vãng lai đặt hàng', description: 'Khi tắt, chỉ tài khoản đã đăng nhập mới đặt được.',              type: 'toggle',  default: true },
  { key: 'vip_purchase_visible',         label: 'Hiện nút mua VIP (Phase 3)',       description: 'Hiện UI mua gói VIP — chỉ bật khi Phase 3 sẵn sàng.',             type: 'toggle',  default: false },
]

type SettingsMap = Record<string, number | boolean>

export default function AdminSettingsPage() {
  const [values, setValues]     = useState<SettingsMap>({})
  const [dirty, setDirty]       = useState<Set<string>>(new Set())
  const [loading, setLoading]   = useState(true)
  const [saving, setSaving]     = useState<string | null>(null)
  const [actionMsg, setActionMsg] = useState('')

  useEffect(() => {
    api.get<{ settings: { key: string; value: number | boolean }[] }>('/admin/settings')
      .then((res) => {
        const map: SettingsMap = {}
        res.settings.forEach(({ key, value }) => { map[key] = value })
        setValues(map)
      })
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [])

  function change(key: string, value: number | boolean) {
    setValues((prev) => ({ ...prev, [key]: value }))
    setDirty((prev) => new Set(prev).add(key))
  }

  async function save(key: string) {
    setSaving(key)
    try {
      await api.put(`/admin/settings/${key}`, { value: values[key] })
      setDirty((prev) => { const next = new Set(prev); next.delete(key); return next })
      setActionMsg(`Đã lưu: ${key}`)
    } catch { setActionMsg('Lưu thất bại.') }
    finally { setSaving(null) }
  }

  if (loading) return <div className="p-6 text-[#6B5C3E]">Đang tải...</div>

  return (
    <div className="p-6">
      <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-xl font-bold text-[#1A1200]">Cài đặt hệ thống</h1>
        <Link
          href="/admin/settings/content"
          className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-[#1A1200] shadow-sm hover:border-[#F5C842]"
        >
          Soạn ToS & Privacy →
        </Link>
      </div>

      {actionMsg && (
        <div className="mb-4 rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm text-green-800">
          {actionMsg} <button className="ml-2 underline" onClick={() => setActionMsg('')}>Đóng</button>
        </div>
      )}

      <div className="space-y-3">
        {FIELDS.map((f) => {
          const val = values[f.key] ?? f.default
          const isDirty = dirty.has(f.key)
          return (
            <div key={f.key} className="flex flex-wrap items-center gap-4 rounded-xl border border-gray-200 bg-white px-4 py-3 shadow-sm">
              <div className="flex-1 min-w-0">
                <p className="font-medium text-[#1A1200]">{f.label}</p>
                <p className="mt-0.5 text-xs text-[#6B5C3E]">{f.description}</p>
              </div>
              <div className="flex items-center gap-3">
                {f.type === 'toggle' ? (
                  <button
                    onClick={() => change(f.key, !val)}
                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                      val ? 'bg-[#1D7A4E]' : 'bg-gray-300'
                    }`}
                  >
                    <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${val ? 'translate-x-6' : 'translate-x-1'}`} />
                  </button>
                ) : (
                  <input
                    type="number"
                    value={val as number}
                    onChange={(e) => change(f.key, parseFloat(e.target.value))}
                    className="w-28 rounded-lg border border-gray-300 px-2 py-1.5 text-sm focus:border-[#1D7A4E] focus:outline-none"
                    step={f.key.startsWith('commission') ? 0.01 : 1}
                  />
                )}
                {isDirty && (
                  <button
                    onClick={() => save(f.key)}
                    disabled={saving === f.key}
                    className="rounded-lg bg-[#F5C842] px-3 py-1.5 text-xs font-semibold text-[#3D2800] disabled:opacity-50"
                  >
                    {saving === f.key ? 'Lưu...' : 'Lưu'}
                  </button>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
