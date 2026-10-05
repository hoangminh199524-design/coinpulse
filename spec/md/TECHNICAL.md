# CoinPulse — Technical Notes (V1)

Tài liệu implementation cho [SPEC-3.md](./SPEC-3.md). SPEC mô tả hành vi quan sát được. File này giữ các tham số và quyết định kỹ thuật, có thể đổi mà không cần sửa SPEC.

## 1. Data source

| Mục | Giá trị |
|---|---|
| REST host | `api.binance.com`, fallback `api1`, `api2`, `api3` |
| Market-data-only host | Dùng làm fallback nếu host chính không tới được |
| WebSocket | `wss://stream.binance.com:9443/ws/!miniTicker@arr`, fallback port `443` |
| Stream dự phòng | `!ticker_1d@arr` (cửa sổ có thể rộng hơn 24h tới gần 60 giây) |

- Trước mỗi release lớn, đối chiếu lại Binance Spot docs về stream và ping/pong.
- Data-source layer phải đổi được stream mà không sửa ranking engine hoặc UI.

## 2. Internal ticker model

Cache chỉ lưu source fields:

- `symbol`, `openPrice`, `currentPrice`, `highPrice`, `lowPrice`, `quoteVolume`, `sourceTimestamp`.

`sourceTimestamp` lấy từ `closeTime` (REST) hoặc `E` (WebSocket).

Derived, tính ở một chỗ duy nhất:

- `priceChangeAmount = currentPrice - openPrice`
- `priceChangePercent = (currentPrice - openPrice) / openPrice × 100`, với `openPrice > 0`

Mapping từ miniTicker: `s→symbol`, `o→openPrice`, `c→currentPrice`, `h→highPrice`, `l→lowPrice`, `q→quoteVolume`, `E→sourceTimestamp`.

Mapping từ REST `ticker/24hr`: `symbol→symbol`, `openPrice→openPrice`, `lastPrice→currentPrice`, `highPrice→highPrice`, `lowPrice→lowPrice`, `quoteVolume→quoteVolume`, `closeTime→sourceTimestamp`.

### Hai model tách biệt

```
SymbolInfo  (từ exchangeInfo)        TickerState (từ REST ticker + WebSocket)
- symbol                              - symbol
- baseAsset                           - openPrice
- quoteAsset                          - currentPrice
- status                              - highPrice
- permissionSets                      - lowPrice
- tickSize                            - quoteVolume
                                      - sourceTimestamp

SymbolInfo + TickerState → Filter → Ranking
```

WebSocket chỉ merge vào `TickerState`, và chỉ khi `sourceTimestamp` mới hơn. Không đụng tới `SymbolInfo`.

## 3. Init / reconnect

1. Mở WebSocket, buffer event.
2. `GET /api/v3/exchangeInfo`, đọc `permissionSets`.
3. `GET /api/v3/ticker/24hr` (weight 80).
4. Normalize REST vào cache.
5. Áp buffer, chỉ nhận event có `E` mới hơn `sourceTimestamp` của symbol.
6. Chuyển sang merge trực tiếp.

Giới hạn buffer: tối đa **30 giây** hoặc **5.000 message**. Chạm ngưỡng thì hủy, đóng connection, backoff, retry từ đầu.

## 4. WebSocket manager

- Một connection duy nhất.
- Reconnect: exponential backoff + jitter.
- Chủ động nối lại trước mốc 24 giờ.
- Ping/pong: server ping khoảng 20 giây, ngắt nếu không pong trong 1 phút. Dùng thư viện Dart xử lý pong đúng protocol.
- Data-silence watchdog: mặc định **10 giây**, đặt ở config của data-source layer.
- Parse JSON trên main isolate trước. Chỉ chuyển sang isolate khi profiling cho thấy parsing ảnh hưởng frame time.

## 5. Ranking và UI

- Tick ranking/UI khoảng **1 giây**, không render theo từng message.
- Sort: `priceChangePercent` giảm dần, rồi `quoteVolume` giảm dần, rồi `symbol` tăng dần.
- List diff theo symbol.
- Rank movement: baseline là ranking đầu tiên sau khi khởi động. Badge giữ 10 giây, reset khi coin đổi hạng tiếp.

## 6. Filter mặc định

- Stablecoin blacklist: `USDC`, `FDUSD`, `TUSD`, `DAI`, `USDP`, `USDE`, `USD1`, `USDS`, `PYUSD`, `AEUR`, `BFUSD`, `XUSD`, `EUR`.
- Leveraged: loại theo `permissionSets` có `LEVERAGED`. Không lọc theo suffix.
- Minimum quote volume: `5,000,000` USDT.

## 7. Settings và storage

- Lưu bằng `shared_preferences`:
  - `setting_top_n`: Top N (int, 5–50, mặc định 10).
  - `setting_min_volume`: Minimum quote volume (double, mặc định 5.000.000 USDT).
  - `setting_blacklist`: Danh sách blacklist base assets (Set/List String, chuẩn hóa chữ hoa).
  - `setting_alert_thresholds_list`: Danh sách các mốc cảnh báo tăng trưởng (List<double>, mặc định `[15.0, 20.0]`).
  - `setting_alert_gain_threshold`: Mốc cảnh báo tương thích ngược (double).
