# Implementation Notes — API Audit
**Ngày:** 2026-05-20  
**Phạm vi:** Backend route audit so với API Contract v3.1 + corrections từ user

---

## 1. Quyết định AI tự ra mà spec không nói

### 1.1. HTTP method cho order status transitions
Spec (vifosa-api-contract.md) định nghĩa các action của quán là **POST**:
```
POST /orders/:id/accept
POST /orders/:id/reject
POST /orders/:id/handover
POST /orders/:id/complete-delivery
```

Backend thực tế dùng **PATCH**:
```
PATCH /orders/:id/accept
PATCH /orders/:id/reject
PATCH /orders/:id/deliver
PATCH /orders/:id/complete
```

Lý do: PATCH ngữ nghĩa phù hợp hơn (partial update), idempotent-safe hơn cho retry. Đây là quyết định đúng theo REST semantics và được user xác nhận là đúng trong corrective notes.

### 1.2. `/me/stores/` prefix thay vì `/stores/` cho store-owner endpoints
Spec định nghĩa một số route dưới `/stores/:id/...` (không cần prefix `/me/`), nhưng backend và user đồng ý dùng `/me/stores/:id/...`:
- Mục đích: rõ ràng ownership scope, tránh nhầm lẫn giữa public endpoint và owner endpoint
- Không có spec đề cập tường minh — AI quyết định pattern này khi implement store dashboard

---

## 2. Chỗ AI đổi so với yêu cầu ban đầu (spec → thực tế backend)

| Spec (vifosa-api-contract.md) | Backend thực tế | Ghi chú |
|---|---|---|
| `GET /stores/:storeId/orders` | `GET /me/stores/:storeId/orders?tab=...` | Owner-only, tab filter |
| `PUT /stores/:storeId/settings/emergency-close` | `PATCH /me/stores/:storeId/emergency-close` | Method + path đều khác |
| `POST /orders/:id/accept` | `PATCH /orders/:id/accept` | Method khác |
| `POST /orders/:id/reject` | `PATCH /orders/:id/reject` | Method khác |
| `POST /orders/:id/handover` | `PATCH /orders/:id/deliver` | Method + action name khác |
| `POST /orders/:id/complete-delivery` | `PATCH /orders/:id/complete` | Method + action name khác |
| `PUT /me` | `PATCH /me` | Method khác (minor) |

---

## 3. Tradeoff AI phải cân nhắc

### 3.1. `/me/stores/` vs `/stores/` cho owner routes
- **Pro `/me/stores/`**: Rõ ràng ownership, consistent với `/me/orders`, `/me/cart` pattern; backend dễ verify auth (không cần lookup owner từ storeId).
- **Con**: Khác spec, mobile cần dùng đúng constant (`myStoreOrders` không phải `storeOrders`).
- **Chọn**: `/me/stores/` — được user xác nhận.

### 3.2. Dùng `tab=pending|active|history` query thay vì `status=` filter
- Spec dùng `?status=` filter trực tiếp theo `mainStatus` value.
- Backend dùng `?tab=pending|active|history` gộp nhiều `mainStatus` thành nhóm.
- **Pro**: UX store dashboard dễ hơn (3 tab rõ ràng).
- **Con**: Client không thể filter theo status cụ thể (ví dụ chỉ lấy `delivering`).
- **Chọn**: tab-based — phù hợp với store dashboard UI.

---

## 4. Những điều khác cần biết

### 4.1. Dashboard Stats URL — ĐÃ XỬ LÝ
- **Backend:** `GET /me/stores/:storeId/stats` (giữ nguyên)
- **Mobile ApiEndpoints:** `storeDashboardStats(id)` đã sửa → `/me/stores/$id/stats`
- Không tạo variant `/me/stores/:id/dashboard/stats`.

### 4.2. ⚠️ Dead constants trong mobile ApiEndpoints
Mobile `api_endpoints.dart` có cả **URL sai lẫn URL đúng** tồn tại song song:

| Constant sai (old spec) | Constant đúng (actual backend) |
|---|---|
| `storeOrders(id)` → `/stores/$id/orders` | `myStoreOrders(id)` → `/me/stores/$id/orders` |
| `storeSettingsEmergencyClose(id)` → `/stores/$id/settings/emergency-close` | `myStoreEmergencyClose(id)` → `/me/stores/$id/emergency-close` |

Nếu code Flutter vô tình dùng constant sai → 404. Nên xóa hoặc deprecate `storeOrders` và `storeSettingsEmergencyClose`.

### 4.3. ⚠️ cart.routes.ts hoàn toàn trống
File `backend/src/modules/orders/cart.routes.ts` chỉ chứa:
```ts
export async function cartRoutes(_app: FastifyInstance) {}
```
Toàn bộ cart API (6 endpoints: GET/PUT /me/cart, POST/PATCH/DELETE /me/cart/items) chưa implement.

### 4.4. ⚠️ Nhiều customer-side order endpoints thiếu trong backend
`order.routes.ts` chỉ implement phía quán. Thiếu phía khách:
- `POST /orders` — tạo đơn
- `GET /me/orders` — danh sách đơn của user
- `GET /orders/:id` — chi tiết đơn
- `POST /orders/:id/report-paid` — báo đã CK
- `POST /orders/:id/cancel` — khách hủy
- `POST /orders/:id/confirm-received` — khách xác nhận nhận hàng

Và phía quán còn thiếu:
- `POST /orders/:id/confirm-money-received`
- `POST /orders/:id/report-payment-not-received`

### 4.5. Routes trong mobile nhưng không có trong spec
- `orderReturnToPending(id)` → `/orders/$id/return-to-pending` — không có trong spec, không có trong backend
- `setBankReceipt(id)` → `/orders/$id/set-bank-receipt` — spec dùng `report-paid` thay thế; endpoint này không có trong backend
- Cả hai chỉ khai báo trong ApiEndpoints, chưa được gọi từ Flutter code → chưa breaking nhưng gây nhầm lẫn

### 4.6. `POST /stores` chưa có trong stores.routes.ts
Spec yêu cầu `POST /stores` để tạo quán. Backend chưa implement. (user cần xem xét có cần thiết hay không trong phase hiện tại)

### 4.7. File không trùng lặp
Không phát hiện file trùng lặp có vấn đề. Có `user.model.ts` và `user.types.ts` trong cùng thư mục users — đây là 2 file riêng biệt (model schema và TypeScript types), không trùng.

---

## Trạng thái các route được user chỉ định

| Route (user correction) | Backend hiện tại | Trạng thái |
|---|---|---|
| `GET /me/stores/:id/orders?tab=...` | ✅ Implemented | ĐÚNG |
| `PATCH /me/stores/:id/emergency-close` | ✅ Implemented | ĐÚNG |
| `PATCH /orders/:id/accept` | ✅ Implemented | ĐÚNG |
| `PATCH /orders/:id/reject` | ✅ Implemented | ĐÚNG |
| `PATCH /orders/:id/deliver` | ✅ Implemented | ĐÚNG |
| `PATCH /orders/:id/complete` | ✅ Implemented | ĐÚNG |
