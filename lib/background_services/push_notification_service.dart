import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:qr_scanner_app/main.dart';
import 'package:qr_scanner_app/notification/API_notification.dart';
import 'package:qr_scanner_app/routes.dart';

class PushNotificationService {
  String oneSignalId = "22843b18-42cb-4bb2-b52b-7fd1c37293b5";
  bool hasPermission = false;

  Future<void> configure(String id) async {
    print("Initializing OneSignal with ID: $oneSignalId");
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(oneSignalId);

    // Request notification permission (especially for iOS)
    await OneSignal.Notifications.requestPermission(true);

    if (Platform.isAndroid) {
      // Android-specific behavior
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        event.preventDefault(); // Let you control the notification display
        OneSignal.Notifications.displayNotification(
          event.notification.notificationId,
        );
      });
    } else if (Platform.isIOS) {
      // iOS-specific behavior
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        // DO NOT call event.preventDefault() on iOS
        debugPrint(
            "Notification received in foreground: ${event.notification.body}");
      });
    }

    // Common to both platforms
    OneSignal.Notifications.addClickListener((event) async {
      print("Notification clicked: ${event.notification.additionalData}");
      NotificationAPI notificationService = NotificationAPI();
      await notificationService.fetchNotifications();
      debugPrint('Notifications fetched from push notification tap.');
      navigatorKey.currentState?.pushNamed(Routes.notifications);
    });

    // checkPermission();
  }

  Future<void> initNotificationListener() async {
    debugPrint("Initialized Notification Listener");

    OneSignal.Notifications.addClickListener((OSNotificationClickEvent result) {
      try {
        print('notify');
        print(result.notification.body);
        print(result);
        var url = result.notification.additionalData!['targeturl'];
        var data = result.notification.additionalData!['id'];
        var ticket = result.notification.additionalData!['ticket_id'];
        print("url $url");
        print("data $data");
        if (url?.isNotEmpty == true) {
          Uri uri = Uri.parse(url!);

          print(uri.path + (uri.hasQuery ? "?${uri.query}" : ""));
        }
      } on Exception catch (e) {
        print(e.toString());
      }
    });

    checkPermission();

    OneSignal.InAppMessages.addClickListener(
        (OSInAppMessageClickEvent action) async {
      try {
        if (action.result.actionId != null) {
          Uri? uri = Uri.tryParse(action.result.actionId!);
          if (uri != null) {
            // locator<NavigationService>().pushNamed(
            //   uri.path + (uri.hasQuery ? "?${uri.query}" : ""),
            // );
          }
        }
      } on Exception catch (e) {
        print(e.toString());
      }
    });
  }

  Future<bool> checkPermission() async {
    hasPermission = OneSignal.Notifications.permission;
    debugPrint("Permission status: $hasPermission");

    OneSignal.Notifications.addPermissionObserver((permission) {
      hasPermission = permission;
    });
    return hasPermission;
  }

  Future<bool> promptOneSignal({bool fallbackToSettings = false}) async {
    return await OneSignal.Notifications.requestPermission(fallbackToSettings);
  }
}
