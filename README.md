# 🌿 Quản Lý Rau — Sổ Sách Cho Tiểu Thương Rau Củ

> Một ứng dụng Flutter + Supabase **cho bác tiểu thương rau cỏ tuổi trung niên / cao tuổi**, theo đúng quy trình làm việc thật ngoài chợ Việt:

```
🌅 SÁNG ở chợ            🌆 TỐI ở nhà
Nhập nhanh:              Chốt giá & xem lời lỗ:
  • Nhà cung cấp (từ danh bạ 📱)   • Tổng tiền bán được hôm nay
  • Mặt hàng                       • Lợi nhuận mong muốn → app tính
  • Số lượng                        GIÁ ĐỀ XUẤT để gọi chốt với NCC
  (KHÔNG nhập giá)                • Nhập giá đã chốt → cập nhật sổ nợ
```

**4 tab chính (chữ to, nút to, độ tương phản cao):**

| Tab | Màn hình | Chức năng |
|---|---|---|
| 📥 **Nhập Hàng** | Màn 1 | Ghi phiếu nhập sáng — không cần giá |
| 💬 **Chốt Giá** | Màn 2 | Chốt giá buổi tối + máy tính "giá đề xuất" |
| 📒 **Sổ Nợ** | Màn 3 | Nợ từng nhà cung cấp + nút 💵 Trả Tiền |
| 📊 **Báo Cáo** | Màn 4 | Tổng thu / tổng vốn / lợi nhuận ròng / top rau lời |

---

## ✨ Tính năng chính

1. **📱 Chọn nhà cung cấp từ danh bạ điện thoại**
   - `flutter_contacts` + `permission_handler` (quyền `READ_CONTACTS` đã khai trong `AndroidManifest.xml`).
   - Tự rút `displayName` + số điện thoại đầu tiên → lưu thẳng vào bảng `suppliers`.
2. **Nhập hàng 3 bước** (Sáng ở chợ): Nhà cung cấp → Mặt hàng → Số lượng. Mặc định `is_price_settled = FALSE`, **không nhập giá**.
3. **Chốt giá buổi tối** với máy tính gợi ý:
   `Giá đề xuất = (Tổng tiền thu được − Lợi nhuận mong muốn) ÷ Số lượng`
   → gọi điện thoại chốt giá với nhà cung cấp → nhập `final_cost` → phiếu chuyển `is_price_settled = TRUE`, nợ NCC tự cập nhật.
4. **Sổ Nợ & Trả tiền**: nợ NCC = Σ(giá trị phiếu đã chốt) − Σ(đã trả); nút "💵 Trả Tiền" ghi vào bảng `payments`.
5. **Báo cáo lời lỗ**: Tổng Thu (đ), Tổng Vốn, Lợi Nhuận Ròng (đỏ khi lỗ), **Top loại rau lời nhất** (Hôm nay / 7 ngày / 30 ngày).
6. **Offline-first**: danh sách nhà cung cấp / mặt hàng / phiếu chờ được cache trên máy; phiếu nhập lúc **mất mạng** được giữ trong hàng đợi và **tự đồng bộ** khi có mạng (banner vàng + nút "Đồng bộ").
7. **UI thân thiện người lớn tuổi**: font ≥ 18pt, số tiền ≥ 24pt, nút ≥ 56–72dp, màu chính xanh lá `#2D6A4F`, toàn bộ nhãn tiếng Việt.

---

## 🛠 Công nghệ

| Thành phần | Chọn |
|---|---|
| Ngôn ngữ | Flutter (Dart ≥ 3.4) |
| Backend / DB | Supabase (PostgreSQL + PostgREST) |
| State | Provider (ChangeNotifier) |
| Cache cục bộ | shared_preferences |
| Danh bạ | flutter_contacts + permission_handler |
| Mạng | connectivity_plus (banner offline) |

---

## 🚀 Bắt đầu (5 bước)

