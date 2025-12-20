import 'package:flutter/material.dart';
import 'package:qr_scanner_app/notification/database_helper_notification.dart';

class NotificationService {
  // singleton (optional but convenient)
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // boolean notifier: true = there is at least one unread notification
  final ValueNotifier<bool> hasUnread = ValueNotifier<bool>(false);

  /// Checks DB and updates the notifier. Returns true if unread exists.
  Future<bool> checkForUnreadNotifications() async {
    try {
      final bool unread =
          await DatabaseHelperNotification().hasUnreadNotifications();
      hasUnread.value = unread;
      debugPrint(unread
          ? 'Unread notifications exist in the local database.'
          : 'No unread notifications found.');
      return unread;
    } catch (e, st) {
      debugPrint('Error checking unread notifications: $e\n$st');
      hasUnread.value = false;
      return false;
    }
  }

  /// Call this after inserting a new notification into DB (FCM/local).
  Future<void> notifyNewNotificationInserted() async {
    // simple approach: re-check DB to update boolean
    await checkForUnreadNotifications();
  }

  /// Call this after marking notification(s) as viewed.
  Future<void> notifyNotificationsUpdated() async {
    await checkForUnreadNotifications();
  }

  void dispose() {
    hasUnread.dispose();
  }
}
