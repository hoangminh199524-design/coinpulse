# 🚀 Hướng Dẫn Chạy CoinPulse Bot 24/7 Trên Cloud (Miễn Phí 100%)

Với server bot này, bạn **KHÔNG CẦN BẬT MÁY TÍNH**, **KHÔNG CẦN MỞ APP HAY TRÌNH DUYỆT**. Bot sẽ chạy liên tục trên đám mây 24/7 và bắn thông báo về nhóm Telegram **Minh và Đạt** mỗi khi có coin tăng vọt.

---

## 🌟 Cách 1: Đưa lên Render.com (Khuyên dùng - 1 click, 100% Free)

1. Truy cập [https://render.com](https://render.com) và bấm **Sign In** (Chọn đăng nhập bằng **GitHub**).
2. Sau khi vào Dashboard, bấm nút **New +** (góc trên bên phải) ➔ Chọn **Blueprint**.
3. Chọn kho lưu trữ GitHub của bạn: `hoangminh199524-design/coinpulse`.
4. Render sẽ tự động đọc file `render.yaml` và cấu hình sẵn toàn bộ:
   - Root Dir: `server`
   - Build: `npm install`
   - Start: `node index.js`
   - Token bot & Chat ID nhóm Telegram
5. Bấm **Apply** ➔ Chờ Render build trong khoảng 1 phút là xong!

> 💡 **Mẹo giữ bot không bao giờ ngủ (Keep-alive):**
> Sau khi deploy xong, bạn copy URL của service (dạng `https://coinpulse-bot-xxxx.onrender.com`).
> Vào [cron-job.org](https://cron-job.org) hoặc [uptimerobot.com](https://uptimerobot.com) (miễn phí), tạo 1 tác vụ ping URL này mỗi 10 phút. Bot sẽ chạy vĩnh viễn 24/7 không bao giờ tắt!

---

## 🌟 Cách 2: Chạy trực tiếp trên VPS / Máy chủ cá nhân (nếu có)

```bash
cd server
npm install
npm start
```
Hoặc dùng `pm2` để tự động khởi động lại nếu crash:
```bash
npm install -g pm2
pm2 start index.js --name "coinpulse-bot"
pm2 save
```

---

## 📱 Điều Khiển Bot Trực Tiếp Trong Chat Telegram

Cả bạn và Đạt có thể nhắn tin cho bot ngay trong nhóm chat:
- `/status` : Xem bot có đang hoạt động không, uptime, mốc đang đặt.
- `/set 10, 15, 20` : Đổi các mốc % cảnh báo thành +10%, +15%, +20%.
- `/set 20` : Chỉ cảnh báo khi coin chạm +20%.
- `/volume 3` : Đổi volume tối thiểu thành $3M USDT (mặc định là $5M).
- `/test` : Gửi 1 tin nhắn test để kiểm tra bot.
- `/help` : Xem danh sách lệnh.
