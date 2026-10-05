# Binance Top Gainers — Product Specification

**Current version: V1 — Flutter (Android + iOS)**

## 1. Mục tiêu

Xây dựng một ứng dụng mobile cá nhân bằng **Flutter**, chạy local trên **Android và iOS**.

Mục tiêu chính của ứng dụng:

> Theo dõi và hiển thị **Top 10 đồng coin tăng giá mạnh nhất trong 24 giờ trên Binance**, với dữ liệu tự cập nhật gần realtime khi app đang mở.

“Tăng nhanh nhất” ở V1 nghĩa là **% thay đổi giá cao nhất trên cửa sổ rolling 24 giờ**, cùng kiểu bảng Top Gainers của Binance. Không phải coin vừa nhích trong vài giây, và không phải % trong ngày theo mốc UTC.

Ứng dụng ưu tiên:

- Miễn phí.
- Không cần backend/server riêng.
- Không cần tài khoản Binance.
- Không cần Binance API Key đối với market data public.
- Dữ liệu lấy trực tiếp từ Binance.
- Xử lý và lưu dữ liệu ngay trên điện thoại.
- Kiến trúc đủ đơn giản cho V1 nhưng có thể mở rộng cảnh báo sau này.

---

## 2. Platform

Ứng dụng được phát triển cross-platform bằng:

**Flutter + Dart**

Mục tiêu hỗ trợ từ đầu:

- Android.
- iOS.
- Một codebase chính dùng chung cho cả hai nền tảng.

App là ứng dụng cá nhân, không yêu cầu phát hành lên Google Play Store hoặc App Store trong V1. Có thể build APK cho Android và build iOS bằng môi trường macOS/Xcode.

Không yêu cầu:

- Server.
- Firebase.
- Cloud database.
- V1 yêu cầu kết nối Internet để đọc Binance public market data. Hỗ trợ chạy ngầm 24/7 và thông báo cảnh báo qua Android Foreground Service.

Các phần business logic như REST, WebSocket, ticker cache, filter, ranking và UI ưu tiên code dùng chung bằng Dart. Code native Android được sử dụng cho Foreground Service và Notification Channel.


---

## 3. Nguồn dữ liệu

Nguồn dữ liệu V1:

**Binance Spot Public Market Data**

Không dùng Futures ở V1.

### REST seed là bắt buộc, WebSocket dùng để cập nhật delta

All-market WebSocket **không gửi full universe**. Các stream dạng `@arr` chỉ chứa những symbol vừa thay đổi trong nhịp cập nhật. Vì vậy không được xây universe/cache ban đầu chỉ từ WebSocket.

V1 dùng `!miniTicker@arr` vì đây là stream Spot hiện có trong tài liệu Binance, cập nhật khoảng mỗi 1000 ms và cung cấp đủ dữ liệu để tự tính ranking 24h: `s`, `c`, `o`, `h`, `l`, `q`. App tự tính:

- Price change amount = `c - o`.
- Price change percent = `(c - o) / o × 100`, với điều kiện `o > 0`.

REST `ticker/24hr` và WebSocket `miniTicker` có schema khác nhau. Cả hai phải được normalize về **một internal ticker model duy nhất** trước khi ranking engine sử dụng.

Source of truth trong cache:

- `symbol`
- `openPrice`
- `currentPrice`
- `highPrice`
- `lowPrice`
- `quoteVolume`
- `sourceTimestamp` — lấy từ `closeTime` với REST, từ event time `E` với WebSocket.

`priceChangeAmount` và `priceChangePercent` là **derived values**, không phải source fields trong cache. Luôn tính từ `openPrice` và `currentPrice` ở cùng một chỗ, bất kể dữ liệu vừa đến từ REST hay WebSocket. Không dùng trực tiếp `priceChangePercent` REST làm source of truth.

Dữ liệu này là **rolling 24 giờ**, không phải ngày lịch UTC. UI vẫn ghi `24H`.

### Trình tự khởi tạo / reconnect

Để tránh khoảng trống dữ liệu giữa REST seed và lúc WebSocket bắt đầu nhận:

