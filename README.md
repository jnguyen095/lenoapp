# Leno POS — ứng dụng Flutter (điện thoại & máy tính bảng)

Ứng dụng gọi món cho nhân viên quán, nối với web POS Leno (CodeIgniter, `D:\xampp\htdocs\leno`)
qua API `/api/v1`. Phiên bản đầu gồm phần **POS: sơ đồ bàn & đơn hàng**:

- Đăng nhập bằng tài khoản web (quyền theo "Gán quyền menu": *Bàn* và *Đơn hàng*).
- Sơ đồ bàn tự làm mới mỗi 15 giây, lọc Trống / Có khách, bàn Mang đi.
- Mở bàn, chuyển bàn, gộp bàn (nhấn giữ bàn đang có khách).
- Gọi món: tìm món không cần dấu, lọc danh mục, bấm để thêm 1, nhấn giữ để chọn số lượng + ghi chú.
- Món đã gọi: đánh số, − / +, ghi chú món, hủy món, ghi chú đơn, đánh dấu "Chưa báo".
- Báo bếp (tạo phiếu cho màn hình Pha chế), thanh toán Tiền mặt / Chuyển khoản / Thẻ / QR với gợi ý mệnh giá và tiền thối.
- Tablet ngang (≥ 760 px): thực đơn và món đã gọi cạnh nhau; điện thoại: 2 tab.

- In qua máy in nhiệt LAN: phiếu bếp tách theo danh mục ra từng máy, phiếu tạm tính, hóa đơn (xem **Máy in** bên dưới).

Chưa có trong bản này: màn hình Pha chế, kho, quản trị thực đơn.

## Máy in (LAN)

Dùng máy in nhiệt ESC/POS cắm dây mạng (Xprinter, Epson TM, Rongta…), in qua cổng TCP 9100.
Phiếu được vẽ thành ảnh rồi mới gửi đi, nên tiếng Việt luôn đúng dấu, không cần chỉnh bảng mã.

Cài trên mỗi máy tính bảng: nút tài khoản (góc phải) → **Cài đặt máy in**.

1. **Thêm máy in**: nhập IP (in trang tự kiểm tra của máy in để xem IP, nên đặt IP tĩnh) hoặc bấm
   **Dò máy in trong mạng LAN**. Chọn khổ giấy 80 mm / 58 mm, rồi bấm **In thử**.
2. **Chọn danh mục cho từng máy**: vd *Quầy bar* chọn Cà phê, Trà sữa, Nước ép; *Bếp* chọn Đồ ăn vặt.
   Một danh mục có thể in ra nhiều máy. Bật **Máy bếp mặc định** cho một máy để nhận các danh mục chưa gán.
3. Bật **In hóa đơn / phiếu tạm tính** cho máy ở quầy thu ngân.
4. Mục **Máy in theo danh mục** cho thấy mỗi danh mục đang in ra máy nào (màu đỏ = chưa có máy).

Khi dùng:
- **Báo bếp** → tự in phiếu bếp, mỗi máy chỉ nhận món thuộc danh mục của nó (tắt được ở "Tự động in").
- Nút 🧾 trên màn hình đơn → **In tạm tính**; đơn đã thanh toán → **In lại hóa đơn**.
- **Thanh toán** → tự in hóa đơn; hộp thoại thanh toán xong có nút **In hóa đơn** để in thêm.
- Máy in lỗi/tắt → báo đỏ kèm nút **In lại**; đơn và báo bếp vẫn được lưu bình thường.

Cài đặt máy in lưu trên từng máy (không đồng bộ qua máy chủ).

### Máy in USB (máy POS / máy tính bảng Android)

1. Cắm máy in vào cổng USB của máy POS (máy tính bảng cần cáp OTG). Android có thể hỏi
   "Mở Leno POS khi cắm thiết bị này?" — chọn **Luôn luôn** để không phải cấp quyền lại.
2. **Thêm máy in** → **Kết nối: USB** → **Chọn máy in USB** → chọn máy trong danh sách → **Cho phép**.
3. Chọn khổ giấy, danh mục, bật "In hóa đơn" nếu là máy thu ngân như máy LAN, rồi **In thử**.

Máy LAN và máy USB dùng chung được (vd máy bếp LAN + máy thu ngân USB). Hỗ trợ máy in nhiệt USB
khai báo lớp Printer hoặc "vendor specific" (Xprinter, Epson TM, Rongta…). Máy in tích hợp sẵn trong
một số máy POS (Sunmi…) dùng dịch vụ riêng của hãng nên có thể không hiện trong danh sách.
USB chỉ chạy trên Android (bản Windows dùng máy LAN).

## Kiểm tra bố cục & mẫu phiếu

Chụp các màn hình (điện thoại, tablet dọc, tablet ngang) và các mẫu phiếu in bằng dữ liệu giả:

```bash
flutter test tool/screenshots_test.dart
```