- Top N giới hạn 5–50, mặc định 10 (quy định trong SPEC §17).
- Blacklist: base asset viết hoa (`USDC`), symbol dạng `BTCUSDT`. Chuẩn hóa về chữ hoa khi lưu.
- Backoff, buffer, watchdog không đưa ra UI.

## 8. Background Monitoring & Alert Service (Đã triển khai)

- **Android Foreground Service (`CoinPulseBackgroundService`)**:
  - Service Type: `android:foregroundServiceType="dataSync"`.
  - Notification kênh thường trực: `coinpulse_foreground_channel` (độ ưu tiên LOW/MIN, tránh làm phiền).
  - Tự động duy trì WebSocket connection 24/7 và xử lý dữ liệu ngay cả khi ứng dụng bị thu nhỏ hoặc tắt màn hình.
  - Tự khởi động lại khi thiết bị reboot (`BOOT_COMPLETED`).
- **Cơ chế Báo động Bậc thang (Step-ladder Multi-milestone Alerts)**:
  - Cho phép người dùng cấu hình đồng thời nhiều mốc (ví dụ: `+15%`, `+20%`, `+30%`, `+50%`...).
  - Bộ quản lý trạng thái `AlertService`: duy trì `_triggeredThresholds` (`Map<String, Set<double>>`) theo từng symbol.
  - Khi coin vượt qua mốc nào, hệ thống phát cảnh báo riêng cho mốc đó (`🚀 [SYMBOL] Đạt mốc +15%!`, `🔥 [SYMBOL] Vượt đỉnh +20%!`).
  - ID thông báo: `(symbol.hashCode ^ milestone.hashCode).abs() % 100000` đảm bảo không đè thông báo của mốc khác hoặc coin khác.
  - **Cơ chế Pullback Reset**: Khi giá coin giảm dưới `mốc - 2.0%` hoặc dưới `90% của mốc`, mốc đó được tự động giải phóng (reset) để sẵn sàng báo động lại nếu coin có nhịp bật tăng tiếp theo.
  - Notification channel: `coinpulse_alert_channel` với `IMPORTANCE_HIGH`, bật rung và âm thanh thông báo nổi (heads-up notification).

## 9. Localization (Giao diện Tiếng Việt)

- Toàn bộ giao diện người dùng được Việt hóa trực quan:
  - Màn hình chính: `Top Tăng Trưởng`, `Binance • USDT • Biến Động 24H`, nhãn `MỚI` thay cho `NEW`, trạng thái kết nối `TRỰC TIẾP`, `ĐANG TẢI`, `KẾT NỐI...`, `MẤT MẠNG`.
  - Màn hình Cài đặt: các phân mục `BẢNG XẾP HẠNG`, `BỘ LỌC THANH KHOẢN`, `DANH SÁCH LOẠI TRỪ`, `THỊ TRƯỜNG`, `CẢNH BÁO TĂNG TRƯỞNG`, nút `LƯU CÀI ĐẶT`.
  - Cảnh báo và thông báo nền: thông điệp cảnh báo bằng Tiếng Việt.
- Giữ nguyên các thuật ngữ tài chính / kỹ thuật crypto chuẩn quốc tế:
  - `USDT`, `Volume`/`Vol`, `24H`, `Live`, `Binance`, `WebSocket`.

## 10. Coin Detail & Realtime Candlestick Chart (Đã triển khai)

- **Tầng dữ liệu (Data Layer)**:
  - REST Kline Seed & Pagination: `BinanceRestService.fetchKlines` gọi `/api/v3/klines` lấy 500 nến ban đầu. Khi người dùng vuốt về quá khứ, truyền thêm `endTime = firstOpenTime - 1` để tải tiếp dữ liệu lịch sử không giới hạn.
  - WebSocket Kline Stream: `KlineWsService` kết nối trực tiếp `<symbol>@kline_<interval>`, bắt event `kline`, trích xuất nến `k` và timestamp máy chủ `E` để đồng bộ countdown.
  - Quản lý trạng thái: `ChartController` kế thừa `ChangeNotifier`:
    - Cập nhật nến hiện tại hoặc mở nến mới mượt mà (`applyLiveCandle`).
    - Khử trùng lặp và sắp xếp theo `openTime` (`mergeCandles`).
    - Bù lệch giờ thiết bị (`serverOffsetMs`) để tính countdown đóng nến chính xác tuyệt đối.
    - Tự động resync nến khi kết nối mạng phục hồi.
