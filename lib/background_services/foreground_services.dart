import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/main.dart';
import 'package:qr_scanner_app/notification/API_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundServices {
  final GlobalKey<NavigatorState> navigatorKey;

  ForegroundServices(this.navigatorKey);

  // Initialize the foreground service
  Future<void> initializeForegroundService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'DMS Services',
        channelName: 'DMS Services',
        channelDescription: 'Monitors network connectivity.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  // Start the foreground service
  Future<void> startForegroundService() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    debugPrint('Foreground service running: $isRunning');
    if (!isRunning) {
      print('Service started');
      await FlutterForegroundTask.startService(
        notificationTitle: 'DMS Services',
        notificationText: 'Ensuring a smooth connection for you.',
        callback: startCallback,
      );
    }
  }

  // Stop the foreground service
  Future<void> stopForegroundService() async {
    await FlutterForegroundTask.stopService();
  }
}

// Foreground Task Callback
@pragma('vm:entry-point')
void startCallback() {
  debugPrint('startCallback called');
  FlutterForegroundTask.setTaskHandler(NetworkTaskHandler(navigatorKey));
}

// Foreground Task Handler
class NetworkTaskHandler extends TaskHandler {
  final GlobalKey<NavigatorState> navigatorKey;
  NetworkTaskHandler(this.navigatorKey);
  bool isRunning = false;
  // Timer? _timer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('Foreground service started.');
    final prefs = await SharedPreferences.getInstance();
    // final currentTime = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(
        'service_start_time', DateTime.now().millisecondsSinceEpoch);
    await checkConnectivity();
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    await checkConnectivity();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('Foreground service destroyed.');
  }

  @override
  void onNotificationPressed() {
    debugPrint('Notification pressed.');
  }

  // Handle connectivity checking and managing offline time
  Future<void> checkConnectivity() async {
    final prefs = await SharedPreferences.getInstance();
    final offlineTime = prefs.getInt('offline_time');
    final serviceStartTime = prefs.getInt('service_start_time');
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    final connectivityResult = await Connectivity().checkConnectivity();

    // Handle one-hour periodic task
    if (serviceStartTime != null && !isRunning) {
      final elapsedTime = currentTime - serviceStartTime;
      if (elapsedTime >= 3600 * 1000) {
        // if (elapsedTime >= 1 * 60 * 1000) {
        // debugPrint('One hour has passed since service started.');
        isRunning = true;
        await oneHourPeriodicTask();
      }
    }

    // If the user is offline, save the offline start time
    if (connectivityResult.first == ConnectivityResult.none) {
      if (offlineTime == null) {
        await prefs.setInt('offline_time', currentTime);
        debugPrint('User is offline. Offline time saved: $currentTime');
      } else {
        // Check if the offline duration exceeds 2 minutes
        final offlineDuration = currentTime - offlineTime;
        if (offlineDuration > 24 * 60 * 60 * 1000) {
          // Prevent multiple triggers of the login page navigation
          final isNavigatingToLogin = prefs.getBool('is_navigating_to_login');
          if (isNavigatingToLogin == null || !isNavigatingToLogin) {
            debugPrint('User has been offline for more than 24 hours');
            await prefs.setBool('offline_24hours', true);
            debugPrint('Shared preferences updated.');

            // Set a flag to indicate that navigation has already happened
            await prefs.setBool('is_navigating_to_login', true);

            bool offline24Hours = prefs.getBool('offline_24hours') ?? false;
            debugPrint('offline_24hours updated value: $offline24Hours');
            await _navigateToLogin();
          }
        }
      }
    } else {
      // If the user is back online, clear the offline time and the navigation flag
      if (offlineTime != null) {
        debugPrint('User is back online. Clearing offline time.');
        await prefs.remove('offline_time');
        await prefs.remove('is_navigating_to_login'); // Reset the flag
      }
    }
  }

  Future<void> _navigateToLogin() async {
    debugPrint('Navigating to login page due to prolonged offline status.');

    if (navigatorKey.currentState == null) {
      debugPrint('Navigator key is null. Cannot navigate.');
      return;
    }

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   navigatorKey.currentState?.pushNamedAndRemoveUntil(
    //     '/login',
    //     (route) => false,
    //   );
    // });
  }

  // One-hour periodic task
  Future<void> oneHourPeriodicTask() async {
    final prefs = await SharedPreferences.getInstance();
    final lastExecutionTime = prefs.getInt('last_execution_time');
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    if (lastExecutionTime == null ||
        currentTime - lastExecutionTime >= 3600 * 1000) {
      // currentTime - lastExecutionTime >= 1 * 60 * 1000) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.first != ConnectivityResult.none) {
        // CallVersionAPI versionAPI = CallVersionAPI();
        // await versionAPI.fetchAndStoreVersion();
        // debugPrint('Version API called from services.');

        // Nayan--- Moved the notification API call to the Version API page
        // For the future usage keeping the code here.
        // Call fetchNotifications API
        // NotificationAPI notificationService = NotificationAPI();
        // await notificationService.fetchNotifications();
        // debugPrint('Notifications fetched.');

        await prefs.setInt('last_execution_time', currentTime);
      } else {
        debugPrint('No internet connection. Waiting for connectivity...');
        _waitForInternetAndCallAPI();
      }
    } else {
      final remainingTime =
          (3600 * 1000 - (currentTime - lastExecutionTime)) ~/ 1000;
    }

    isRunning = false;
  }

  // Wait for connectivity and call API
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Future<void> _waitForInternetAndCallAPI() async {
    if (_connectivitySubscription != null) return; // already listening...

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((connectivityResult) async {
      if (connectivityResult.first != ConnectivityResult.none) {
        debugPrint('Internet is now available. Calling Version API...');
        // CallVersionAPI versionAPI = CallVersionAPI();
        // await versionAPI.fetchAndStoreVersion();

        NotificationAPI notificationService = NotificationAPI();
        await notificationService.fetchNotifications();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
            'last_execution_time', DateTime.now().millisecondsSinceEpoch);

        // Only show toast if the app is in foreground
        if (navigatorKey.currentState != null) {
          Fluttertoast.showToast(
            msg: "Internet restored. Performing operation...",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }

        _connectivitySubscription?.cancel();
        _connectivitySubscription = null;
      }
    });
  }
}
