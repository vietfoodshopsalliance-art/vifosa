# Bàn giao: Phát triển iOS trên MacBook — App Vifosa

> Ngày bàn giao: 30/05/2026  
> Người bàn giao: dmtri.nc@gmail.com  
> Dự án: Vifosa — Viet Food Shops Alliance (đặt đồ ăn TPHCM)

---

## 1. Tổng quan dự án

Monorepo gồm 3 phần:

| Phần | Công nghệ | Thư mục |
|------|-----------|---------|
| Mobile app | Flutter 3.x + Dart | `mobile/` |
| Backend API | Fastify 5 + TypeScript + MongoDB | `backend/` |
| Web dashboard | Next.js 16 App Router + Tailwind v4 | `web/` |

Backend production chạy trên Render: `https://vifosa-backend.onrender.com`

**Nhiệm vụ bàn giao:** Chạy và build app Flutter trên iPhone (iOS) từ MacBook.

---

## 2. Yêu cầu máy MacBook

### 2.1 Phần mềm cần cài

```bash
# 1. Xcode — bắt buộc để build iOS
# Tải từ Mac App Store (miễn phí, ~7GB)
# Sau khi cài xong, mở Xcode một lần để chấp nhận license

# 2. Xcode Command Line Tools
xcode-select --install

# 3. CocoaPods — quản lý dependency iOS
sudo gem install cocoapods
# Hoặc dùng Homebrew:
brew install cocoapods

# 4. Flutter SDK
# Tải tại: https://docs.flutter.dev/get-started/install/macos
# Giải nén vào ~/development/flutter
# Thêm vào PATH trong ~/.zshrc:
export PATH="$HOME/development/flutter/bin:$PATH"

# 5. Kiểm tra môi trường
flutter doctor
# Phải xanh hết ở mục: Flutter, Xcode, iOS toolchain
```

### 2.2 Kiểm tra phiên bản

```bash
flutter --version   # >= 3.19
dart --version      # >= 3.0
xcodebuild -version # >= 15.x (iOS 17 SDK)
pod --version       # >= 1.15
```

---

## 3. Lấy source code

```bash
# Clone repo (yêu cầu quyền truy cập từ owner)
git clone <URL_REPO>
cd vifosa

# Hoặc nếu đã có repo, pull code mới nhất
git checkout master
git pull origin master
```

> **Lưu ý:** Liên hệ dmtri.nc@gmail.com để được thêm vào repo GitHub.

---

## 4. Cài đặt dependencies

```bash
cd mobile

# Cài Flutter packages
flutter pub get

# Cài iOS pods (bắt buộc lần đầu và khi thêm package mới)
cd ios
pod install
cd ..
```

---

## 5. Cấu hình file nhạy cảm (KHÔNG có trong git)

Các file sau cần được nhận riêng qua email/Zalo từ owner:

| File | Đặt tại | Mô tả |
|------|---------|-------|
| `google-services.json` | `mobile/android/app/` | Firebase Android |
| `GoogleService-Info.plist` | `mobile/ios/Runner/` | Firebase iOS — **quan trọng** |
| `.env` hoặc config API | `mobile/lib/core/` | Base URL backend |

### 5.1 Thêm GoogleService-Info.plist vào Xcode

```
1. Mở Xcode: open mobile/ios/Runner.xcworkspace
2. Kéo file GoogleService-Info.plist vào thư mục Runner trong Project Navigator
3. Chọn "Copy items if needed" → Add
```

---

## 6. Chạy app trên iOS Simulator

```bash
cd mobile

# Xem danh sách simulator
flutter emulators

# Mở simulator iPhone (ví dụ iPhone 15)
flutter emulators --launch apple_ios_simulator

# Chạy app
flutter run
# Hoặc chọn device cụ thể:
flutter run -d "iPhone 15"
```

---

## 7. Chạy app trên iPhone thật

### 7.1 Yêu cầu