Cần biến môi trường `FLUTTER_ROOT` trỏ tới thư mục Flutter SDK. Ảnh ra `build/screenshots/`.

## Cài đặt lần đầu

1. Cài Flutter (bản stable mới nhất): https://docs.flutter.dev/get-started/install/windows
   rồi kiểm tra bằng `flutter doctor`.
2. Tạo thư mục android/ios và chỉnh cấu hình mạng (chạy một lần):

   ```bash
   powershell -ExecutionPolicy Bypass -File tool\setup_platforms.ps1
   ```

   Script chạy `flutter create` (không ghi đè `lib/`, `pubspec.yaml`, `test/`), thêm quyền INTERNET và
   cho phép `http://` tới máy chủ trong mạng LAN.
3. Chạy trên máy/emulator:

   ```bash
   flutter run
   ```

4. Kiểm tra mã:

   ```bash
   flutter analyze
   ```

   ```bash
   flutter test
   ```

## Máy chủ

Ở màn hình đăng nhập bấm **Máy chủ** để đổi địa chỉ:

| Môi trường | Địa chỉ |
| --- | --- |
| Production | `https://leno.pickangelpark.com` (mặc định) |
| XAMPP trên máy tính, điện thoại cùng Wi-Fi | `http://<IP máy tính>/leno`, vd `http://192.168.1.10/leno` |
| Android emulator → XAMPP cùng máy | `http://10.0.2.2/leno` |

Máy chủ phải đã chạy migration 002 (bảng `api_tokens`): `php index.php migrate`
(trên host không có SSH thì dùng `Migrate_runner` như lần trước).

## API `/api/v1` (phía máy chủ)

Mọi request trừ đăng nhập gửi header `Authorization: Bearer <token>`. Lỗi trả về
`{"success": false, "message": "..."}` (message tiếng Việt, hiển thị thẳng cho nhân viên)
với mã 401 (hết phiên), 403 (không có quyền), 404, 409 (bàn/đơn đã đổi trạng thái), 422 (dữ liệu sai).

| Method | Đường dẫn | Body | Trả về |
| --- | --- | --- | --- |
| POST | `auth/login` | `username, password, device_name` | `token, user` |
| POST | `auth/logout` | | |
| GET | `me` | | `user` (kèm `permissions.tables/orders`), `settings` |
| GET | `tables` | | `tables[]` (kèm đơn đang mở) |
| POST | `tables/{id}/open` | | đơn |
| POST | `tables/{id}/transfer` | `target_table_id` | `tables[]` |
| POST | `tables/{id}/merge` | `target_table_id` | đơn đích |
| GET | `menu` | | `categories[].products[]` |
| GET | `orders/active` | | `orders[]` |
| GET | `orders/history?date=YYYY-MM-DD` | | đơn người đăng nhập tạo trong ngày (mặc định hôm nay) + `summary` |
| GET | `orders/{id}` | | đơn |
| PATCH | `orders/{id}` | `note` | đơn |
| POST | `orders/{id}/items` | `items: [{product_id, qty, note}]` | đơn |
| PATCH | `orders/{id}/items/{item_id}` | `qty` và/hoặc `note` | đơn |
| DELETE | `orders/{id}/items/{item_id}` | | đơn |
| POST | `orders/{id}/notify` | | đơn + `kitchen_slip` |
| GET | `orders/{id}/kitchen-history` | | `history[]` — các lần báo bếp (cả từ web), mới nhất trước |
| POST | `orders/{id}/pay` | `payment_method` (CASH/TRANSFER/CARD/QR), `received_amount` | đơn + `payment` |

"Đơn" = `{order, is_active, items[], pending_count, payment}`. Ảnh món trả về dạng `assets/...`,
ứng dụng tự ghép với địa chỉ máy chủ.

Nghiệp vụ dùng chung với web qua `application/libraries/Pos_service.php`, nên web và ứng dụng luôn
cùng quy tắc (mở bàn, cộng dồn món, báo bếp, hủy món đã báo, thanh toán, chuyển/gộp bàn).

## Cấu trúc

```
lib/
  core/      api_client.dart (Dio + lỗi tiếng Việt), session_store.dart, format.dart
  printing/  print_settings.dart, escpos.dart (lệnh in), ticket.dart (vẽ phiếu), tickets.dart (mẫu phiếu + tách theo danh mục), printer_service.dart (TCP 9100, dò máy in)
  models/    models.dart (khớp JSON của API)
  data/      pos_repository.dart (các lệnh API)
  state/     auth.dart (đăng nhập/phiên), pos.dart (sơ đồ bàn, thực đơn, đơn), printing.dart (cài đặt + lệnh in)
  ui/        layout.dart (cỡ điện thoại/tablet), screens/ (login, home, order, printer_settings, printer_edit), widgets/
tool/        setup_platforms.ps1, screenshots_test.dart
```
