# Hướng dẫn Deploy — Vifosa

## Tổng quan hạ tầng

| Service | Tài khoản | URL |
|---------|-----------|-----|
| **Vercel** (web) | `vietfoodshopsalliance-5562` team | https://project-f7r57.vercel.app |
| **Render.com** (backend) | `vietfoodshopsalliance@gmail.com` | https://vifosa-backend.onrender.com |
| **MongoDB Atlas** | `vietfoodshopsalliance_db_user` | Cluster0 (nhw1otx) |
| **GitHub** (source code) | `vietfoodshopsalliance-art` | https://github.com/vietfoodshopsalliance-art/vifosa |
| **Git local** (máy dev) | `dmtri.nc@gmail.com` (dmtrinc) | — |

---

## 1. Deploy Web (Vercel)

### Cách hoạt động
Vercel tự động deploy mỗi khi có push lên branch `master` của GitHub repo — **không cần thao tác thủ công**.

### Quy trình
```bash
# Sửa code trong web/
git add web/...
git commit -m "mô tả thay đổi"
git push origin master
```

Vercel detect push → tự build → deploy lên `https://project-f7r57.vercel.app` trong ~1 phút.

### Lưu ý
- Git commit author là `dmtrinc` (`dmtri.nc@gmail.com`) — **không** deploy bằng Vercel CLI (sẽ bị blocked do email không khớp Git account của team)
- Vercel team: `vietfoodshopsalliance-5562`
- Project name: `project-f7r57`

### Environment Variables trên Vercel
Vào **Vercel Dashboard → project-f7r57 → Settings → Environment Variables**:

| Key | Value |
|-----|-------|
| `NEXT_PUBLIC_API_URL` | `https://vifosa-backend.onrender.com` |
| `NEXT_PUBLIC_APP_URL` | `https://project-f7r57.vercel.app` |

---

## 2. Deploy Backend (Render.com)

### Cách hoạt động
Render tự động deploy khi có push lên `master` (nếu GitHub integration đang bật), hoặc deploy thủ công từ dashboard.

### Quy trình tự động (nếu GitHub integration bật)
```bash
# Sửa code trong backend/
git add backend/...
git commit -m "mô tả thay đổi"
git push origin master
```

### Quy trình thủ công
1. Vào https://dashboard.render.com (đăng nhập `vietfoodshopsalliance@gmail.com`)
2. Chọn service `vifosa-backend`
3. Bấm **Manual Deploy → Deploy latest commit**

### Environment Variables trên Render
Xem và chỉnh tại **Render Dashboard → vifosa-backend → Environment**. Các biến quan trọng:

| Key | Ghi chú |
|-----|---------|
| `NODE_ENV` | `production` |
| `PORT` | `8080` |
| `MONGO_URI` | MongoDB Atlas connection string |
| `JWT_SECRET` | Phải khác với `.env` local |
| `JWT_REFRESH_SECRET` | Phải khác với `.env` local |
| `ALLOWED_ORIGINS` | Phải bao gồm `https://project-f7r57.vercel.app` |
| `CLOUDINARY_*` | Credentials Cloudinary |
| `FIREBASE_*` | Credentials Firebase |

### CORS — quan trọng
`ALLOWED_ORIGINS` trên Render phải có đủ:
```
https://project-f7r57.vercel.app,http://localhost:3000
```

---

## 3. Push lên GitHub

### Thông tin repo
- **URL:** https://github.com/vietfoodshopsalliance-art/vifosa
- **Branch chính:** `master`
- **Git author local:** `dmtri.nc@gmail.com` (dmtrinc)

### Quy trình thông thường
```bash
cd C:/Users/Admin/develop/vifosa

# Kiểm tra thay đổi
git status
git diff

# Stage và commit
git add <files>
git commit -m "loại: mô tả ngắn"

# Push lên GitHub (Vercel/Render tự deploy sau đó)
git push origin master
```

### Cấu trúc repo
```
vifosa/
├── web/        # Next.js 16 — deploy lên Vercel
├── backend/    # Fastify + TypeScript — deploy lên Render
└── mobile/     # Flutter — build riêng
```

---

## 4. Kiểm tra sau deploy

### Web
```
https://project-f7r57.vercel.app/login
```
- Đăng nhập bằng tài khoản admin
- Vào `/admin/stores` kiểm tra danh sách quán

### Backend health check
```
https://vifosa-backend.onrender.com/health
```

### Lưu ý Render cold start
Render (Hobby plan) tắt service sau 15 phút không có request. Lần đầu vào web sau thời gian dài, backend cần ~30 giây để khởi động lại — đây là hành vi bình thường.

---

## 5. Workflow dev local

```bash
# Terminal 1 — backend
cd backend
npm run dev   # localhost:8080

# Terminal 2 — web
cd web
npm run dev   # localhost:3000
```

File `web/.env.local`:
```
NEXT_PUBLIC_API_URL=http://localhost:8080
NEXT_PUBLIC_APP_URL=http://localhost:3000
```
