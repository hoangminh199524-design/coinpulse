class PushNotificationServiceImpl {
  static Future<bool> isSupported() async => false;
  static Future<bool> isSubscribed() async => false;
  static Future<Map<String, dynamic>> subscribe() async => {
        'success': false,
        'error': 'Nền tảng này không hỗ trợ Web Push.',
      };
  static Future<Map<String, dynamic>> unsubscribe() async => {'success': false};
  static Future<Map<String, dynamic>> sendTestPush() async => {'success': false};
}
