# Vifosa Web — Bàn giao

**Ngày:** 2026-05-18  
**Spec:** `vifosa-web-spec-v1.2.md`  
**Repo web:** `C:\Users\Admin\develop\vifosa\web\`  
**Deploy:** Vercel — https://vercel.com/vietfoodshopsalliance-5562s-projects/project-f7r57  
**Backend repo:** https://github.com/vietfoodshopsalliance-art

---

## Stack

- Next.js 16 (App Router, TypeScript)
- Tailwind CSS v4
- Recharts (analytics charts)
- react-markdown + remark-gfm (ToS/Privacy editor)
- socket.io-client (real-time track page)

---

## Trạng thái: ĐÃ XONG (web)

Toàn bộ file theo spec v1.2 đã được tạo và TypeScript check sạch.

### Cấu trúc file hoàn chỉnh

```
web/
├── lib/
│   ├── api.ts               # fetch wrapper, credentials: include, ApiError class
│   ├── auth.ts              # type Me, Role, helpers isAdmin/isStoreUser/isMod
│   └── landing-content.ts   # placeholder nội dung landing — chủ điền sau
├── middleware.ts             # guard /admin (role admin) và /store (store_owner|mod) → redirect /login
├── components/
│   ├── store/
│   │   └── StoreMenuEditor.tsx   # component dùng chung — nhận prop storeId + isAdminMode
│   └── tracking/
│       └── TrackingOrderDetail.tsx  # Socket.IO client — subscribe room theo orderId
└── app/
    ├── (public)/
    │   ├── page.tsx              # Landing page
    │   ├── terms/page.tsx        # Render Markdown từ DB, revalidate 1h
    │   ├── privacy/page.tsx      # Render Markdown từ DB, revalidate 1h
    │   └── track/
    │       ├── page.tsx          # Form tra cứu (mã đơn + SĐT)
    │       └── [code]/page.tsx   # Chi tiết đơn + refund form + support form + Socket.IO
    ├── login/page.tsx            # Login chung admin + store, field: identifier
    ├── register/page.tsx         # Đăng ký bằng SĐT, nhận ?phone=&returnTo= (dispute flow RC-7)
    ├── api/logout/route.ts       # GET /api/logout → clear cookie → redirect /login
    ├── admin/
    │   ├── layout.tsx            # Auth guard server-side: GET /me → check role admin
    │   ├── page.tsx              # Dashboard: alert panel + 4 metrics + shortcuts
    │   ├── analytics/page.tsx    # Charts (Recharts) + mock data (backend chưa có route)
    │   ├── users/page.tsx        # Danh sách user, khoá/mở, toggle mod, reset password
    │   ├── stores/page.tsx       # Danh sách quán, bulk actions, chuyển nhượng
    │   ├── stores/[storeId]/menu/page.tsx  # Impersonate: dùng StoreMenuEditor + banner đỏ cố định
    │   ├── orders/page.tsx       # Đơn cần xử lý + search theo mã + force refund modal
    │   ├── reports/page.tsx      # Báo cáo vi phạm, 3 tab (open/in_review/resolved)
    │   ├── support/page.tsx      # Support tickets, reply, đóng ticket
    │   ├── audit-log/page.tsx    # Nhật ký, filter, diff before/after
    │   └── settings/
    │       ├── page.tsx          # 19 system settings (number + toggle), lưu từng field
    │       └── content/page.tsx  # Markdown editor split-pane cho ToS & Privacy
    └── store/
        ├── layout.tsx            # Auth guard server-side: check role store_owner|mod
        ├── page.tsx              # redirect → /store/menu
        ├── menu/page.tsx         # Dùng StoreMenuEditor
        ├── orders/page.tsx       # Placeholder — "Dùng app Android"
        ├── reviews/page.tsx      # Xem + reply đánh giá, sửa trong 24h
        └── settings/page.tsx     # Giờ mở cửa, phí ship, thanh toán, ngân hàng, chuyển nhượng (mod only)
```

---

## VIỆC CÒN LẠI — Backend (blocker)

Backend phải làm trước khi web hoạt động được. Tất cả nằm trong repo backend tại `C:\Users\Admin\develop\vifosa\backend\`.

### 🔴 Blocker — Auth không hoạt động nếu thiếu

| Việc | File backend | Ghi chú |
|---|---|---|
| Cài `@fastify/cookie` | `package.json` | `npm install @fastify/cookie` |
| `POST /auth/login` set cookie httpOnly | `auth.routes.ts` hoặc `auth.controller.ts` | Cookie tên `accessToken`, httpOnly, Secure, SameSite=Strict, maxAge=900 |
| `POST /auth/logout` clear cookie `accessToken` | `auth.controller.ts` | |
| CORS bật `credentials: true`, whitelist domain Vercel | `app.ts` hoặc fastify config | Domain: `https://project-f7r57.vercel.app` (kiểm tra lại URL thật) |
| `GET /me` trả về `{ _id, username, roles[], storeId? }` | đã có — kiểm tra field `storeId` có trả về không | Web dùng `storeId` để load menu |

