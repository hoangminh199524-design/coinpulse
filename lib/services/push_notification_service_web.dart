import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('CoinPulsePush')
external CoinPulsePushJS? get coinPulsePush;

@JS()
extension type CoinPulsePushJS(JSObject _) implements JSObject {
  external bool isSupported();
  external JSPromise<JSBoolean> isSubscribed();
  external JSPromise<JSObject> subscribe();
  external JSPromise<JSObject> unsubscribe();
  external JSPromise<JSObject> testPush();
}

class PushNotificationServiceImpl {
  static Future<bool> isSupported() async {
    try {
      if (coinPulsePush != null) {
        return coinPulsePush!.isSupported();
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> isSubscribed() async {
    try {
      if (coinPulsePush != null) {
        final jsBool = await coinPulsePush!.isSubscribed().toDart;
        return jsBool.toDart;
      }
    } catch (_) {}
    return false;
  }

  static Future<Map<String, dynamic>> subscribe() async {
    try {
      if (coinPulsePush != null) {
        final jsObj = await coinPulsePush!.subscribe().toDart;
        final success = (jsObj.getProperty('success'.toJS) as JSBoolean?)?.toDart ?? false;
        final error = (jsObj.getProperty('error'.toJS) as JSString?)?.toDart;
        return {'success': success, 'error': error};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Chưa khởi tạo PushManager'};
  }

  static Future<Map<String, dynamic>> unsubscribe() async {
    try {
      if (coinPulsePush != null) {
        await coinPulsePush!.unsubscribe().toDart;
        return {'success': true};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false};
  }

  static Future<Map<String, dynamic>> sendTestPush() async {
    try {
      if (coinPulsePush != null) {
        await coinPulsePush!.testPush().toDart;
        return {'success': true};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false};
  }
}
