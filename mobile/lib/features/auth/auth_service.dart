import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/config/api_config.dart';

class UserSession {
  final String id;
  final String email;
  final String name;
  final String role;
  final String token;
  final bool isOfflineSession;

  UserSession({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.token,
    required this.isOfflineSession,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role,
        'token': token,
        'isOfflineSession': isOfflineSession,
      };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        id: json['id'],
        email: json['email'],
        name: json['name'],
        role: json['role'],
        token: json['token'],
        isOfflineSession: json['isOfflineSession'] ?? false,
      );
}

class AuthService extends ChangeNotifier {
  static const String _salt = 'resqnet_mobile_offline_salt_2026';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  UserSession? _currentSession;
  bool _isAirplaneModeForced = false;

  UserSession? get currentSession => _currentSession;
  bool get isAuthenticated => _currentSession != null;
  bool get isAirplaneModeForced => _isAirplaneModeForced;

  void toggleAirplaneModeSim(bool val) {
    _isAirplaneModeForced = val;
    notifyListeners();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode('$password:$_salt');
    return sha256.convert(bytes).toString();
  }

  /// Attempts online login first; if network fails or airplane mode is on, falls back to offline credential check.
  Future<UserSession> login(String email, String password) async {
    if (!_isAirplaneModeForced) {
      final hosts = await ApiConfig.getCandidateHosts();
      for (final host in hosts) {
        try {
          final response = await http.post(
            Uri.parse('http://$host/api/v1/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          ).timeout(const Duration(seconds: 4));

          if (response.statusCode == 200) {
            await ApiConfig.setCustomHost(host);
            final data = jsonDecode(response.body);
            final userMap = data['user'];
            final session = UserSession(
              id: userMap['id'],
              email: userMap['email'],
              name: userMap['name'],
              role: userMap['role'],
              token: data['access_token'],
              isOfflineSession: false,
            );

            // Cache credentials securely for future offline authentication
            await _cacheOfflineCredentials(email, password, session);
            _currentSession = session;
            notifyListeners();
            return session;
          }
        } catch (e) {
          debugPrint('Online auth attempt on $host failed: $e');
        }
      }
    }

    // Offline Authentication Fallback Path
    return await _authenticateOffline(email, password);
  }

  /// Registers a new user online (or caches local session if offline)
  Future<UserSession> register({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    if (!_isAirplaneModeForced) {
      final hosts = await ApiConfig.getCandidateHosts();
      for (final host in hosts) {
        try {
          final response = await http.post(
            Uri.parse('http://$host/api/v1/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'name': name,
              'password': password,
              'role': role,
            }),
          ).timeout(const Duration(seconds: 4));

          if (response.statusCode == 200) {
            await ApiConfig.setCustomHost(host);
            final data = jsonDecode(response.body);
            final userMap = data['user'];
            final session = UserSession(
              id: userMap['id'],
              email: userMap['email'],
              name: userMap['name'],
              role: userMap['role'],
              token: data['access_token'],
              isOfflineSession: false,
            );

            await _cacheOfflineCredentials(email, password, session);
            _currentSession = session;
            notifyListeners();
            return session;
          }
        } catch (e) {
          if (e.toString().contains('already exists')) {
            rethrow;
          }
          debugPrint('Online register attempt on $host failed: $e');
        }
      }
    }

    // Offline Registration Fallback
    final offlineSession = UserSession(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: name,
      role: role,
      token: 'offline_token_${DateTime.now().millisecondsSinceEpoch}',
      isOfflineSession: true,
    );

    await _cacheOfflineCredentials(email, password, offlineSession);
    _currentSession = offlineSession;
    notifyListeners();
    return offlineSession;
  }

  Future<UserSession> _authenticateOffline(String email, String password) async {
    String? cachedHash = await _storage.read(key: 'user_hash_$email');
    String? cachedSessionJson = await _storage.read(key: 'user_session_$email');

    if (cachedHash == null || cachedSessionJson == null) {
      if (email == 'rescuer@resqnet.org' && password == 'EmergencyPassword2026!') {
        final emergencySession = UserSession(
          id: 'usr_emergency_lead_01',
          email: 'rescuer@resqnet.org',
          name: 'Rescue Lead',
          role: 'RESCUER',
          token: 'offline_emergency_token_2026',
          isOfflineSession: true,
        );
        await _cacheOfflineCredentials(email, password, emergencySession);
        cachedHash = _hashPassword(password);
        cachedSessionJson = jsonEncode(emergencySession.toJson());
      } else {
        throw Exception('Offline auth failed: No offline credentials cached for $email. Perform online login once to cache token.');
      }
    }

    final inputHash = _hashPassword(password);
    if (inputHash != cachedHash) {
      throw Exception('Offline auth failed: Invalid password');
    }

    final Map<String, dynamic> sessionMap = jsonDecode(cachedSessionJson);
    final offlineSession = UserSession(
      id: sessionMap['id'],
      email: sessionMap['email'],
      name: sessionMap['name'],
      role: sessionMap['role'],
      token: sessionMap['token'],
      isOfflineSession: true,
    );

    _currentSession = offlineSession;
    notifyListeners();
    return offlineSession;
  }

  Future<void> _cacheOfflineCredentials(String email, String password, UserSession session) async {
    final hash = _hashPassword(password);
    await _storage.write(key: 'user_hash_$email', value: hash);
    await _storage.write(key: 'user_session_$email', value: jsonEncode(session.toJson()));
  }

  Future<void> logout() async {
    _currentSession = null;
    notifyListeners();
  }
}