1. Mở **một** WebSocket `!miniTicker@arr`.
2. Tạm buffer các WebSocket event nhận được.
3. Gọi `GET /api/v3/exchangeInfo` để lấy universe, status, quote asset, `permissionSets`, tick size.
4. Gọi `GET /api/v3/ticker/24hr` để seed snapshot ban đầu.
5. Normalize REST response vào internal ticker model rồi tạo ticker cache. Với từng symbol, dùng `closeTime` của REST ticker làm timestamp của snapshot symbol đó.
6. Áp các WebSocket event đã buffer lên cache. Chỉ áp event khi event time `E` mới hơn timestamp hiện có của symbol, tránh event cũ ghi đè snapshot mới hơn.
7. Chuyển sang merge WebSocket delta trực tiếp vào cache.

Buffer khởi tạo phải có giới hạn. Nếu vượt giới hạn khi seed chưa xong thì hủy lần khởi tạo và retry an toàn từ đầu.

Host, endpoint, stream dự phòng và các giới hạn số cụ thể nằm trong [TECHNICAL.md](./TECHNICAL.md).

Không mở socket riêng cho từng coin.

Không polling REST liên tục khi WebSocket đang sống. Seed lại khi reconnect/cache mất hoặc khi cần resync có chủ đích.

Stream Binance là dependency bên ngoài. Data-source layer phải đổi được stream mà không sửa ranking engine/UI.

Binance có thể chặn theo vùng. App thử fallback host. Nếu mọi host đều không tới được thì hiện `OFFLINE`. Không có server trung gian để đi vòng.

---

## 4. Phạm vi thị trường

V1 chỉ xét các cặp có:

**Quote Asset = USDT**

Ví dụ:

- BTCUSDT
- ETHUSDT
- SOLUSDT
- SUIUSDT
- XRPUSDT

Không đưa các quote market khác như BTC, ETH, BNB, FDUSD hoặc USDC vào bảng xếp hạng V1.

---

## 5. Bộ lọc coin

Một symbol chỉ được xét vào ranking khi tất cả điều kiện sau đúng:

- `quoteAsset == USDT`.
- `status == TRADING`. `HALT`, `BREAK`, `CANCEL_ONLY` đều loại.
- `permissionSets` không chứa permission `LEVERAGED`.
- Base asset không nằm trong blacklist stablecoin.
- Ticker hợp lệ theo rule bên dưới.
- Quote volume 24h đạt ngưỡng tối thiểu.

Ticker không hợp lệ nếu:

- `currentPrice` không parse được hoặc `<= 0`.
- `openPrice` không parse được hoặc `<= 0`.
- `quoteVolume` không parse được hoặc `< 0`.
- Thiếu một trong các field bắt buộc để normalize: symbol, open price, current price, quote volume.
- Derived `priceChangePercent` hoặc `priceChangeAmount` không tính được thành số hữu hạn.

Loại khỏi ranking:

- Stablecoin và token neo giá. V1 dùng blacklist base asset cấu hình được, không đoán bằng “giá gần 1”.
- Leveraged token: loại dựa trên `permissionSets` có `LEVERAGED`. **Không lọc chỉ bằng suffix** `UP`, `DOWN`, `BULL`, `BEAR`, vì có thể loại nhầm coin thật như `JUP`.
- Pair không còn `TRADING`.
- Symbol có ticker hỏng.

Blacklist phải mở rộng được mà không sửa ranking engine. Danh sách mặc định nằm trong [TECHNICAL.md](./TECHNICAL.md).

`exchangeInfo` phải đọc `permissionSets`; không dựa vào field `permissions` vì field này có thể rỗng. V1 lấy `exchangeInfo` khi mở app và khi reconnect/resync, không poll liên tục.

**Known limitation V1:** nếu symbol chuyển từ `TRADING` sang `HALT/BREAK` giữa hai lần refresh `exchangeInfo`, cache có thể tạm giữ status cũ cho tới lần resync tiếp theo. Chấp nhận giới hạn này trong V1.

