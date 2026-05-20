# Backlog — Compile Errors & Dead Code

> Cập nhật: 2026-05-20  
> Chạy `flutter analyze --no-pub` để xem toàn bộ danh sách hiện tại.

---

## 1. Dead code — orders/store_orders_screen.dart (12 lỗi)

**File:** `mobile/lib/features/store_dashboard/orders/store_orders_screen.dart`  
**Trạng thái:** Không được router import, đã được thay thế bởi `screens/store_orders.dart`.  
**Nguyên nhân lỗi:** Dùng các named parameter cũ của `OrderCardStore` đã bị xoá khi rewrite:
`showTimer`, `actionRow`, `compact`, `greyed`, `extraContent`  
**Việc cần làm:** Xoá file này hoặc cập nhật lại theo API mới của `OrderCardStore`.

---

## 2. ApiEndpoints thiếu getter/method (pre-existing)

Các file dưới đây dùng method/getter chưa khai báo trong `core/network/api_endpoints.dart`:

| File | Thiếu | Ghi chú |
|------|-------|---------|
| `features/home/screens/favorites_screen.dart:12` | `ApiEndpoints.favorites` | endpoint GET favorites |
| `features/order/checkout_provider.dart:172` | `ApiEndpoints.meAddresses` | đã có `myAddresses` — có thể đổi tên |
| `features/profile/screens/favorites_screen.dart:18,26` | `ApiEndpoints.favorites` | giống home |
| `features/profile/screens/favorites_screen.dart:111,220` | `ApiEndpoints.likeDelete` | endpoint DELETE like |
| `features/social/social_provider.dart:110` | `ApiEndpoints.postLike` | endpoint POST like post |
| `features/store_detail/store_detail_provider.dart:66` | `ApiEndpoints.likeDelete` | endpoint DELETE like |

**Fix nhanh:** Thêm vào `api_endpoints.dart`:
```dart
// Favorites
static const String favorites      = '/me/favorites';

// Likes
static String likeDelete(String id) => '/likes/$id';

// Posts
static String postLike(String id)   => '/posts/$id/like';
```

> `meAddresses` → đổi thành `myAddresses` (đã có sẵn) ở `checkout_provider.dart:172`.

---

## 3. Missing file (pre-existing)

**File gọi:** `features/profile/screens/payment_methods_screen.dart:12`  
**Import bị thiếu:** `../../store_dashboard/providers/payment_methods_provider.dart`  
**Việc cần làm:** Tạo file provider này hoặc trỏ sang provider khác đang tồn tại.

---

## 4. Warnings đáng chú ý (không block build)

| File | Vấn đề |
|------|--------|
| `menu/providers/menu_provider.dart:256` | `onError` handler trả `Future<void>` thay vì `Map` |
| `orders/store_orders_screen.dart:455,458` | `BuildContext` dùng sau async gap |
| `notifications_screen.dart:31` | `onError` handler không trả giá trị |
| `store_detail_screen.dart:244` | `onError` handler không trả giá trị |
