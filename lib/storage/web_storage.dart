import 'web_storage_stub.dart'
    if (dart.library.js_interop) 'web_storage_web.dart';

class WebStorage {
  static String? getItem(String key) => WebStorageAdapter.getItem(key);
  static void setItem(String key, String value) => WebStorageAdapter.setItem(key, value);
}
