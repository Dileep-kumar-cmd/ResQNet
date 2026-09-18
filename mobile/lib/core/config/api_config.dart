import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConfig {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'backend_server_host';

  /// Default candidate endpoints:
  /// 1. 127.0.0.1:8000 (Forwarded over USB via adb reverse tcp:8000 tcp:8000)
  /// 2. 192.168.51.229:8000 (Current Wi-Fi LAN IP of host machine running backend)
  /// 3. 10.0.2.2:8000 (Standard Android Emulator localhost alias)
  static const List<String> defaultHosts = [
    '127.0.0.1:8000',
    '192.168.51.229:8000',
    '10.0.2.2:8000',
  ];

  /// Retrieves user-saved custom server host (e.g. "192.168.1.100:8000")
  static Future<String?> getCustomHost() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim();
      }
    } catch (_) {}
    return null;
  }

  /// Sets user-configured backend host
  static Future<void> setCustomHost(String host) async {
    try {
      await _storage.write(key: _storageKey, value: host.trim());
    } catch (_) {}
  }

  /// Returns prioritized list of candidate hosts to attempt connection
  static Future<List<String>> getCandidateHosts() async {
    final custom = await getCustomHost();
    if (custom != null && custom.isNotEmpty) {
      return [custom, ...defaultHosts.where((h) => h != custom)];
    }
    return defaultHosts;
  }
}