- **Tầng hiển thị (UI & CustomPainter)**:
  - Widget `CandleChart`: Vẽ trực tiếp qua `CustomPainter` tối ưu 60fps:
    - Nến tăng xanh ngọc (`#0ECB81`), nến giảm đỏ ruby (`#F6465D`).
    - Sub-chart khối lượng (Volume) đặt ở 20% bên dưới, đồng bộ màu theo nến.
    - Lưới tọa độ tự động chia bước giá chuẩn (`_niceStep`) và nhãn thời gian (`_niceCount`).
    - Điểm cực trị: Tự động đánh dấu giá Cao nhất (High) và Thấp nhất (Low) của vùng hiển thị với đường dẫn chỉ hướng.
    - Đường giá hiện tại: Nét đứt ngang, tag giá nổi bật kèm đồng hồ đếm ngược thời gian đóng nến (`countdown`).
    - Thao tác tương tác:
      - Chụm 2 ngón để Phóng to / Thu nhỏ (Pinch-to-zoom).
      - Vuốt ngang để cuộn lịch sử với gia tốc quán tính (`FrictionSimulation`).
      - Chạm 1 ngón để bật/tắt Crosshair: hiển thị đường gióng chữ thập, tag giá, tag thời gian và dải số liệu O/H/L/C/%/Vol chi tiết.
      - Nút tròn "Về hiện tại" xuất hiện khi đang cuộn xem lịch sử.
  - Bộ chọn khung thời gian `IntervalSelector`: Hỗ trợ đầy đủ `1m`, `3m`, `5m`, `15m`, `30m`, `1h`, `4h`, `1d`, `1w`.
  - Chế độ toàn màn hình `ChartFullScreen`: Tự động xoay ngang màn hình (Landscape), ẩn thanh điều hướng hệ thống (Immersive Sticky) cho không gian phân tích tối đa.

## 11. Imbalance Detector (OFIF) — Architecture & Algorithm (Đã triển khai)

- **Pure Dart Indicator Engine (`ImbalanceDetector`)**:
  - Tách biệt hoàn toàn khỏi Widget UI và Chart Engine, cho phép kiểm thử độc lập (unit tests) và mở rộng cho các chỉ báo kỹ thuật khác sau này.
  - Phân tích nến dựa trên 3 nến liên tiếp (`c2 = candle[i-2]`, `c1 = candle[i-1]`, `c0 = candle[i]`):
    - **Top Imbalance**: `c2.low <= c1.open && c0.high >= c1.close`, với `size = c2.low - c0.high > 0`. Tạo zone: `topPrice = c2.low`, `bottomPrice = c0.high`.
    - **Bottom Imbalance**: `c2.high >= c1.open && c0.low <= c1.close`, với `size = c0.low - c2.high > 0`. Tạo zone: `topPrice = c0.low`, `bottomPrice = c2.high`.
- **Zone Lifecycle & Boundary Violation (`f_choppedoffimb`)**:
  - Lưu trữ danh sách active boxes trong bộ nhớ. Mỗi khi duyệt nến tiếp theo `c0`, các zone đang kéo tới nến `i - 1` được kiểm tra:
    - Nếu `(c0.high > zone.topPrice && c0.low < zone.topPrice)` hoặc `(c0.high > zone.bottomPrice && c0.low < zone.bottomPrice)`: Zone bị cắt (`active = false`), dừng mở rộng.
    - Ngược lại: Zone tiếp tục kéo dài sang nến `c0` (`endOpenTime = c0.openTime`).
  - Quản lý giới hạn bộ nhớ: `maxZones = 50` (Pine Script limit), tự động `removeAt(0)` loại bỏ zone cũ nhất khi đầy danh sách.
  - Lọc nến xác nhận: `confirmedOnly = true` (mặc định) bỏ qua nến chưa đóng (`isClosed == false`) ở cuối series để tránh zone xuất hiện rồi biến mất khi giá đang nhảy.
- **Tích hợp vào `ChartController`**:
  - Biến trạng thái: `_imbalanceZones` (`List<ImbalanceZone>`) và `_showImbalance` (`bool`, mặc định `true`).
  - Hàm `toggleImbalance()` cho phép bật/tắt hiển thị tức thì.
  - Tự động gọi `_recalculateImbalances()` khi nến ban đầu load xong, khi nến realtime đóng mở nến mới, hoặc khi phân trang nến lịch sử.
- **Overlay CustomPainter (`_ChartPainter`)**:
  - Render vùng Imbalance bằng `canvas.drawRect`:
    - Top Imbalance: Đỏ ruby bán trong suốt (`#F6465D` với alpha `0.18`), viền nét đứt (dashed stroke) với alpha `0.65`.
    - Bottom Imbalance: Xanh ngọc bán trong suốt (`#0ECB81` với alpha `0.18`), viền nét đứt với alpha `0.65`.
    - Nhãn nhận diện `TOP IMB` / `BOT IMB` nhỏ gọn gắn ở góc box.
  - Sử dụng binary search `findIndex(openTime)` để ánh xạ chính xác tọa độ X của nến bắt đầu và kết thúc ngay cả khi người dùng cuộn hoặc phóng to/thu nhỏ chart.

## 12. Known limitations

- Symbol bị `HALT`/`BREAK` giữa phiên vẫn nằm trong cache tới lần resync tiếp theo.
- Trên iOS, cơ chế Background Execution phụ thuộc vào chính sách Background App Refresh của Apple (Android đã hỗ trợ chạy ngầm 24/7 qua Foreground Service).