### 1. Yêu cầu
- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.22 (`flutter doctor`)
- Android Studio / Android SDK
- Tài khoản [Supabase](https://supabase.com) (gói Free là đủ)

### 2. Tạo database trên Supabase
1. Tạo project → mở **SQL Editor**.
2. Dán toàn bộ nội dung file **`supabase/migrations/0001_init.sql`** → **Run**.
3. Vào **Settings → API**: copy **Project URL** và **anon public key**.

### 3. Cấu hình khoá
Cách nhanh (sửa file trước khi build):

```dart
// lib/core/config.dart
static const String supabaseUrl = 'https://YOUR-PROJECT-REF.supabase.co';
static const String supabaseAnonKey = 'eyJhbGciOi...';
```

Cách chuẩn (không commit khoá — khuyến nghị):

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

> ⚠️ Nếu màn hình đầu tiên hiện hướng dẫn 3 bước nghĩa là khoá vẫn còn là placeholder.

### 4. (Nếu thiếu) sinh lại Gradle wrapper
Repo này **không commit file nhị phân** `gradle-wrapper.jar`. Nếu máy bạn chưa có nó, chạy một lần tại thư mục gốc:

```bash
flutter create --platforms android --org com.quanlyrau .
```

Lệnh trên chỉ **bổ sung các file còn thiếu** (wrapper, `.metadata`…) và **không ghi đè** mã nguồn đã có (`AndroidManifest.xml`, `MainActivity.kt`, `lib/`…).

### 5. Chạy thử
```bash
flutter pub get
flutter run
```

---

## 📦 Đóng gói APK

```bash
# APK debug (thử nhanh)
flutter build apk --debug

# APK release (nhớ ký keystore trước — xem flutter.dev/deployment/android)
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

APK nằm tại `build/app/outputs/flutter-apk/app-release.apk`.

**Quyền & lưu ý Android:**
- `AndroidManifest.xml` đã khai `READ_CONTACTS` + `INTERNET`.
- Lần đầu bấm "📱 Chọn Từ Danh Bạ", hệ thống hỏi quyền; nếu từ chối vĩnh viễn, app có nút đưa thẳng vào Cài Đặt.
- `minSdk = 23`, hỗ trợ Android 6.0+ (bao gồm máy cũ giá rẻ).

---

## 🗄 Cấu trúc mã nguồn

```
lib/
├─ main.dart                    # Khởi động: Supabase, connectivity, DI
├─ app.dart                     # MultiProvider + MaterialApp + theme
├─ core/
│  ├─ config.dart               # SUPABASE_URL / ANON_KEY (--dart-define)
│  ├─ theme.dart                # Bảng màu #2D6A4F + kiểu chữ to
│  ├─ format.dart               # money() 1.234.000 ₫, ngày giờ, phân tích số
│  └─ widgets.dart              # BigButton, KpiCard, ErrorBanner…
├─ data/
│  ├─ models.dart               # Supplier, Product, PurchaseOrder, Payment…
│  ├─ local_store.dart          # Cache + hàng đợi offline (shared_preferences)
│  ├─ errors.dart               # AppException / OfflineException
│  ├─ suppliers_repo.dart       # NCC (cache-fallback, khử trùng theo tên/SĐT)
│  ├─ products_repo.dart        # Mặt hàng
│  ├─ purchases_repo.dart       # Phiếu nhập: quickImport / settle / pending
│  ├─ payments_repo.dart        # Khoản trả nợ
│  ├─ ledger.dart               # Tính nợ: Σ(phiếu đã chốt) − Σ(đã trả)
│  ├─ analytics_repo.dart       # Tổng thu/vốn/lời + top sản phẩm
│  └─ sync_service.dart         # Đẩy phiếu nhập offline lên Supabase
├─ services/
│  ├─ supabase_service.dart     # Khởi tạo client (không crash khi offline)
│  ├─ app_services.dart         # Composition root (DI)
│  ├─ contacts_service.dart     # Danh bạ + quyền
│  └─ connectivity_service.dart # Trạng thái mạng
└─ screens/
   ├─ home_shell.dart           # 4 tab lớn + banner offline
   ├─ quick_import/             # MÀN 1 + chọn NCC/mặt hàng
   ├─ settlement/               # MÀN 2 + máy tính chốt giá
   ├─ debts/                    # MÀN 3 + sheet trả tiền
   ├─ dashboard/                # MÀN 4 báo cáo
   ├─ shared/contact_selector.dart
   └─ setup/setup_screen.dart   # Hướng dẫn khi thiếu cấu hình
```

---

## 🗄 Cơ sở dữ liệu (tóm tắt)

Xem đầy đủ: **`supabase/migrations/0001_init.sql`**

- `suppliers` — nhà cung cấp (`name`, `phone`, `address`)
- `products` — mặt hàng (`name`, `unit` = kg/bó/cân…)
- `purchase_orders` — phiếu nhập; `quantity`, `import_date`, `is_price_settled` (FALSE khi mới nhập), `final_cost`, `total_sales_amount`
- `payments` — sổ trả nợ (`amount`, `payment_date`, `notes`)
- `daily_profit_report` — view lợi nhuận theo ngày

**Cách tính nợ** (không cần bảng ledger riêng):
```
Nợ NCC = Σ(quantity × final_cost của phiếu ĐÃ chốt) − Σ(payments.amount)
```

---

## 🔐 Bảo mật (đọc kỹ trước khi dùng thật)

Ứng dụng thiết kế cho **1 điện thoại / 1 chủ sạp**, schema chạy ngay với anon key
(RLS tắt). Điều đó nghĩa là **bất kỳ ai có anon key đều đọc/ghi được DB**.

Nếu bạn cần nhiều người dùng hoặc dữ liệu nhạy cảm:

1. Thêm cột `owner_id uuid NOT NULL DEFAULT auth.uid()` vào **mọi bảng**.
2. `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;` và tạo policy `FOR ALL USING (owner_id = auth.uid())` (mẫu đã comment sẵn cuối file SQL).
3. Bật **Anonymous sign-ins** trong Supabase Auth (app đã gọi `signInAnonymously()` khi có mạng).
4. Không bao giờ đưa `service_role` key vào app.

---

## 🧪 Kiểm thử

```bash
flutter test   # test đơn vị: định dạng tiền VNĐ, phân tích số, ngày
```

## 📄 Giấy phép
MIT