Coin name đầy đủ không có trong exchangeInfo. V1 hiện `baseAsset`. Không chặn V1 vì thiếu tên.

---

## 6. Volume Filter

Để tránh coin thanh khoản quá thấp lọt Top Gainers, app hỗ trợ:

**Minimum 24h Quote Volume**

Giá trị mặc định:

`5,000,000 USDT`

Ngưỡng này là cấu hình, không hard-code trong ranking engine.

V1 có màn Settings tối giản để sửa ngưỡng này. Giá trị cấu hình nằm ngoài ranking engine và được lưu local.

Listing mới vẫn có thể vào Top 10 nếu volume vừa vượt sàn. Đó là hành vi đúng của filter này.

---

## 7. Top 10 Gainers 24H

Sau khi lọc các symbol hợp lệ:

1. Lấy `priceChangePercent` 24h.
2. Sort giảm dần.
3. Hòa % thì sort tiếp theo quote volume giảm dần, rồi theo symbol tăng dần, để hạng không nhảy.
4. Lấy N coin đầu. Mặc định N = 10. Engine nhận N từ cấu hình.

Ví dụ:

| Rank | Coin | Price | 24h | Volume |
|---|---|---:|---:|---:|
| 1 | ABC | $1.42 | +32.5% | $42M |
| 2 | XYZ | $0.83 | +25.1% | $18M |
| 3 | SUI | $4.21 | +18.4% | $380M |

Danh sách tự cập nhật khi cache đổi. Không cần refresh thủ công.

Giá format theo `tickSize` trong `PRICE_FILTER` của exchangeInfo. Volume format rút gọn, ví dụ `$42M`.

---

## 8. Realtime Update

Luồng xử lý:

`WebSocket buffer + REST seed → ticker cache → WebSocket delta → filter → ranking → Top N → UI`

WebSocket merge ticker đã normalize vào đúng symbol trong cache, chỉ khi `sourceTimestamp` mới hơn. Không thay thế cả object, để không mất metadata từ `exchangeInfo`. Không rebuild universe từ message.

Không render theo từng WebSocket message. Ranking và UI chạy theo nhịp khoảng 1 giây. Socket vẫn nhận liên tục. Parsing/processing không được gây jank UI.

Trễ kỳ vọng khi mạng ổn là khoảng 1–2 giây so với Binance. Đó là mức gần realtime của public market data. Vẽ nhanh hơn nhịp này không làm dữ liệu mới hơn.

---

## 9. Thông tin mỗi coin

UI/ranking model gồm:

- Rank.
- Symbol.
- Base asset. Coin name chỉ thêm nếu sau này có nguồn riêng.
- Open price 24h.
- Current price.
- Price change % 24h — **derived từ `openPrice` và `currentPrice`**.
- Price change amount 24h — **derived từ `openPrice` và `currentPrice`**.
- 24h high.
- 24h low.
- 24h quote volume.
- Previous rank.
- Last updated timestamp.

`!miniTicker@arr` không cung cấp trade count `n`, vì vậy V1 không đưa số lượng trade vào internal model hoặc UI.

Ví dụ hiển thị:

`#3 SUI`

`$4.21`

`+18.42%`

`Volume $382M`

---

## 10. Rank Movement

V1 giữ ranking trong memory để phát hiện thay đổi hạng.

Quy tắc:

- **Lần ranking đầu tiên sau khi app/process khởi động không hiển thị rank movement và không gắn `NEW`.**
- Sau khi có baseline đầu tiên, app so ranking mới với ranking trước đó để phát hiện tăng hạng, giảm hạng, mới vào hoặc rời Top N.
- Badge movement không biến mất ngay ở tick kế tiếp. Khi có thay đổi, giữ badge trên UI trong **10 giây** kể từ lần thay đổi gần nhất của coin.
- Nếu coin lại đổi hạng khi badge cũ vẫn còn, thay badge bằng **movement mới nhất** và reset timer 10 giây. Không cộng dồn về hạng gốc.
- Coin rời Top N chỉ là trạng thái nội bộ. V1 không hiển thị badge cho coin này vì không còn dòng nào để gắn.
- V1 chỉ dùng movement như tín hiệu UI ngắn hạn. Các khái niệm như “tăng 7 → 3 trong 5 phút” thuộc V2 momentum/history.

