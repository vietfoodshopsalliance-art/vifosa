// web/components/tracking/GuestSupportForm.tsx
'use client';
import { useState } from 'react';

interface Props {
  relatedOrderCode?: string;
  guestPhone?: string;
}

export default function GuestSupportForm({ relatedOrderCode, guestPhone }: Props) {
  const [open, setOpen] = useState(false);
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [phone, setPhone] = useState(guestPhone ?? '');
  const [sent, setSent] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    try {
      await fetch(`${process.env.NEXT_PUBLIC_API_URL}/support/tickets`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subject, body, guestPhone: phone, relatedOrderCode }),
      });
      setSent(true);
    } finally {
      setLoading(false);
    }
  }

  if (sent) {
    return (
      <div className="bg-green-50 rounded-2xl p-4 text-center text-green-700 text-sm">
        Đã gửi yêu cầu hỗ trợ. Chúng tôi sẽ phản hồi trong 24h.
      </div>
    );
  }

  return (
    <div className="bg-white rounded-2xl shadow p-6">
      <button
        onClick={() => setOpen(o => !o)}
        className="w-full text-left font-semibold text-gray-800 flex justify-between items-center"
      >
        <span>Liên hệ hỗ trợ</span>
        <span className="text-gray-400">{open ? '▲' : '▼'}</span>
      </button>

      {open && (
        <form onSubmit={handleSubmit} className="mt-4 space-y-3">
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Số điện thoại</label>
            <input
              type="tel"
              value={phone}
              onChange={e => setPhone(e.target.value)}
              required
              className="w-full border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Tiêu đề</label>
            <input
              type="text"
              value={subject}
              onChange={e => setSubject(e.target.value)}
              required
              maxLength={200}
              className="w-full border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-400"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Mô tả vấn đề</label>
            <textarea
              value={body}
              onChange={e => setBody(e.target.value)}
              required
              maxLength={2000}
              rows={4}
              className="w-full border rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-orange-400"
            />
          </div>
          {relatedOrderCode && (
            <p className="text-xs text-gray-400">Liên quan đến đơn: {relatedOrderCode}</p>
          )}
          <button
            type="submit"
            disabled={loading}
            className="w-full bg-orange-500 text-white rounded-lg py-2 text-sm font-semibold hover:bg-orange-600 disabled:opacity-50"
          >
            {loading ? 'Đang gửi...' : 'Gửi yêu cầu'}
          </button>
        </form>
      )}
    </div>
  );
}