### 🟡 Cần cho /admin/analytics (web hiện dùng mock data)

| Việc | File backend | Ghi chú |
|---|---|---|
| Đăng ký route `GET /admin/analytics/orders` | `admin.routes.ts` | Controller đã có trong `analytics.controller.ts` |
| Đăng ký route `GET /admin/analytics/top-stores` | `admin.routes.ts` | Controller đã có |
| Đăng ký route `GET /admin/analytics/top-items` | `admin.routes.ts` | Controller đã có |
| Đăng ký route `GET /admin/analytics/cancellation-rate` | `admin.routes.ts` | Controller đã có |
| Fix field `status` → `mainStatus` trong aggregate | `analytics.controller.ts` | Spec v3.1 dùng `mainStatus` không phải `status` |
| Implement `GET /admin/dashboard-stats` | mới — cần tạo | Aggregate tổng hợp 4 metrics + alerts, cache 5 phút |

### 🟠 Cần cho dispute flow (register → link đơn guest)

| Việc | File backend | Ghi chú |
|---|---|---|
| `POST /auth/register` tự link đơn guest theo phone | `auth.controller.ts` | Spec RC-7: sau khi tạo account với SĐT trùng đơn → auto-link |

---

## Lưu ý quan trọng cho dev tiếp nhận

### Auth flow (phải hiểu đúng)
1. Web gọi `POST /auth/login` với `credentials: 'include'`
2. Backend set cookie `accessToken` httpOnly — **JS không đọc được**
3. Web gọi tiếp `GET /me` để lấy `roles[]`
4. Web tự set cookie `userRoles` (client-readable) để middleware Next.js đọc
5. Middleware đọc cả 2 cookie để guard route

Cookie `accessToken` (httpOnly, backend set) → bảo mật thực sự  
Cookie `userRoles` (client, web set) → chỉ để routing, không phải bảo mật

### Admin role — KHÔNG có UI
Role `admin` chỉ được gán thủ công trong MongoDB. Không có endpoint, không có UI. Đây là thiết kế cố ý theo spec WD-3.

### StoreMenuEditor — dùng chung 2 nơi
- `/store/menu` → `isAdminMode={false}` (mặc định)
- `/admin/stores/[storeId]/menu` → `isAdminMode={true}` → gửi thêm header `X-Admin-Override: true`

### Mock data còn tồn tại ở
- `app/admin/page.tsx` — fallback khi `/admin/dashboard-stats` 404
- `app/admin/analytics/page.tsx` — toàn bộ dữ liệu là mock, xoá khi backend sẵn sàng

### Landing page — chủ điền nội dung
Mở file `lib/landing-content.ts`, điền các field `'ĐIỀN SAU'`:
- `tagline` — câu slogan
- `description` — mô tả ngắn
- `downloadUrl` — link APK hoặc Play Store
- `contactEmail` — email liên hệ
- `features[]` — 3 tính năng nổi bật

### Env vars
```
# web/.env.local
NEXT_PUBLIC_API_URL=http://localhost:8080   # đổi sang URL Render khi deploy
NEXT_PUBLIC_APP_URL=http://localhost:3000   # đổi sang URL Vercel khi deploy
```

---

## Chạy local

```bash
cd web
npm install
npm run dev   # http://localhost:3000
```

Backend phải chạy ở `http://localhost:8080` trước.

---

## Checklist tích hợp (thực hiện theo thứ tự)

- [ ] Backend: cài `@fastify/cookie`, set cookie httpOnly trong login/logout
- [ ] Backend: bật CORS credentials + whitelist Vercel domain
- [ ] Test: đăng nhập tại `/login` → redirect đúng `/admin` hoặc `/store`
- [ ] Test: F5 trang `/admin` → không bị redirect (cookie còn hạn)
- [ ] Backend: đăng ký 4 route analytics, fix field `mainStatus`
- [ ] Web: xoá mock data trong `analytics/page.tsx`, kết nối API thật
- [ ] Backend: implement `GET /admin/dashboard-stats`
- [ ] Web: xoá mock fallback trong `admin/page.tsx`
- [ ] Chủ điền `lib/landing-content.ts`
- [ ] Deploy lên Vercel, cập nhật `NEXT_PUBLIC_API_URL` sang URL Render thật
