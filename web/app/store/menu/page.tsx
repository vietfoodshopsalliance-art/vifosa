import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import type { Metadata } from 'next'
import StoreMenuEditor from '@/components/store/StoreMenuEditor'

export const metadata: Metadata = { title: 'Quản lý Menu — Vifosa' }

async function getStoreId(): Promise<string | null> {
  const cookieStore = await cookies()
  try {
    const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/me`, {
      headers: { Cookie: cookieStore.toString() },
      cache: 'no-store',
    })
    if (!res.ok) return null
    const me = await res.json()
    return me.storeId ?? null
  } catch {
    return null
  }
}

export default async function StoreMenuPage() {
  const storeId = await getStoreId()
  if (!storeId) redirect('/login')

  return (
    <div className="flex h-screen flex-col">
      <div className="flex h-14 items-center border-b border-gray-200 bg-white px-6">
        <h1 className="text-base font-bold text-[#1A1200]">Quản lý Menu</h1>
      </div>
      <div className="flex-1 overflow-hidden">
        <StoreMenuEditor storeId={storeId} />
      </div>
    </div>
  )
}
