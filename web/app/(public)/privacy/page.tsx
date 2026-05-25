import Link from 'next/link'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import type { Metadata } from 'next'

export const metadata: Metadata = { title: 'Chính sách bảo mật — Viet Shops' }

export const dynamic = 'force-dynamic'

async function getContent(): Promise<{ value: string; updatedAt?: string } | null> {
  try {
    const res = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/settings/privacy_content`, {
      cache: 'no-store',
      signal: AbortSignal.timeout(5000),
    })
    if (!res.ok) return null
    return res.json()
  } catch {
    return null
  }
}

export default async function PrivacyPage() {
  const content = await getContent()

  return (
    <div className="min-h-screen bg-[#FDFAF3]">
      <header className="border-b border-gray-200 bg-[#1D7A4E]">
        <div className="mx-auto flex h-14 max-w-3xl items-center px-4">
          <Link href="/" className="text-lg font-bold text-white">Viet Shops</Link>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-4 py-10">
        <h1 className="mb-6 text-2xl font-bold text-[#1A1200]">Chính sách bảo mật</h1>

        {content?.value ? (
          <div className="prose prose-sm max-w-none text-[#1A1200]">
            <ReactMarkdown remarkPlugins={[remarkGfm]}>{content.value}</ReactMarkdown>
          </div>
        ) : (
          <p className="text-[#6B5C3E] italic">Nội dung đang được cập nhật.</p>
        )}

        {content?.updatedAt && (
          <p className="mt-8 text-xs text-[#6B5C3E]">
            Cập nhật lần cuối: {new Date(content.updatedAt).toLocaleDateString('vi-VN')}
          </p>
        )}
      </main>

      <footer className="border-t border-gray-200 py-6 text-center text-xs text-[#6B5C3E]">
        <Link href="/" className="hover:underline">Trang chủ</Link>
        {' · '}
        <Link href="/terms" className="hover:underline">Điều khoản sử dụng</Link>
      </footer>
    </div>
  )
}
