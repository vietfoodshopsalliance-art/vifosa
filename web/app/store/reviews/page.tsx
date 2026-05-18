'use client'

import { useState, useEffect, useCallback } from 'react'
import { api } from '@/lib/api'

interface Review {
  _id: string
  rating: number
  comment?: string
  images?: string[]
  isAnonymous: boolean
  customerName?: string
  storeReply?: string
  repliedAt?: string
  createdAt: string
}

type Filter = 'all' | 'unreplied' | 'replied' | '1' | '2' | '3' | '4' | '5'

export default function StoreReviewsPage() {
  const [reviews, setReviews]   = useState<Review[]>([])
  const [loading, setLoading]   = useState(true)
  const [filter, setFilter]     = useState<Filter>('all')
  const [replyModal, setReplyModal] = useState<Review | null>(null)
  const [reply, setReply]       = useState('')
  const [saving, setSaving]     = useState(false)
  const [actionMsg, setActionMsg] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const params = new URLSearchParams({ limit: '20' })
      if (filter === 'unreplied') params.set('replied', 'false')
      else if (filter === 'replied') params.set('replied', 'true')
      else if (['1','2','3','4','5'].includes(filter)) params.set('rating', filter)
      const res = await api.get<{ reviews: Review[] }>(`/store/reviews?${params}`)
      setReviews(res.reviews)
    } catch { setReviews([]) }
    finally { setLoading(false) }
  }, [filter])

  useEffect(() => { load() }, [load])

  async function submitReply() {
    if (!replyModal || !reply.trim()) return
    setSaving(true)
    try {
      await api.post(`/store/reviews/${replyModal._id}/reply`, { reply })
      setActionMsg('Đã gửi phản hồi.')
      setReplyModal(null)
      setReply('')
      load()
    } catch { setActionMsg('Gửi phản hồi thất bại.') }
    finally { setSaving(false) }
  }

  async function editReply() {
    if (!replyModal || !reply.trim()) return
    setSaving(true)
    try {
      await api.patch(`/store/reviews/${replyModal._id}/reply`, { reply })
      setActionMsg('Đã cập nhật phản hồi.')
      setReplyModal(null)
      setReply('')
      load()
    } catch { setActionMsg('Cập nhật thất bại.') }
    finally { setSaving(false) }
  }

  function canEdit(r: Review): boolean {
    if (!r.repliedAt) return false
    return Date.now() - new Date(r.repliedAt).getTime() < 24 * 60 * 60 * 1000
  }

  return (
    <div className="p-6">
      <h1 className="mb-6 text-xl font-bold text-[#1A1200]">Đánh giá</h1>

      {actionMsg && (
        <div className="mb-4 rounded-lg border border-green-200 bg-green-50 px-4 py-2 text-sm text-green-800">
          {actionMsg} <button className="ml-2 underline" onClick={() => setActionMsg('')}>Đóng</button>
        </div>
      )}

      {/* Filter */}
      <div className="mb-4 flex flex-wrap gap-2">
        {([
          { val: 'all', label: 'Tất cả' },
          { val: 'unreplied', label: 'Chưa reply' },
          { val: 'replied', label: 'Đã reply' },
          { val: '5', label: '⭐⭐⭐⭐⭐' },
          { val: '4', label: '⭐⭐⭐⭐' },
          { val: '3', label: '⭐⭐⭐' },
          { val: '1', label: '⭐' },
        ] as { val: Filter; label: string }[]).map(({ val, label }) => (
          <button
            key={val}
            onClick={() => setFilter(val)}
            className={`rounded-full px-3 py-1.5 text-xs font-medium transition-colors ${
              filter === val ? 'bg-[#F5C842] text-[#3D2800]' : 'border border-gray-200 bg-white text-[#6B5C3E] hover:bg-gray-50'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Review list */}
      <div className="space-y-3">
        {loading && <p className="text-center text-sm text-[#6B5C3E]">Đang tải...</p>}
        {!loading && reviews.length === 0 && <p className="text-center text-sm text-[#6B5C3E]">Không có đánh giá nào.</p>}
        {reviews.map((r) => (
          <div key={r._id} className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
            <div className="flex items-start justify-between gap-2">
              <div>
                <p className="text-sm font-semibold text-[#1A1200]">
                  {r.isAnonymous ? 'Người dùng ẩn danh' : (r.customerName ?? 'Khách hàng')}
                </p>
                <div className="mt-0.5 flex gap-0.5">
                  {Array.from({ length: 5 }).map((_, i) => (
                    <span key={i} className={i < r.rating ? 'text-[#F5C842]' : 'text-gray-200'}>★</span>
                  ))}
                </div>
              </div>
              <span className="text-xs text-[#6B5C3E]">{new Date(r.createdAt).toLocaleDateString('vi-VN')}</span>
            </div>

            {r.comment && <p className="mt-2 text-sm text-[#1A1200]">{r.comment}</p>}

            {r.images && r.images.length > 0 && (
              <div className="mt-2 flex gap-2">
                {r.images.map((img, i) => (
                  <a key={i} href={img} target="_blank" rel="noreferrer">
                    <img src={img} alt="" className="h-16 w-16 rounded-lg object-cover" />
                  </a>
                ))}
              </div>
            )}

            {r.storeReply && (
              <div className="mt-3 rounded-lg border border-[#1D7A4E]/20 bg-[#1D7A4E]/5 p-3">
                <p className="mb-1 text-xs font-semibold text-[#1D7A4E]">Phản hồi của quán</p>
                <p className="text-sm text-[#1A1200]">{r.storeReply}</p>
              </div>
            )}

            <div className="mt-3 flex gap-2">
              {!r.storeReply && (
                <button
                  onClick={() => { setReplyModal(r); setReply('') }}
                  className="rounded-lg border border-[#1D7A4E] px-3 py-1.5 text-xs font-medium text-[#1D7A4E] hover:bg-[#1D7A4E]/5"
                >
                  Trả lời
                </button>
              )}
              {r.storeReply && canEdit(r) && (
                <button
                  onClick={() => { setReplyModal(r); setReply(r.storeReply ?? '') }}
                  className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-[#6B5C3E] hover:bg-gray-50"
                >
                  Sửa phản hồi
                </button>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Reply modal */}
      {replyModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="mb-3 text-base font-bold text-[#1A1200]">
              {replyModal.storeReply ? 'Sửa phản hồi' : 'Trả lời đánh giá'}
            </h2>
            <p className="mb-3 rounded-lg bg-gray-50 p-3 text-sm text-[#6B5C3E] italic">"{replyModal.comment}"</p>
            <textarea
              value={reply}
              onChange={(e) => setReply(e.target.value)}
              placeholder="Nhập phản hồi của quán..."
              rows={4}
              className="mb-4 w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none"
            />
            <div className="flex gap-3">
              <button onClick={() => { setReplyModal(null); setReply('') }} className="flex-1 rounded-lg border border-gray-200 py-2 text-sm">Huỷ</button>
              <button
                onClick={replyModal.storeReply ? editReply : submitReply}
                disabled={saving || !reply.trim()}
                className="flex-1 rounded-lg bg-[#1D7A4E] py-2 text-sm font-semibold text-white disabled:opacity-50"
              >
                {saving ? 'Đang gửi...' : 'Gửi'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
