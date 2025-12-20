import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/notification/database_helper_notification.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationAPI {
  final String baseUrl = Strings.baseUrl;

  final GlobalKey<NavigatorState>? navigatorKey;

  NotificationAPI({this.navigatorKey});

  Future<void> fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('user_id') ?? '';

    final response = await ApiClient(baseUrl: baseUrl).get(
      'user/notifications?user_id=$userId&page=1&sort_order=asc',
    );

    debugPrint("Status Code notification foreground: ${response.statusCode}");
    debugPrint('API Response notification foreground: ${response.body}');

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);

      if (jsonData['status'] == 200 && jsonData['data'] != null) {
        List<dynamic> notificationsList = jsonData['data'];

        List<Map<String, dynamic>> notificationMaps =
            notificationsList.map((notification) {
          return {
            "unique_id": notification["unique_id"],
            "notification_id": notification["notification_id"],
            "user_id": notification["user_id"],
            "title": notification["title"],
            "type": notification["type"],
            "schedule_time": notification["schedule_time"],
            "viewed": notification["viewed"] ? 1 : 0,
            "received": notification["received"] ? 1 : 0,
            "status": notification["status"],
            "content_id": notification["content"]?["content_id"],
            "content_comment": notification["content"]?["comment"],
            "audit_created_by": notification["audit_log"]["created_by"],
            "audit_created_id": notification["audit_log"]["created_id"],
            "audit_created_on": notification["audit_log"]["created_on"],
            "audit_modified_by": notification["audit_log"]["modified_by"],
            "audit_modified_id": notification["audit_log"]["modified_id"],
            "audit_modified_on": notification["audit_log"]["modified_on"],
          };
        }).toList();

        //Clear all notifications before writing.
        final dbHelper = DatabaseHelperNotification();
        await dbHelper.clearNotifications();

        // Store notifications in database
        await DatabaseHelperNotification()
            .insertNotifications(notificationMaps);
        debugPrint("Notifications successfully stored in the database.");
      } else {
        debugPrint("Invalid API response format.");
      }
    } else {
      debugPrint(
          "Failed to fetch notifications. Status Code: ${response.statusCode}");
    }
  }

  Future<void> offlineViewedNotifications() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isConnected = connectivityResult != ConnectivityResult.none;

    if (!isConnected) return;

    final dbHelper = DatabaseHelperNotification();
    final pendingNotifications = await dbHelper.getPendingViewedNotifications();

    if (pendingNotifications.isEmpty) return;

    debugPrint("Pending notifications to sync: $pendingNotifications");

    for (var notificationId in pendingNotifications) {
      try {
        final baseUrl = Strings.baseUrl;
        final apiClient = ApiClient(baseUrl: baseUrl);

        // Make API call
        final response = await apiClient.post(
          'user/notification/viewed',
          body: {
            'notification_ids': [notificationId]
          },
        );

        // Handle response based on statusCode
        if (response.statusCode == 200) {
          await dbHelper.removePendingViewedNotification(notificationId);
          debugPrint('Synced pending notification: $notificationId');
        } else if (response.statusCode == 401) {
          debugPrint('Received 401. Response body: $response');
          throw UnauthorizedException('Notification API returned 401');
        } else {
          debugPrint(
              'Failed to sync pending notification $notificationId. Status: ${response.statusCode}');
        }
      } on UnauthorizedException {
        rethrow; // stop immediately and let DataPushingService handle logout/navigation
      } catch (e, st) {
        // Inspect the exception string for auth-related errors
        final s = e.toString().toLowerCase();
        if (s.contains('401') ||
            s.contains('user is disabled') ||
            s.contains('invalid_grant')) {
          throw UnauthorizedException(e.toString());
        }

        // Non-auth errors: log and continue with next notification
        debugPrint(
            'Error syncing pending notification $notificationId: $e\n$st');
      }
    }
  }
}