Ví dụ: `#7 → #5`, sau 4 giây coin đổi tiếp `#5 → #3` thì UI đổi badge thành `#5 → #3` và giữ badge mới thêm 10 giây kể từ lần đổi thứ hai.

Ví dụ:

`#7 → #3`

hoặc:

`NEW`

V1 chỉ cần dữ liệu này cho UI. Chưa ghi lịch sử ra database. V2 notification sẽ dùng cùng tín hiệu này.

---

## 11. Local Storage

Cấu hình ứng dụng lưu local bằng giải pháp phù hợp Flutter. Với dữ liệu cấu hình nhỏ của V1, ưu tiên `shared_preferences`. Chỉ dùng Hive/Isar hoặc database khác khi V2 thực sự cần lưu history lớn hơn.

V1 chỉ lưu:

- Ngưỡng volume.
- Top N.
- Blacklist stablecoin và symbol loại trừ.
- Quote asset, hiện cố định USDT.

Không lưu từng WebSocket tick. Không lưu ranking history hay notification history ở V1. Hai thứ đó thuộc V2.

Previous rank chỉ nằm trong memory. Khi process khởi động lại, ranking đầu tiên trở thành baseline mới và **không tạo movement/`NEW`**. Chỉ các ranking từ lần thứ hai trở đi mới được so với baseline trước đó.

---

## 12. Background Monitoring

Mục tiêu dài hạn là app vẫn theo dõi khi:

- Không nằm ở foreground.
- Màn hình tắt.
- Người dùng đang dùng ứng dụng khác.

Android có thể cắt background process. Không giả định WebSocket sống mãi khi app không mở.

V2 có thể nghiên cứu:

- Foreground Service.
- WebSocket reconnect.
- Network change handling.
- Battery optimization handling.

V1 chỉ đảm bảo realtime khi app đang mở. Tắt màn hình hoặc thoát app có thể mất socket. Đây là hành vi chấp nhận được của V1.

Background monitoring thuộc V2. Android và iOS có giới hạn background khác nhau, đặc biệt iOS không đảm bảo một WebSocket có thể chạy liên tục khi app bị đưa xuống background.

---

## 13. WebSocket Reliability

Chỉ một connection market. Không tạo socket trùng.

WebSocket manager phải có:

- Auto reconnect.
- Phát hiện disconnect.
- Network mất và network trở lại.
- Retry với exponential backoff và jitter.
- Chủ động nối lại trước mốc 24 giờ, vì Binance đóng connection sau 24 giờ.
- Xử lý heartbeat (ping/pong) đúng protocol của Binance Spot.
- Phát hiện stale connection: nếu connection vẫn báo mở nhưng không nhận market-data trong một khoảng ngắn, chuyển `CONNECTING`, đóng connection cũ và reconnect.

Tham số cụ thể (chu kỳ ping, timeout, ngưỡng watchdog) nằm trong [TECHNICAL.md](./TECHNICAL.md).

Mất kết nối không được làm crash app. Cache cuối vẫn giữ để hiển thị.

UI có trạng thái:

- `LOADING`: đang seed REST, chưa có ranking.
- `LIVE`: socket đang nhận.
- `CONNECTING`: đang nối hoặc đang nối lại.
- `OFFLINE`: không tới Binance. Vẫn hiện snapshot cuối nếu có, kèm giờ cập nhật. Không để số đứng im mà trông như live.
- `EMPTY`: sau khi seed/filter hoàn tất có **0 coin** hợp lệ. Nếu có từ 1 đến N-1 coin thì vẫn hiển thị toàn bộ số coin hiện có, không coi là `EMPTY`.

---

## 14. Notification — V2

V1 chỉ để lại tín hiệu rank movement, chưa gửi notification. Notification là tính năng của V2.

Ví dụ ở V2:

