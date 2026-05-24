import Link from 'next/link'
import type { Metadata } from 'next'
import { LANDING } from '@/lib/landing-content'

export const metadata: Metadata = {
  title: 'Viet Shops — Viet Food Shops Alliance',
  description: LANDING.description !== 'ĐIỀN SAU' ? LANDING.description : 'Nền tảng kết nối quán ăn Việt Nam với thực khách.',
}

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-[#FDFAF3] font-sans text-[#1A1200]">
      {/* Navbar */}
      <header className="sticky top-0 z-30 border-b border-[#1D7A4E]/10 bg-[#1D7A4E]">
        <div className="mx-auto flex h-14 max-w-5xl items-center justify-between px-4">
          <span className="text-lg font-bold text-white">Viet Shops</span>
          <div className="flex items-center gap-4">
            <Link href="/track" className="text-sm text-white/80 hover:text-white transition-colors">Tra cứu đơn</Link>
            <Link href="/login" className="rounded-lg bg-[#F5C842] px-4 py-1.5 text-sm font-semibold text-[#3D2800] hover:bg-[#D4A820] transition-colors">
              Đăng nhập quán
            </Link>
          </div>
        </div>
      </header>

      {/* Hero */}
      <section className="mx-auto max-w-5xl px-4 py-20 text-center">
        <h1 className="mb-4 text-4xl font-bold leading-tight sm:text-5xl">
          {LANDING.tagline !== 'ĐIỀN SAU' ? LANDING.tagline : (
            <>
              Đặt đồ ăn từ quán yêu thích —<br />
              <span className="text-[#1D7A4E]">không qua trung gian</span>
            </>
          )}
        </h1>
        <p className="mx-auto mb-8 max-w-xl text-lg text-[#6B5C3E]">
          {LANDING.description !== 'ĐIỀN SAU'
            ? LANDING.description
            : 'Viet Shops kết nối trực tiếp thực khách với các quán ăn địa phương. Không phí nền tảng, không trung gian, quán tự quản lý.'}
        </p>
        <div className="flex flex-wrap justify-center gap-3">
          <a
            href={LANDING.downloadUrl !== 'ĐIỀN SAU' ? LANDING.downloadUrl : '#'}
            className="inline-flex items-center gap-2 rounded-xl bg-[#F5C842] px-6 py-3 text-base font-bold text-[#3D2800] shadow-md hover:bg-[#D4A820] transition-colors"
          >
            📱 Tải app Android
          </a>
          <Link
            href="/track"
            className="inline-flex items-center gap-2 rounded-xl border border-[#1D7A4E] px-6 py-3 text-base font-semibold text-[#1D7A4E] hover:bg-[#1D7A4E]/5 transition-colors"
          >
            Tra cứu đơn hàng
          </Link>
        </div>
      </section>

      {/* Features */}
      <section className="bg-white py-16">
        <div className="mx-auto max-w-5xl px-4">
          <h2 className="mb-10 text-center text-2xl font-bold text-[#1A1200]">Tại sao chọn Viet Shops?</h2>
          <div className="grid gap-6 sm:grid-cols-3">
            {LANDING.features[0].title !== 'ĐIỀN SAU'
              ? LANDING.features.map((f, i) => (
                  <FeatureCard key={i} icon={['🍜', '🏪', '💸'][i] ?? '✨'} title={f.title} description={f.description} />
                ))
              : (
                <>
                  <FeatureCard icon="🍜" title="Đặt đồ ăn dễ dàng" description="Chọn quán, chọn món, theo dõi đơn real-time ngay trên app." />
                  <FeatureCard icon="🏪" title="Quán tự quản lý" description="Chủ quán toàn quyền quản lý menu, giá, giờ mở cửa — không cần qua ai." />
                  <FeatureCard icon="💸" title="Không phí nền tảng MVP" description="Giai đoạn đầu không thu phí nền tảng. Phí chỉ áp dụng khi có thỏa thuận rõ ràng." />
                </>
              )
            }
          </div>
        </div>
      </section>

      {/* How it works */}
      <section className="py-16">
        <div className="mx-auto max-w-4xl px-4 text-center">
          <h2 className="mb-10 text-2xl font-bold">Cách hoạt động</h2>
          <div className="grid gap-8 sm:grid-cols-3">
            {[
              { step: '1', icon: '📱', title: 'Tải app', desc: 'Tải Viet Shops trên Android, tạo tài khoản miễn phí.' },
              { step: '2', icon: '🔍', title: 'Tìm quán gần bạn', desc: 'App tự định vị, hiện các quán đang mở trong bán kính của bạn.' },
              { step: '3', icon: '🛵', title: 'Đặt & theo dõi', desc: 'Chọn món, xác nhận đơn, theo dõi trạng thái real-time.' },
            ].map(({ step, icon, title, desc }) => (
              <div key={step} className="flex flex-col items-center">
                <div className="mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-[#F5C842] text-xl font-bold text-[#3D2800]">{step}</div>
                <div className="mb-2 text-3xl">{icon}</div>
                <h3 className="mb-1 font-semibold">{title}</h3>
                <p className="text-sm text-[#6B5C3E]">{desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="bg-[#1D7A4E] py-14 text-center text-white">
        <h2 className="mb-4 text-2xl font-bold">Sẵn sàng trải nghiệm?</h2>
        <p className="mb-6 text-white/80">Tải app và đặt đồ ăn ngay hôm nay.</p>
        <a
          href={LANDING.downloadUrl !== 'ĐIỀN SAU' ? LANDING.downloadUrl : '#'}
          className="inline-flex items-center gap-2 rounded-xl bg-[#F5C842] px-6 py-3 text-base font-bold text-[#3D2800] hover:bg-[#D4A820] transition-colors"
        >
          📱 Tải app Android
        </a>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-200 bg-white py-8">
        <div className="mx-auto max-w-5xl px-4">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="font-bold text-[#1D7A4E]">Viet Shops</p>
              <p className="text-xs text-[#6B5C3E]">Viet Food Shops Alliance</p>
            </div>
            <div className="flex flex-wrap gap-4 text-sm text-[#6B5C3E]">
              <Link href="/terms" className="hover:text-[#1D7A4E]">Điều khoản sử dụng</Link>
              <Link href="/privacy" className="hover:text-[#1D7A4E]">Chính sách bảo mật</Link>
              <Link href="/track" className="hover:text-[#1D7A4E]">Tra cứu đơn hàng</Link>
              {LANDING.contactEmail !== 'ĐIỀN SAU' && (
                <a href={`mailto:${LANDING.contactEmail}`} className="hover:text-[#1D7A4E]">{LANDING.contactEmail}</a>
              )}
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}

function FeatureCard({ icon, title, description }: { icon: string; title: string; description: string }) {
  return (
    <div className="rounded-2xl border border-gray-100 bg-[#FDFAF3] p-6 text-center shadow-sm">
      <div className="mb-3 text-4xl">{icon}</div>
      <h3 className="mb-2 font-bold text-[#1A1200]">{title}</h3>
      <p className="text-sm text-[#6B5C3E]">{description}</p>
    </div>
  )
}
