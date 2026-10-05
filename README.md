# CoinPulse ⚡

> **Ứng dụng theo dõi Top Coin tăng giá mạnh nhất trên Binance Spot theo thời gian thực (Real-time 24H Top Gainers) với hệ thống cảnh báo đa mốc và tiến trình chạy ngầm 24/7.**

---

## 🚀 Tính năng nổi bật

- **Bảng xếp hạng Top Gainers thời gian thực**:
  - Dữ liệu trực tiếp từ **Binance Spot** (không qua trung gian, không cần API Key).
  - Khởi tạo snapshot bằng Binance REST API (`/api/v3/ticker/24hr`), cập nhật delta qua WebSocket (`!miniTicker@arr`).
  - Tần suất render mượt mà ~1 giây/lần, nhãn `MỚI` khi coin mới lọt Top, chỉ báo tăng/giảm thứ hạng.
- **Cảnh báo bùng nổ đa mốc (Multi-milestone Alerts)**:
  - Chọn đồng thời nhiều mốc tăng trưởng (ví dụ: `+15%`, `+20%`, `+30%`, `+50%`...).
  - Chip bấm chọn nhanh tiện lợi và ô nhập mốc tùy ý (vd: `12.5%`).
  - **Báo động bậc thang**: Gửi thông báo riêng cho từng mốc khi coin vượt qua, chống spam lặp lại và tự động reset mốc khi coin pullback để sẵn sàng cho nhịp tăng tiếp theo.
- **Chạy ngầm 24/7 (Android Foreground Service)**:
  - Sử dụng `CoinPulseBackgroundService` với `android:foregroundServiceType="dataSync"`.
  - Giữ kết nối WebSocket và kiểm tra biến động liên tục ngay cả khi khóa màn hình hoặc chuyển app.
  - Thông báo heads-up ưu tiên cao (`IMPORTANCE_HIGH`) kèm rung và chuông báo.
- **Chart nến Realtime đầy đủ (V1 Next)**:
  - Xem biểu đồ nến (Candlestick) chạy trực tiếp theo từng tick giá Binance Spot.
  - Hỗ trợ 9 khung thời gian: `1m`, `3m`, `5m`, `15m`, `30m`, `1h`, `4h`, `1d`, `1w`.
  - Tự động tải nến quá khứ vô hạn khi vuốt sang trái.
  - Phóng to/thu nhỏ (pinch-to-zoom) và cuộn lịch sử mượt mà với gia tốc quán tính.
  - Crosshair tương tác: chạm để xem chính xác O/H/L/C, % tăng giảm, Volume và mốc thời gian.
  - Cột khối lượng (Volume bars) đồng bộ màu sắc nến.
  - Đánh dấu đỉnh/đáy (High/Low) của vùng hiển thị.
  - Đường giá hiện tại nét đứt kèm đồng hồ đếm ngược đóng nến (`countdown`).
- **Chỉ báo Order Flow Imbalance Finder (OFIF)**:
  - Tái tạo chuẩn thuật toán indicator Pine Script của Turk viết hoàn toàn bằng Pure Dart.
  - Tự động phát hiện vùng Top Imbalance (vùng bán / Supply) và Bottom Imbalance (vùng mua / Demand) từ 3 nến liên tiếp.
  - Vùng Imbalance tự động kéo dài sang phải theo nến realtime và tự cắt ngắn (`f_choppedoffimb`) khi nến mới xuyên thủng biên.
  - Giới hạn 50 vùng đồng thời, lọc nến xác nhận (`confirmedOnly`) chống nhiễu.
  - Nút bấm `OFIF` bật/tắt tức thì trên cả chế độ dọc và toàn màn hình xoay ngang.
- **Bộ lọc thông minh & Cài đặt linh hoạt**:
  - Tự động loại bỏ Stablecoin và Leveraged tokens (`UP/DOWN`).
  - Lọc ngưỡng thanh khoản tối thiểu (mặc định: `5.000.000 USDT`).
  - Tùy chỉnh danh sách loại trừ (Blacklist) và số lượng hiển thị (Top 5 - 50).
- **Giao diện Tiếng Việt hoàn chỉnh**:
  - Tối ưu trải nghiệm cho người dùng Việt Nam nhưng vẫn giữ chuẩn các thuật ngữ crypto quốc tế (`USDT`, `Volume`, `24H`, `Binance`, `WebSocket`).

---

## 🛠 Kiến trúc hệ thống

```
           +-----------------------------------------------+
           |               Binance Spot API                |
           +-----------------------------------------------+
                 | (REST seed)                   | (miniTicker WebSocket)
                 v                               v
           +-----------------------------------------------+
           |               Market Coordinator              |
           +-----------------------------------------------+
                 |                               |
                 v (Normalize & Merge)           v (Evaluate Milestones)
           +--------------------+         +--------------------+
           |    Ticker Cache    |         |    Alert Service   |
           +--------------------+         +--------------------+
                 | (Filter & Sort)               | (Local Notification)
                 v                               v
           +--------------------+         +--------------------+
           |   Ranking Engine   |         | Foreground Service |
           +--------------------+         +--------------------+
                 |
                 v
           +--------------------+
           |  Flutter UI (VN)   |
           +--------------------+
```

---

## 📱 Cài đặt & Chạy ứng dụng

### 1. Yêu cầu môi trường
- Flutter SDK (≥ 3.19)
- Android SDK (API 34+) & Java 17
- Thiết bị Android bật chế độ **USB Debugging**

### 2. Chạy thử nghiệm trên máy thật / giả lập
```bash
flutter run
```

### 3. Build bản phát hành (Release APK)
```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH

cd android && ./gradlew assembleRelease --console=plain
```

### 4. Cài đặt trực tiếp vào điện thoại qua ADB
```bash
adb install -r -d build/app/outputs/flutter-apk/app-release.apk
```

---

## 📁 Cấu trúc thư mục

- `lib/`
  - `data/`: REST API client và WebSocket stream manager kết nối Binance.
  - `models/`: Cấu trúc dữ liệu Ticker, Symbol, Cấu hình app (`AppConfig`).
  - `ranking/`: Thuật toán lọc thanh khoản, blacklist và xếp hạng 24H gainers.
  - `services/`: `MarketCoordinator` điều phối dữ liệu, `AlertService` quản lý cảnh báo đa mốc.
  - `storage/`: `SettingsRepository` lưu cấu hình với `shared_preferences`.
  - `ui/`: Màn hình chính (`HomeScreen`), màn hình cài đặt (`SettingsScreen`), custom widgets.
- `android/`: Mã nguồn native Android (Foreground Service, Notification channels, Permissions).
- `spec/md/`:
  - `SPEC-3.md`: Tài liệu đặc tả sản phẩm chi tiết.
  - `TECHNICAL.md`: Ghi chú kỹ thuật, schema lưu trữ và thông số luồng dữ liệu.

---

## 📄 Bản quyền
Phát triển cho mục đích cá nhân, hoàn toàn mã nguồn mở và miễn phí.