### Coin mới vào Top 10

`SUI entered Top 10`

`+12.8% / 24h`

### Coin tăng hạng nhanh

`SUI #8 → #3`

### Coin tăng tốc

`SUI +4.2% trong 5 phút`

Ưu tiên notification local, không phụ thuộc Firebase nếu không cần.

---

## 15. Short-Term Momentum — V2

Ngoài % 24h, V2 có thể tính:

- 1 phút.
- 5 phút.
- 15 phút.
- 30 phút.
- 1 giờ.

Ví dụ:

`24h: +14.2%`

`15m: +5.8%`

`5m: +3.1%`

Mục đích là tách coin đã tăng từ lâu khỏi coin đang tăng nhanh ngay lúc này. Không đưa vào tiêu chí sort của V1. Binance có sẵn `!ticker_1h@arr`. Cửa sổ ngắn hơn phải tự giữ snapshot. Phần này không thuộc V1.

---

## 16. Home Screen — V1

Màn hình chính giữ đơn giản.

Header:

`Top Gainers`

Trạng thái:

`● LIVE`

Thông tin phụ:

`Binance • USDT • 24H`

Danh sách:

- Rank.
- Coin.
- Price.
- 24H %.
- Volume.

Có thể hiện rank movement ngắn, ví dụ `NEW` hoặc `#7 → #3`, nếu không làm rối dòng.

Không nhồi high, low, amount change vào màn chính. Tap vào coin để mở detail thuộc V2.

`OFFLINE` hiện giờ của snapshot cuối trên header.

---

## 17. Settings — V1 tối giản

V1 **có màn Settings tối giản**. Không để các giá trị quan trọng chỉ tồn tại dưới dạng hằng số trong code.

Cho phép chỉnh:

### Market

`Quote Asset: USDT`

V1 chỉ hỗ trợ USDT nên field này có thể read-only. Kiến trúc không khóa cứng để sau này thêm quote asset khác.

### Minimum Volume

Mặc định `5,000,000 USDT`.

### Ranking

`Top N: 10`

Cho phép thay đổi Top N trong khoảng **5–50**, mặc định 10. Đổi Top N không mở thêm WebSocket. Top N chỉ quyết định số dòng lấy ra từ cache đã lọc.

### Excluded Coins

Cho phép chỉnh blacklist base asset và symbol mà không sửa ranking engine.

### Cảnh báo tăng trưởng nhiều mốc (Multi-milestone Gain Alerts)

- Cho phép người dùng chọn **đồng thời nhiều mốc % tăng trưởng 24H** (mặc định: `+15%` và `+20%`).
- Chip chọn nhanh: `+5%`, `+10%`, `+15%`, `+20%`, `+25%`, `+30%`, `+40%`, `+50%`, `+100%`.
- Thêm mốc tùy ý: Cho phép gõ số % bất kỳ (ví dụ `12.5%`, `35%`) và thêm vào danh sách kích hoạt.
- Thanh tóm tắt: Hiển thị trực quan toàn bộ các mốc đang bật (ví dụ: `Đang kích hoạt: +15%, +20%`).
- Cơ chế báo động bậc thang (Step-ladder): Bắn notification riêng cho từng mốc khi coin vượt qua, không đè lặp, tự reset khi coin pullback (giảm dưới mốc - 2% hoặc dưới 0.9x).

### Chạy ngầm 24/7 (Android Foreground Service)

- Sử dụng `CoinPulseBackgroundService` (`foregroundServiceType="dataSync"`).
- Duy trì kết nối WebSocket và cập nhật bảng xếp hạng liên tục kể cả khi tắt màn hình hoặc chuyển sang ứng dụng khác.
- Đẩy local notification với kênh âm thanh và rung mức độ ưu tiên cao (`IMPORTANCE_HIGH`) khi phát hiện coin vượt mốc.

### Ngôn ngữ & Bản địa hóa (Vietnamese UI)

