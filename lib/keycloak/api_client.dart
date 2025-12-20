import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_scanner_app/keycloak/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient._privateConstructor({
    required this.baseUrl,
    http.Client? client,
  }) : client = client ?? http.Client();

  static final ApiClient _instance = ApiClient._privateConstructor(baseUrl: '');
  Duration timeout = const Duration(seconds: 30); // Default timeout

  factory ApiClient(
      {required String baseUrl,
      http.Client? client,
      Duration? customTimeout = const Duration(seconds: 40)}) {
    if (_instance.baseUrl.isEmpty) {
      _instance.baseUrl = baseUrl;
      if (client != null) {
        _instance.client = client;
      }
      if (customTimeout != null) {
        _instance.timeout = customTimeout;
      }
    }
    return _instance;
  }

  late String baseUrl;
  late http.Client client;

  Future<http.Response> _sendRequest(http.Request request) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    String? accessToken = prefs.getString('access_token');

    // If token is null or empty, try to get it from AuthService cache
    if (accessToken == null || accessToken.isEmpty) {
      accessToken = AuthService.getCachedAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        debugPrint("📌 Using cached token from AuthService");
        // Update SharedPreferences for consistency
        await prefs.setString('access_token', accessToken);
      }
    }

    debugPrint(
        "Access token: ${accessToken != null ? '${accessToken.substring(0, 20)}...' : 'null'}");

    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $accessToken';
      debugPrint("===== API Request Token =====");
      debugPrint("Authorization: Bearer ${accessToken.substring(0, 20)}...");
      debugPrint("============================");
    } else {
      debugPrint("===== API Request Token =====");
      debugPrint("⚠️ No access token found in SharedPreferences or cache.");
      debugPrint("============================");
    }

    // Log request details
    debugPrint("===== API Request =====");
    debugPrint("URL: ${request.url}");
    debugPrint("Method: ${request.method}");
    debugPrint("Headers: ${request.headers}");
    debugPrint("Body: ${request.body}");
    debugPrint("=======================");

    return await http.Response.fromStream(await client.send(request));
  }

  Future<http.Response> get(String endpoint) async {
    final request = http.Request('GET', Uri.parse('$baseUrl$endpoint'));
    return _handleRequest(request);
  }

  Future<http.Response> post(String endpoint, {dynamic body}) async {
    final request = http.Request('POST', Uri.parse('$baseUrl$endpoint'));
    request.headers['Content-Type'] = 'application/json';
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return _handleRequest(request);
  }

  Future<http.Response> put(String endpoint, {dynamic body}) async {
    final request = http.Request('PUT', Uri.parse('$baseUrl$endpoint'));
    request.headers['Content-Type'] = 'application/json';
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return _handleRequest(request);
  }

  Future<http.Response> patch(String endpoint, {dynamic body}) async {
    final request = http.Request('PATCH', Uri.parse('$baseUrl$endpoint'));
    request.headers['Content-Type'] = 'application/json';
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return _handleRequest(request);
  }

  Future<http.Response> delete(String endpoint, {dynamic body}) async {
    final request = http.Request('DELETE', Uri.parse('$baseUrl$endpoint'));
    request.headers['Content-Type'] = 'application/json';
    if (body != null) {
      request.body = jsonEncode(body);
    }
    return _handleRequest(request);
  }

  Future<http.Response> _handleRequest(http.Request request) async {
    final response = await _sendRequest(request);

    debugPrint('⬅️ STATUS -------->: ${response.statusCode}');
    debugPrint('⬅️ RESPONSE --------->: ${response.body}');

    // Handle both 401 and 403 (unauthorized / token expired)
    if (response.statusCode == 401 || response.statusCode == 403) {
      debugPrint(
          "===== Token Expired/Unauthorized (${response.statusCode}), Refreshing Token =====");

      final refreshed = await AuthService().refreshToken();

      if (refreshed) {
        debugPrint("===== Token Refresh Successful, Retrying Request =====");
        final newRequest = _cloneRequest(request);
        return await _sendRequest(newRequest);
      } else {
        debugPrint("===== Token Refresh Failed, logging out user =====");

        // 1) Clear any stored tokens
        // final prefs = await SharedPreferences.getInstance();
        // await prefs.remove('access_token');
        // await prefs.remove('refresh_token');
        // await prefs.remove('user_id');

        // 2) Trigger your app-level logout / navigation
        //    If you use a global navigatorKey in main.dart:
        //
        //    navigatorKey.currentState?.pushNamedAndRemoveUntil(
        //      Routes.login,
        //      (route) => false,
        //    );
        //
        // or delegate to AuthService:

        // await AuthService().forceLogout();

        // 3) Optionally throw or just return the 401 response
        return response;
      }
    }

    return response;
  }

  http.Request _cloneRequest(http.Request request) {
    final newRequest = http.Request(request.method, request.url);
    newRequest.headers.addAll(request.headers);
    newRequest.body = request.body;

    // Log cloned request details
    debugPrint("===== Cloned Request =====");
    debugPrint("URL: ${newRequest.url}");
    debugPrint("Method: ${newRequest.method}");
    debugPrint("Headers: ${newRequest.headers}");
    debugPrint("Body: ${newRequest.body}");
    debugPrint("=========================");

    return newRequest;
  }
}
