import 'dart:convert';

import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/main.dart'; // for navigatorKey
import 'package:qr_scanner_app/routes.dart'; // for Routes.login
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AuthService {
  AuthService._();
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  static String? _cachedAccessToken;
  static bool _isRefreshing = false;

  static String? getCachedAccessToken() => _cachedAccessToken;

  // ---------------- LOGIN ----------------
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
    _cachedAccessToken = accessToken;
  }

  // ---------------- REFRESH TOKEN ----------------
  Future<bool> refreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

      if (refreshToken == null || refreshToken.isEmpty) {
        await forceLogout();
        return false;
      }

      final response = await http.post(
        Uri.parse('${Strings.baseUrl}auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode != 200) {
        await forceLogout();
        return false;
      }

      final jsonResponse = jsonDecode(response.body);

      final newAccessToken = jsonResponse['access_token'];
      final newRefreshToken = jsonResponse['refresh_token'];

      if (newAccessToken == null || newRefreshToken == null) {
        await forceLogout();
        return false;
      }

      await saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      return true;
    } catch (_) {
      await forceLogout();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  // ---------------- FORCE LOGOUT ----------------
  Future<void> forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _cachedAccessToken = null;
    _isRefreshing = false;

    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      Routes.login,
      (_) => false,
    );
  }
}