- Giao diện chuyển đổi hoàn toàn sang Tiếng Việt:
  - Màn hình chính: `Top Tăng Trưởng`, `Binance • USDT • Biến Động 24H`, nhãn `MỚI` (thay cho `NEW`), thanh tìm kiếm, trạng thái kết nối (`TRỰC TIẾP`, `ĐANG TẢI`, `MẤT MẠNG`).
  - Màn hình Cài đặt: các phân mục chức năng rõ ràng, nút `LƯU CÀI ĐẶT`.
- Giữ nguyên các thuật ngữ crypto / tài chính quốc tế: `USDT`, `Volume`, `24H`, `Live`, `Binance`, `WebSocket`.

Settings lưu local bằng `shared_preferences`.

Không đưa các cấu hình kỹ thuật như reconnect backoff, buffer size hoặc watchdog timeout ra UI Settings.


---

## 18. Performance

Ứng dụng phải nhẹ.

Không:

- Ghi database theo từng WebSocket message.
- Re-render cả màn theo từng message.
- Tạo WebSocket riêng cho từng coin.
- Poll REST khi socket đang sống.
- Để parsing/processing gây jank UI.

Ưu tiên:

**Một market stream → cache local → ranking local mỗi khoảng 1 giây.**

List dùng diff theo symbol, chỉ cập nhật dòng đổi rank, giá hoặc %.

---

## 19. Security

V1 chỉ đọc public market data.

Không lưu Binance API Secret.

Không yêu cầu quyền truy cập tài khoản Binance.

Không thực hiện:

- Buy.
- Sell.
- Withdraw.
- Deposit.
- Trading automation.

---

## 20. Chi phí vận hành

Mục tiêu:

**0 VNĐ/tháng**

Kiến trúc:

`Mobile App (Android / iOS) ↔ Binance Spot Public API / WebSocket`

Không có server trung gian. Nếu Binance bị chặn tại mạng đang dùng, app không có đường vòng miễn phí.

---

## 21. V1 Scope

**V1 là version đang được triển khai hiện tại.**

Mọi quyết định implementation hiện tại phải ưu tiên hoàn thành V1. Không tự động triển khai tính năng V2 chỉ vì architecture đã chuẩn bị sẵn khả năng mở rộng.


V1 xong khi:

- Mở một WebSocket và buffer event trong lúc REST seed.
- Seed được universe và ticker bằng REST, sau đó áp buffer vào cache.
- Nhận delta tiếp tục bằng cùng một WebSocket.
- Lọc USDT, `TRADING`, stablecoin, leveraged token qua `permissionSets`, volume sàn.
- Sort theo % 24h, có tie-break.
- Hiện Top 10, giá và volume tự đổi khi Binance đổi.
- Rank movement trong memory.
- Reconnect một socket, có backoff.
- Có `LOADING`, `LIVE`, `CONNECTING`, `OFFLINE`, `EMPTY` với semantics rõ ràng.
- Có data-silence watchdog và reconnect khi stream stale.
- Có Settings cho Top N, minimum volume, blacklist và cấu hình nhiều mốc cảnh báo tăng trưởng (+15%, +20%...).
- Chạy ngầm 24/7 với Android Foreground Service.
- Gửi Local Notification ưu tiên cao khi coin chạm mốc tăng trưởng.
- Giao diện người dùng được Việt hóa toàn diện.
- **Coin Detail & Candlestick Chart Realtime (V1 Next)**:
  - Xem nến realtime cập nhật theo từng nhịp thị trường Binance.
  - Chọn 9 khung thời gian (1m, 3m, 5m, 15m, 30m, 1h, 4h, 1d, 1w).
  - Tải nến quá khứ vô tận khi vuốt sang trái.
  - Cử chỉ pinch-to-zoom và pan cuộn lịch sử mượt mà.
  - Crosshair tương tác: hiển thị O/H/L/C, % biến động, Volume, mốc thời gian.
  - Cột khối lượng (Volume bars) đồng bộ màu sắc.
  - Đánh dấu High/Low của vùng hiển thị.
  - Đường giá live nét đứt kèm đồng hồ đếm ngược đóng nến.
  - Chế độ toàn màn hình xoay ngang (Landscape Fullscreen).
