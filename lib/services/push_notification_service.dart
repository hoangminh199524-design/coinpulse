import 'push_notification_service_stub.dart'
    if (dart.library.js) 'push_notification_service_web.dart';

/// Dịch vụ quản lý thông báo đẩy trực tiếp (Apple Web Push / W3C Push API).
class PushNotificationService {
  /// Kiểm tra xem trình duyệt / thiết bị có hỗ trợ Web Push không.
  static Future<bool> isSupported() => PushNotificationServiceImpl.isSupported();

  /// Kiểm tra xem thiết bị đã đăng ký nhận thông báo đẩy chưa.
  static Future<bool> isSubscribed() => PushNotificationServiceImpl.isSubscribed();

  /// Đăng ký quyền và liên kết token thông báo với Render Server.
  static Future<Map<String, dynamic>> subscribe() => PushNotificationServiceImpl.subscribe();

  /// Huỷ đăng ký nhận thông báo.
  static Future<Map<String, dynamic>> unsubscribe() => PushNotificationServiceImpl.unsubscribe();

  /// Gửi thông báo thử nghiệm để test âm thanh và banner trên iPhone.
  static Future<Map<String, dynamic>> sendTestPush() => PushNotificationServiceImpl.sendTestPush();
}
