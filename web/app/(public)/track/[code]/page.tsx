import { notFound } from 'next/navigation'
import Link from 'next/link'
import TrackOrderClient from '@/components/tracking/TrackingOrderDetail'

const MAIN_STATUS_LABEL: Record<string, string> = {
  cart:               'Đang tạo đơn',
  created:            'Đã tạo',
  awaiting_payment:   'Chờ thanh toán',
  awaiting_store_open:'Chờ quán mở',
  pending_store:      'Chờ quán xác nhận',
  preparing:          'Đang chuẩn bị',
  delivering:         'Đang giao',
  delivered:          'Đã giao',
  completed:          'Hoàn thành',
  cancelled:          'Đã huỷ',
}

async function getOrder(code: string, token: string) {
  try {
    const res = await fetch(
      `${process.env.NEXT_PUBLIC_API_URL}/orders/track/${code}?t=${token}`,
      { cache: 'no-store' },
    )
    if (!res.ok) return null
    return res.json()
  } catch {
    return null
  }
}

function maskPhone(phone: string): string {
  if (!phone || phone.length < 6) return phone
  return `${phone.slice(0, 2)}xx xxx ${phone.slice(-3)}`
}

export default async function TrackOrderPage({
  params,
  searchParams,
}: {
  params: Promise<{ code: string }>
  searchParams: Promise<{ t?: string }>
}) {
  const { code } = await params
  const { t: token } = await searchParams

  // TODO Phase 2: add token expiry validation
  if (!token) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center bg-[#FDFAF3] px-4 text-center">
        <p className="mb-4 text-lg font-semibold text-[#1A1200]">Không tìm thấy đơn hàng</p>
        <Link href="/track" className="text-sm font-medium text-[#1D7A4E] hover:underline">
          Tra cứu đơn hàng
        </Link>
      </div>
    )
  }

  const order = await getOrder(code, token)
  if (!order) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center bg-[#FDFAF3] px-4 text-center">
        <p className="mb-4 text-lg font-semibold text-[#1A1200]">Không tìm thấy đơn hàng</p>
        <Link href="/track" className="text-sm font-medium text-[#1D7A4E] hover:underline">
          Tra cứu đơn hàng
        </Link>
      </div>
    )
  }

  const codePrefix = order.code?.slice(0, -3)
  const codeSuffix = order.code?.slice(-3)

  return (
    <div className="min-h-screen bg-[#FDFAF3] pb-12">
      {/* Header */}
      <header className="border-b border-gray-200 bg-[#1D7A4E]">
        <div className="mx-auto flex h-14 max-w-2xl items-center justify-between px-4">
          <Link href="/" className="text-lg font-bold text-white">Vifosa</Link>
          <Link href="/track" className="text-sm text-white/80 hover:text-white">Tra cứu đơn khác</Link>
        </div>
      </header>

      <div className="mx-auto max-w-2xl px-4 py-6 space-y-4">
        {/* Order code + status */}
        <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
          <p className="mb-1 text-xs text-[#6B5C3E]">Mã đơn hàng</p>
          <p className="mb-3 font-mono text-xl font-bold text-[#1A1200]">
            <span className="text-[#6B5C3E]">{codePrefix}</span>{codeSuffix}
          </p>
          <StatusBadge status={order.mainStatus} label={MAIN_STATUS_LABEL[order.mainStatus] ?? order.mainStatus} />
          {order.paymentStatus && (
            <p className="mt-2 text-xs text-[#6B5C3E]">Thanh toán: <strong>{order.paymentStatus}</strong></p>
          )}
          {order.refundStatus && (
            <p className="mt-1 text-xs text-[#6B5C3E]">Hoàn tiền: <strong>{order.refundStatus}</strong></p>
          )}
        </div>

        {/* Store info */}
        <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
          <p className="mb-2 text-xs font-semibold text-[#6B5C3E] uppercase">Quán</p>
          <p className="font-semibold text-[#1A1200]">{order.store?.name}</p>
          {order.store?.address && <p className="text-sm text-[#6B5C3E]">{order.store.address}</p>}
        </div>

        {/* Items */}
        <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
          <p className="mb-3 text-xs font-semibold text-[#6B5C3E] uppercase">Món đã đặt</p>
          <div className="space-y-2">
            {order.items?.map((item: { name: string; quantity: number; priceSnapshot: number }, i: number) => (
              <div key={i} className="flex justify-between text-sm">
                <span className="text-[#1A1200]">{item.name} <span className="text-[#6B5C3E]">x{item.quantity}</span></span>
                <span className="font-medium">{(item.priceSnapshot * item.quantity).toLocaleString('vi-VN')}đ</span>
              </div>
            ))}
          </div>
          <div className="mt-3 border-t border-gray-100 pt-3 flex justify-between text-sm">
            <span className="text-[#6B5C3E]">Phí ship</span>
            <span>{order.shipFee?.toLocaleString('vi-VN')}đ</span>
          </div>
          <div className="flex justify-between text-base font-bold">
            <span>Tổng</span>
            <span className="text-[#1D7A4E]">{order.totalAmount?.toLocaleString('vi-VN')}đ</span>
          </div>
        </div>

        {/* Payment info */}
        {order.store?.bankAccount && (
          <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <p className="mb-2 text-xs font-semibold text-[#6B5C3E] uppercase">Thanh toán chuyển khoản</p>
            <p className="text-sm"><span className="text-[#6B5C3E]">Ngân hàng:</span> {order.store.bankAccount.bank}</p>
            <p className="text-sm"><span className="text-[#6B5C3E]">Số TK:</span> <span className="font-mono font-bold">{order.store.bankAccount.number}</span></p>
            <p className="text-sm"><span className="text-[#6B5C3E]">Chủ TK:</span> {order.store.bankAccount.holder}</p>
            <p className="mt-1 text-xs text-[#6B5C3E]">SĐT người đặt (ẩn): {maskPhone(order.customerPhone)}</p>
          </div>
        )}

        {/* Refund form — khi cần hoàn tiền */}
        {order.refundStatus === 'required' && (
          <div className="rounded-2xl border border-amber-200 bg-amber-50 p-5">
            <p className="mb-2 font-semibold text-amber-800">Cung cấp thông tin hoàn tiền</p>
            {order.isGuest ? (
              <div>
                <p className="mb-3 text-sm text-amber-700">
                  Để cung cấp thông tin hoàn tiền, bạn cần tạo tài khoản với số điện thoại đã đặt đơn.
                </p>
                <Link
                  href={`/register?phone=${order.customerPhone}&returnTo=/track/${code}?t=${token}`}
                  className="inline-block rounded-lg bg-[#F5C842] px-4 py-2 text-sm font-semibold text-[#3D2800] hover:bg-[#D4A820]"
                >
                  Tạo tài khoản
                </Link>
              </div>
            ) : (
              <RefundForm orderId={order._id} />
            )}
          </div>
        )}

        {/* Real-time client (Socket.IO) */}
        <TrackOrderClient orderId={order._id} trackingToken={token} />

        {/* Support form */}
        <SupportForm orderCode={order.code} guestPhone={order.customerPhone} />
      </div>
    </div>
  )
}

