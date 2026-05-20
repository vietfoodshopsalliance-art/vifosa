# Implementation Notes

> Ghi lại các quyết định kỹ thuật, thay đổi so với yêu cầu, và những điều cần biết.
> Cập nhật mỗi khi có thay đổi đáng kể.

---

## 1. Quyết định AI tự ra (spec không nói)

### [2026-05-20] ADB install dùng `--no-streaming`
- **Quyết định:** Dùng `adb install -r --no-streaming` thay vì `flutter run` / `flutter install` mặc định.
- **Lý do:** Debug APK 108 MB bị "Broken pipe (32)" khi streaming install qua ADB trên Windows. `--no-streaming` push file trước, rồi mới install — tránh timeout TCP của streaming protocol.
- **Cách dùng lại:**
  ```
  adb kill-server && adb start-server
  adb -s emulator-5554 install -r --no-streaming build\app\outputs\flutter-apk\app-debug.apk
  ```

---

## 2. Thay đổi so với yêu cầu ban đầu

_(Chưa có thay đổi nào so với spec. Mục này sẽ được cập nhật khi có.)_

---

## 3. Tradeoff AI cân nhắc

### `--no-streaming` vs streaming install
| | Streaming (mặc định) | `--no-streaming` |
|---|---|---|
| Tốc độ | Nhanh hơn (pipe trực tiếp) | Chậm hơn (push + install 2 bước) |
| Độ ổn định | Dễ bị broken pipe với APK lớn trên Windows | Ổn định hơn |
| Incremental install | Hỗ trợ | Không hỗ trợ |
- **Chọn:** `--no-streaming` vì APK debug ~108 MB và môi trường Windows + emulator hay bị timeout.

---

## 4. Điều khác cần biết

### Tình trạng emulator (2026-05-20)
- Emulator: `emulator-5554` (Android)
- Storage `/data`: 86% đã dùng (~845 MB còn lại) — **không phải nguyên nhân lỗi**, nhưng cần chú ý nếu emulator tích dữ liệu thêm.
- APK debug hiện tại: **108 MB** — lớn hơn bình thường do chưa tối ưu (debug build bao gồm cả Dart devtools và symbols).

### Quy tắc làm việc (user yêu cầu)
- Không thay đổi schema, repo, api, backend mà không tóm tắt và hỏi xác nhận trước.
- Báo file trùng lặp nếu phát hiện.
- Báo nội dung mâu thuẫn, không thống nhất giữa các phần của hệ thống.
