import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConfig {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'backend_server_host';

  /// Default candidate endpoints:
  /// 1. Render Cloud Production Backend
  /// 2. 127.0.0.1:8000 (Forwarded over USB via adb reverse tcp:8000 tcp:8000)
  /// 3. 192.168.51.229:8000 (Current Wi-Fi LAN IP of host machine running backend)
  /// 4. 10.0.2.2:8000 (Standard Android Emulator localhost alias)
  static const List<String> defaultHosts = [
    'https://resqnet-hhmk.onrender.com',
    '127.0.0.1:8000',
    '192.168.51.229:8000',
    '10.0.2.2:8000',
  ];

  /// Formats a host and route into a full Uri string (detecting http vs https)
  static String formatUrl(String host, String path) {
    final cleanHost = host.trim();
    final cleanPath = path.startsWith('/') ? path : '/$path';
    if (cleanHost.startsWith('http://') || cleanHost.startsWith('https://')) {
      final base = cleanHost.endsWith('/') ? cleanHost.substring(0, cleanHost.length - 1) : cleanHost;
      return '$base$cleanPath';
    }
    final isLocal = cleanHost.startsWith('127.0.0.1') || 
                    cleanHost.startsWith('localhost') || 
                    cleanHost.startsWith('10.0.2.2') || 
                    cleanHost.startsWith('192.168.');
    final scheme = isLocal ? 'http' : 'https';
    return '$scheme://$cleanHost$cleanPath';
  }

  /// Retrieves user-saved custom server host (e.g. "https://resqnet-hhmk.onrender.com" or "127.0.0.1:8000")
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