function StatusBadge({ status, label }: { status: string; label: string }) {
  const color = {
    completed: 'bg-green-100 text-green-700',
    cancelled:  'bg-red-100 text-red-700',
    preparing:  'bg-blue-100 text-blue-700',
    delivering: 'bg-purple-100 text-purple-700',
    delivered:  'bg-teal-100 text-teal-700',
  }[status] ?? 'bg-gray-100 text-gray-700'

  return (
    <span className={`inline-block rounded-full px-3 py-1 text-sm font-semibold ${color}`}>{label}</span>
  )
}

function RefundForm({ orderId }: { orderId: string }) {
  return (
    <form
      onSubmit={async (e) => {
        e.preventDefault()
        const fd = new FormData(e.currentTarget)
        await fetch(`${process.env.NEXT_PUBLIC_API_URL}/orders/${orderId}/refund-info`, {
          method: 'POST',
          credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            bankNumber: fd.get('bankNumber'),
            bank: fd.get('bank'),
            holder: fd.get('holder'),
          }),
        })
      }}
      className="space-y-2"
    >
      <input name="bankNumber" type="text" placeholder="Số tài khoản" required
        className="w-full rounded-lg border border-amber-300 bg-white px-3 py-2 text-sm focus:outline-none" />
      <input name="bank" type="text" placeholder="Tên ngân hàng" required
        className="w-full rounded-lg border border-amber-300 bg-white px-3 py-2 text-sm focus:outline-none" />
      <input name="holder" type="text" placeholder="Chủ tài khoản" required
        className="w-full rounded-lg border border-amber-300 bg-white px-3 py-2 text-sm focus:outline-none" />
      <button type="submit" className="w-full rounded-lg bg-[#F5C842] py-2 text-sm font-semibold text-[#3D2800]">
        Gửi thông tin hoàn tiền
      </button>
    </form>
  )
}

function SupportForm({ orderCode, guestPhone }: { orderCode: string; guestPhone: string }) {
  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
      <p className="mb-3 text-sm font-semibold text-[#1A1200]">Liên hệ hỗ trợ</p>
      <form
        onSubmit={async (e) => {
          e.preventDefault()
          const fd = new FormData(e.currentTarget)
          await fetch(`${process.env.NEXT_PUBLIC_API_URL}/support/tickets`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              subject: fd.get('subject'),
              body: fd.get('body'),
              relatedOrderCode: orderCode,
              guestPhone,
            }),
          })
          ;(e.target as HTMLFormElement).reset()
        }}
        className="space-y-3"
      >
        <input name="subject" type="text" placeholder="Tiêu đề" required
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-[#1D7A4E] focus:outline-none" />
        <textarea name="body" placeholder="Mô tả vấn đề..." rows={3} required
          className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:border-[#1D7A4E] focus:outline-none" />
        <button type="submit" className="w-full rounded-lg bg-[#1D7A4E] py-2 text-sm font-semibold text-white hover:bg-[#165f3c]">
          Gửi yêu cầu hỗ trợ
        </button>
      </form>
    </div>
  )
}