- Có **Apple Developer Account** (Free account cũng chạy được để test, nhưng giới hạn 7 ngày)
- Cắm iPhone vào MacBook qua cáp USB
- Trên iPhone: **Tin tưởng** máy tính khi được hỏi

### 7.2 Cấu hình trong Xcode

```
1. Mở: open mobile/ios/Runner.xcworkspace
2. Chọn project Runner → Signing & Capabilities
3. Team: đăng nhập Apple ID của bạn
4. Bundle Identifier: com.vifosa.app (giữ nguyên)
5. Chọn iPhone thật trong dropdown device
6. Nhấn ▶ Run (hoặc Cmd+R)
```

### 7.3 Trust app trên iPhone

```
iPhone → Cài đặt → VPN & Quản lý thiết bị → [Tên Apple ID] → Tin tưởng
```

---

## 8. Build release (TestFlight / App Store)

> Yêu cầu: Apple Developer Program trả phí ($99/năm) + được owner thêm vào App Store Connect.

```bash
# Build file .ipa
flutter build ipa --release

# File output tại:
# mobile/build/ios/ipa/vifosa.ipa
```

Upload lên TestFlight qua Xcode → Product → Archive → Distribute App.

---

## 9. Cấu trúc code chính (thư mục `mobile/lib/`)

```
lib/
├── core/
│   ├── api/          # Dio HTTP client, interceptor JWT
│   ├── auth/         # JWT, refresh token, flutter_secure_storage
│   └── routing/      # go_router — toàn bộ routes app
├── features/
│   ├── home/         # Màn hình chính, danh sách quán
│   ├── order/        # Đặt món, giỏ hàng, tracking đơn
│   ├── store/        # Trang quán, menu, đánh giá
│   ├── auth/         # Đăng nhập, đăng ký
│   └── profile/      # Tài khoản, lịch sử, cài đặt
└── main.dart
```

---

## 10. Tính năng đã hoàn thành

- [x] Đăng nhập / đăng ký (JWT + refresh token)
- [x] Trang chủ — danh sách quán gần đây, trending, yêu thích
- [x] Xem menu quán, thêm vào giỏ hàng
- [x] Đặt hàng (user đã đăng nhập + khách vãng lai)
- [x] Tracking đơn hàng real-time (Socket.IO)
- [x] Thông báo push (FCM) — âm thanh tuỳ chỉnh
- [x] Hồ sơ người dùng, lịch sử đơn hàng
- [x] Bản đồ OSM (flutter_map)

---

## 11. Các lệnh thường dùng

```bash
# Chạy debug
flutter run

# Xem log khi đang chạy
flutter logs

# Build Android APK (để test nhanh)
flutter build apk --debug

# Dọn cache khi có lỗi lạ
flutter clean && flutter pub get && cd ios && pod install && cd ..

# Cập nhật packages
flutter pub upgrade

# Kiểm tra lỗi code
flutter analyze
```

---

## 12. Lỗi thường gặp & cách xử lý

| Lỗi | Nguyên nhân | Cách xử lý |
|-----|------------|------------|
| `CocoaPods not found` | Chưa cài pod | `sudo gem install cocoapods` |
| `Unable to boot simulator` | Xcode chưa setup đầy đủ | Mở Xcode → Settings → Platforms → cài iOS |
| `No provisioning profile` | Chưa sign Xcode | Vào Signing & Capabilities, chọn Team |
| `Firebase not configured` | Thiếu GoogleService-Info.plist | Xin file từ owner |
| `Pod install failed` | Conflict version | `cd ios && pod repo update && pod install` |
| App crash ngay khi mở | API URL sai | Kiểm tra base URL trong `core/api/` |

---

## 13. Liên hệ

- **Owner / Tech Lead:** dmtri.nc@gmail.com
- **Backend production:** https://vifosa-backend.onrender.com
- **Repo:** liên hệ owner để lấy URL

---

> Khi gặp vấn đề không giải quyết được, chụp màn hình terminal lỗi và gửi cho owner.
