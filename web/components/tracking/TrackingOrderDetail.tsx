'use client'

import { useEffect, useState } from 'react'
import { io } from 'socket.io-client'

interface Props {
  orderId: string
  trackingToken: string
}

export default function TrackingOrderDetail({ orderId, trackingToken }: Props) {
  const [status, setStatus]       = useState<string | null>(null)
  const [connected, setConnected] = useState(false)

  useEffect(() => {
    const socket = io(process.env.NEXT_PUBLIC_API_URL ?? '', {
      withCredentials: false,
    })

    socket.on('connect', () => {
      setConnected(true)
      socket.emit('join-order-room', { orderId, trackingToken })
    })

    socket.on('disconnect', () => setConnected(false))

    socket.on('order:status', (data: { mainStatus: string }) => {
      setStatus(data.mainStatus)
    })

    return () => { socket.disconnect() }
  }, [orderId, trackingToken])

  if (!status && connected) return null

  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
      <div className="flex items-center gap-2">
        <span className={`h-2 w-2 rounded-full ${connected ? 'animate-pulse bg-green-500' : 'bg-gray-300'}`} />
        <span className="text-xs text-[#6B5C3E]">
          {connected ? 'Đang theo dõi real-time' : 'Đang kết nối lại...'}
        </span>
      </div>
      {status && (
        <p className="mt-2 text-sm font-medium text-[#1A1200]">Cập nhật: <strong>{status}</strong></p>
      )}
    </div>
  )
}
