import { cookies } from 'next/headers'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import StoreMenuEditor from '@/components/store/StoreMenuEditor'

async function getStore(storeId: string) {
  const cookieStore = await cookies()
  try {
    const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/admin/stores/${storeId}`, {
      headers: {
        Cookie: cookieStore.toString(),
        'X-Admin-Override': 'true',
      },
      cache: 'no-store',
    })
    if (!res.ok) return null
    return res.json()
  } catch {
    return null
  }
}

export default async function AdminStoreMenuPage({
  params,
}: {
  params: Promise<{ storeId: string }>
}) {
  const { storeId } = await params
  const store = await getStore(storeId)
  if (!store) notFound()

  return (
    <div>
      {/* Impersonate banner — luôn hiện, không thể dismiss */}
      <div className="sticky top-0 z-40 flex items-center gap-3 border-b border-red-300 bg-red-600 px-4 py-3 text-white">
        <span className="text-lg">⚠️</span>
        <p className="flex-1 text-sm font-semibold">
          Bạn đang thao tác với tư cách ADMIN trên quán:{' '}
          <span className="font-bold">{store.name}</span>
        </p>
        <Link
          href="/admin/stores"
          className="rounded-lg border border-red-300 bg-red-700 px-3 py-1.5 text-sm font-semibold hover:bg-red-800"
        >
          Thoát
        </Link>
      </div>

      <StoreMenuEditor storeId={storeId} isAdminMode />
    </div>
  )
}
