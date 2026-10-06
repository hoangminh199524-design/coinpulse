import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class WebStorageAdapter {
  static String? getItem(String key) {
    try {
      final storage = globalContext.getProperty<JSObject>('localStorage'.toJS);
      final val = storage.callMethod<JSString?>('getItem'.toJS, key.toJS);
      return val?.toDart;
    } catch (_) {
      return null;
    }
  }

  static void setItem(String key, String value) {
    try {
      final storage = globalContext.getProperty<JSObject>('localStorage'.toJS);
      storage.callMethod('setItem'.toJS, key.toJS, value.toJS);
    } catch (_) {}
  }
}
