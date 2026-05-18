'use client'

import { useState, useEffect } from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import { api } from '@/lib/api'

type Tab = 'tos' | 'privacy'

interface ContentEntry {
  value: string
  updatedAt?: string
  updatedBy?: string
}

const TOS_REMINDER = `Điều khoản bắt buộc phải có: "Sau 48 giờ kể từ khi quán xác nhận đã hoàn tiền mà khách hàng không phản hồi, hệ thống tự động chuyển trạng thái hoàn tiền sang đã hoàn. Khách hàng đồng ý với điều khoản này khi sử dụng dịch vụ."`

export default function AdminSettingsContentPage() {
  const [tab, setTab]         = useState<Tab>('tos')
  const [tos, setTos]         = useState<ContentEntry>({ value: '' })
  const [privacy, setPrivacy] = useState<ContentEntry>({ value: '' })
  const [draft, setDraft]     = useState('')
  const [saving, setSaving]   = useState(false)
  const [saved, setSaved]     = useState(false)

  useEffect(() => {
    async function loadContent() {
      try {
        const [tosRes, privRes] = await Promise.all([
          api.get<ContentEntry>('/admin/settings/tos_content'),
          api.get<ContentEntry>('/admin/settings/privacy_content'),
        ])
        setTos(tosRes)
        setPrivacy(privRes)
      } catch {}
    }
    loadContent()
  }, [])

  useEffect(() => {
    setDraft(tab === 'tos' ? tos.value : privacy.value)
    setSaved(false)
  }, [tab, tos.value, privacy.value])

  async function publish() {
    setSaving(true)
    try {
      const key = tab === 'tos' ? 'tos_content' : 'privacy_content'
      const res = await api.put<ContentEntry>(`/admin/settings/${key}`, { value: draft })
      if (tab === 'tos') setTos(res)
      else setPrivacy(res)
      setSaved(true)
    } catch {}
    finally { setSaving(false) }
  }

  const current = tab === 'tos' ? tos : privacy

  return (
    <div className="flex h-screen flex-col p-6">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-xl font-bold text-[#1A1200]">Soạn thảo ToS & Privacy</h1>
        <button
          onClick={publish}
          disabled={saving}
          className="rounded-lg bg-[#1D7A4E] px-4 py-2 text-sm font-semibold text-white disabled:opacity-50 hover:bg-[#165f3c]"
        >
          {saving ? 'Đang lưu...' : saved ? '✓ Đã lưu & Publish' : 'Lưu & Publish'}
        </button>
      </div>

      {/* Tabs */}
      <div className="mb-4 flex gap-1 border-b border-gray-200">
        {(['tos', 'privacy'] as Tab[]).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`px-4 py-2 text-sm font-medium transition-colors ${
              tab === t
                ? 'border-b-2 border-[#F5C842] text-[#1A1200]'
                : 'text-[#6B5C3E] hover:text-[#1A1200]'
            }`}
          >
            {t === 'tos' ? 'Terms of Service' : 'Privacy Policy'}
          </button>
        ))}
      </div>

      {current.updatedAt && (
        <p className="mb-3 text-xs text-[#6B5C3E]">
          Cập nhật lần cuối: {new Date(current.updatedAt).toLocaleString('vi-VN')}
          {current.updatedBy && ` bởi ${current.updatedBy}`}
        </p>
      )}

      {/* Split pane editor */}
      <div className="flex flex-1 gap-4 overflow-hidden">
        <div className="flex flex-1 flex-col">
          <p className="mb-2 text-xs font-semibold text-[#6B5C3E] uppercase">Markdown</p>
          <textarea
            value={draft}
            onChange={(e) => { setDraft(e.target.value); setSaved(false) }}
            className="flex-1 resize-none rounded-xl border border-gray-300 p-3 font-mono text-sm text-[#1A1200] focus:border-[#1D7A4E] focus:outline-none"
            placeholder="Nhập nội dung Markdown..."
          />
        </div>

        <div className="flex flex-1 flex-col overflow-hidden">
          <p className="mb-2 text-xs font-semibold text-[#6B5C3E] uppercase">Preview</p>
          <div className="flex-1 overflow-y-auto rounded-xl border border-gray-200 bg-white p-4 prose prose-sm max-w-none text-[#1A1200]">
            {draft
              ? <ReactMarkdown remarkPlugins={[remarkGfm]}>{draft}</ReactMarkdown>
              : <p className="text-[#6B5C3E] italic">Preview sẽ hiện ở đây...</p>
            }
          </div>
        </div>
      </div>

      {/* ToS reminder */}
      {tab === 'tos' && (
        <div className="mt-4 flex gap-3 rounded-xl border border-amber-200 bg-amber-50 p-4">
          <span className="shrink-0">⚠️</span>
          <p className="text-xs text-amber-800">{TOS_REMINDER}</p>
        </div>
      )}
    </div>
  )
}
