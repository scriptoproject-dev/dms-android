import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/antibiogram/antibiogram_post_service.dart';
import 'package:qr_scanner_app/antibiotic_policy/OfflineAntibioticUploader.dart';
import 'package:qr_scanner_app/antibiotic_policy/OfflineViewAntibioticUploader.dart';
import 'package:qr_scanner_app/antibiotic_policy/offline_compliance_uploader.dart';
import 'package:qr_scanner_app/e_learn/e_learn_post_services.dart';
import 'package:qr_scanner_app/notification/API_notification.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataPushingService {
  // The static instance of the class
  static DataPushingService? _instance;

  // Expose the singleton instance via a factory constructor
  factory DataPushingService(GlobalKey<NavigatorState> navigatorKey) {
    // If the instance is not created, create it
    _instance ??= DataPushingService._internal(navigatorKey);
    return _instance!;
  }
  final GlobalKey<NavigatorState> navigatorKey;
  final ELearnPostServices eLearnPostServices;
  final AntibiogramPostService antibiogramPostService;
  final NotificationAPI notificationAPI;

  // Private named constructor to prevent external instantiation

  DataPushingService._internal(this.navigatorKey)
      : eLearnPostServices = ELearnPostServices(navigatorKey: navigatorKey),
        antibiogramPostService =
            AntibiogramPostService(navigatorKey: navigatorKey),
        notificationAPI = NotificationAPI(navigatorKey: navigatorKey) {
    initializeSync();
  }

  // final GlobalKey<NavigatorState> navigatorKey;
  // final ELearnPostServices eLearnPostServices = ELearnPostServices(navigatorKey: navigatorKey);

  final OfflineAntibioticUploader offlineAntibioticUploader =
      OfflineAntibioticUploader();
  final OfflineComplianceUploader offlineComplianceUploader =
      OfflineComplianceUploader();
  final OfflineViewAntibioticUploader offlineViewAntibioticUploader =
      OfflineViewAntibioticUploader();

  bool _isSyncing = false;
  Timer? _debounceTimer;

  late ConnectivityResult _previousConnectivityState;
  bool _isInitializing =
      true; // Flag to check if initialization is still in progress

  void initializeSync() async {
    // Initialize previous state from SharedPreferences
    _previousConnectivityState = await _getPreviousConnectivityState();

    // Mark initialization as complete
    _isInitializing = false;

    debugPrint('Initializing sync listener');
    Connectivity().onConnectivityChanged.listen((result) async {
      if (_isInitializing) {
        debugPrint(
            'Initialization in progress, skipping connectivity change check.');
        return;
      }

      if (result.isNotEmpty) {
        // Ensure the list is not empty
        ConnectivityResult newState =
            result.first; // Get the first connectivity result

        if (newState != _previousConnectivityState) {
          _previousConnectivityState = newState;
          await _saveConnectivityState(newState);

          if (newState != ConnectivityResult.none) {
            debugPrint('Connectivity restored, preparing to sync...');
            _debounceSync();
          } else {
            debugPrint('No connectivity, sync skipped.');
          }
        } else {
          debugPrint('Connectivity state did not change, skipping sync.');
        }
      }
    });
  }

  // Debounce mechanism to prevent multiple API calls
  void _debounceSync() {
    // If sync is in progress, cancel the debounce to avoid unnecessary triggers
    if (_isSyncing) {
      debugPrint('Sync in progress, skipping debounce trigger.');
      return;
    }

    // Cancel any existing debounce timer to prevent unnecessary API calls
    _debounceTimer?.cancel();

    // Start a new debounce timer
    _debounceTimer = Timer(const Duration(seconds: 2), () async {
      // Proceed with sync only if it's not already in progress
      if (!_isSyncing) {
        debugPrint('Starting sync after debounce...');
        await syncAllServices();
      } else {
        debugPrint('Sync already in progress, skipping this trigger.');
      }
    });
  }

  Future<void> syncAllServices() async {
    if (_isSyncing) return;
    _isSyncing = true;

    bool hasOfflineData = await eLearnPostServices.checkOfflineDataAvailable();

    if (!hasOfflineData) {
      _isSyncing = false;
      debugPrint('No offline data to upload.');
      return;
    }

    _showDialog(
        'Data Uploading', 'Please wait while data is being uploaded...');
    try {
      // run sequentially so we can abort immediately on UnauthorizedException

      await eLearnPostServices.checkAndUploadOfflineMetrics();
      await offlineComplianceUploader.uploadOfflineComplianceRecords();
      await antibiogramPostService.checkAndUploadOfflineData();
      await offlineAntibioticUploader.uploadOfflineAntibiotics();
      await offlineViewAntibioticUploader.checkAndUploadOfflineViews();
      await notificationAPI.offlineViewedNotifications();

      debugPrint('All data pushed globally successfully');
      // optionally show success toast here
      Fluttertoast.showToast(msg: 'Data uploaded successfully');
    } on UnauthorizedException catch (e) {
      debugPrint('Unauthorized during sync: $e');

      // Make sure the dialog is closed before navigating.
      _dismissDialog();

      // Schedule navigation in next frame (to avoid mid-frame re-entrance)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await AuthHelper.logoutAndNavigateToLogin(navigatorKey,
            toastMsg: 'Account Disabled. Please contact support.');
      });

      // done — no further processing
      return;
    } catch (e) {
      debugPrint('Error syncing services: $e');
      _showToast('Data upload failed');
    } finally {
      _isSyncing = false;
      // ensure dialog dismissed (safe, it may already be dismissed)
      _dismissDialog();
    }
  }

  void _showDialog(String title, String content) {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context != null) {
      // _isDialogVisible = true;
      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Row(
              children: [
                const CircularProgressIndicator(), // Loading spinner
                const SizedBox(width: 16),
                Expanded(child: Text(content)),
              ],
            ),
          );
        },
      );
    }
  }

  void _dismissDialog() {
    final navState = navigatorKey.currentState;
    if (navState != null && navState.canPop()) {
      navState.pop();
    } else {
      debugPrint('Cannot dismiss dialog: navigator has no routes to pop.');
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.white,
      textColor: Colors.black,
      fontSize: 16.0,
    );
  }

  Future<void> _saveConnectivityState(ConnectivityResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('previous_connectivity_state', result.index);
  }

  Future<ConnectivityResult> _getPreviousConnectivityState() async {
    final prefs = await SharedPreferences.getInstance();
    int? storedState = prefs.getInt('previous_connectivity_state');
    return ConnectivityResult
        .values[storedState ?? ConnectivityResult.none.index];
  }
}