- **Chỉ báo Order Flow Imbalance Finder (OFIF Indicator)**:
  - Pure Dart price imbalance / FVG detector dựa trên 3 nến liên tiếp chuẩn theo indicator Pine Script của Turk.
  - Tự động nhận diện Top Imbalance (vùng bán / Supply) và Bottom Imbalance (vùng mua / Demand).
  - Zone tự động kéo dài sang phải theo realtime candle và cắt ngắn (`f_choppedoffimb`) ngay khi bị nến mới xuyên thủng biên.
  - Giới hạn tối đa 50 zones trong bộ nhớ (tự loại bỏ zone cũ nhất).
  - Mặc định chỉ tính nến đã xác nhận (`confirmedOnly = true`) để chống nhiễu từ nến đang hình thành.
  - Nút toggle `OFIF` tiện dụng trên cả giao diện dọc (Portrait) và toàn màn hình xoay ngang (Landscape Fullscreen).

Chưa cần:

- Trading.
- Login Binance.
- CoinGlass.
- AI.
- Cloud sync.
- Account system.
- Backend/server riêng.
- Momentum 1m/5m/15m.
- Ranking history trong database.
- Order book imbalance, Bid/ask delta, Footprint chart, Liquidation.

---

## 21a. Chi tiết kỹ thuật: Realtime Coin Detail Chart

Khi người dùng nhấn vào bất kỳ coin nào trong bảng xếp hạng Top Gainers, app mở màn **Coin Detail** với biểu đồ nến realtime của symbol đó.

### Nguồn dữ liệu & Model
- Dữ liệu Kline lấy trực tiếp từ Binance Spot (`/api/v3/klines` và WebSocket `<symbol>@kline_<interval>`).
- Chuẩn hóa REST và WebSocket về một `Candle` model thống nhất:
  - `openTime`, `closeTime`, `open`, `high`, `low`, `close`, `volume`, `isClosed`.
- Subscribe Kline WebSocket riêng cho coin đang xem, tự động hủy (unsubscribe/dispose) khi thoát khỏi màn hình Coin Detail để bảo tồn tài nguyên mạng và pin.

### Tính năng biểu đồ
- Khung thời gian (Intervals): `1m`, `3m`, `5m`, `15m`, `30m`, `1h`, `4h`, `1d`, `1w`.
- Tải nến quá khứ vô tận khi vuốt sang trái (Infinite Pagination).
- Zoom 2 ngón (Pinch-to-zoom) và Pan với gia tốc quán tính.
- Crosshair tương tác: Hiển thị trục tọa độ chữ thập, tag giá, tag mốc thời gian và thanh thông số O/H/L/C/%/Vol chi tiết.
- Sub-chart khối lượng (Volume bars) tỉ lệ hài hòa phía dưới.
- Tag giá hiện tại nét đứt kèm đồng hồ đếm ngược đóng nến (`countdown`).
- Đánh dấu cực trị High / Low trên vùng nến đang hiển thị.

---

## 21b. Chi tiết kỹ thuật: Imbalance Detector (OFIF)

Coin Detail hỗ trợ overlay **Imbalance** dựa trên OHLC candle, tái tạo logic indicator Pine Script **"Order Flow Imbalance Finder By Turk"**.

### Thuật toán nhận diện (3-bar pattern)
Mỗi lần có candle mới, detector duyệt qua chuỗi 3 nến liên tiếp `candle[i-2]`, `candle[i-1]`, `candle[i]`:

1. **Top Imbalance (Supply Zone)**:
   ```text
   candle[i-2].low <= candle[i-1].open AND candle[i].high >= candle[i-1].close
   size = candle[i-2].low - candle[i].high
   Tạo zone khi size > 0:
     topPrice = candle[i-2].low
     bottomPrice = candle[i].high
   ```
2. **Bottom Imbalance (Demand Zone)**:
   ```text
   candle[i-2].high >= candle[i-1].open AND candle[i].low <= candle[i-1].close
   size = candle[i].low - candle[i-2].high
   Tạo zone khi size > 0:
     topPrice = candle[i].low
     bottomPrice = candle[i-2].high
   ```

### Vòng đời & Quy tắc cắt vùng (`f_choppedoffimb`)
- Vùng đang hoạt động (`active = true`) tiếp tục được mở rộng sang phải theo các nến tiếp theo.
- Đối với mỗi nến mới `c0`, kiểm tra các zone đang nối từ nến liền trước:
  ```text
  highViolates = c0.high > zone.edge && c0.low < zone.edge
  ```
  Nếu giá cao nhất và thấp nhất của nến mới kẹp giữa biên trên hoặc biên dưới của zone, zone bị vô hiệu hóa (`active = false`), dừng kéo dài và chốt `endOpenTime`.
- **Giới hạn số vùng**: Tối đa 50 vùng hiển thị đồng thời (`maxZones = 50`), tự động xóa zone cũ nhất khi vượt ngưỡng.
- **Xác nhận nến (`confirmedOnly`)**: Mặc định `true` để tránh zone nhấp nháy do nến hiện tại đang nhảy giá.
- **Hiển thị trực quan**: Vẽ dạng hộp chữ nhật bán trong suốt (Đỏ ruby `#F6465D` cho Top Imbalance, Xanh ngọc `#0ECB81` cho Bottom Imbalance), viền nét đứt (dashed border) kèm nhãn nhận diện tinh tế.

---

## 22. V2 — Bản cập nhật sau V1

Chỉ bắt đầu V2 sau khi V1 đã hoạt động ổn định.

V2 tập trung vào **theo dõi chủ động và cảnh báo**, thay vì chỉ xem bảng Top Gainers khi app đang mở.

Các tính năng dự kiến:

- Background monitoring trong giới hạn Android/iOS cho phép.
- Local notification.
- Cảnh báo coin mới vào Top N.
- Cảnh báo rank tăng nhanh.
- Momentum 1m / 5m / 15m / 30m / 1h.
- Price alerts.
- Volume spike.
- Coin detail.
- Local history.
- Watchlist.
- Ranking history.
- Notification history.

Watchlist vẫn dùng ticker cache chung, không mở một WebSocket riêng cho từng coin.

Các tính năng nâng cao có thể tiếp tục bổ sung trong V2 hoặc các version sau nếu thực sự cần:

- Binance Futures data.
- Open Interest.
- Funding Rate.
- Long/Short ratio.
- Liquidation.
- Liquidation heatmap.
- Volume acceleration.
- Composite momentum score.

Futures là nguồn dữ liệu khác với Binance Spot và không được đưa vào V1.

---

## 23. Ranh giới V1 và V2

### V1 — Đang làm

V1 trả lời một câu hỏi duy nhất:

> **Ngay lúc này, những coin USDT nào đang có % tăng rolling 24h cao nhất trên Binance Spot?**

V1 tập trung vào:

`Binance Spot → REST seed → WebSocket → cache → filter → ranking → Top N → UI`

V1 phải ổn định, nhẹ và đúng dữ liệu trước khi thêm các tính năng khác.

### V2 — Sau khi V1 hoàn thành

V2 trả lời thêm:

> **Coin nào đang bắt đầu tăng nhanh, coin nào đáng theo dõi và khi nào cần báo cho người dùng?**

V2 mới bổ sung background, notification, momentum, watchlist, history và các tín hiệu nâng cao.

Nếu một yêu cầu mới không cần thiết để trả lời câu hỏi chính của V1, mặc định đưa yêu cầu đó sang V2 thay vì mở rộng scope V1.

---

## 24. Nguyên tắc phát triển

Thứ tự ưu tiên:

**Reliable data → Low resource usage → Simple UI → Fast realtime update → Background monitoring → Advanced signals**

Không over-engineer V1.

Mục tiêu đầu tiên:

> Mở app và thấy 10 coin USDT đủ thanh khoản đang tăng mạnh nhất trong 24 giờ trên Binance. Binance đổi thì danh sách trên máy đổi theo, trễ khoảng 1–2 giây khi app đang mở.
