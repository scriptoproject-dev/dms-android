import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:qr_scanner_app/antibiogram/antibiogram_api_services.dart';
import 'package:qr_scanner_app/antibiogram/database_helper_antibiogram.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';

class AntibiogramPostService {
  late Connectivity connectivity;
  // late StreamSubscription<ConnectivityResult> connectivitySubscription;
  bool hasOfflineData = false;
  bool _isUploading = false;

  final GlobalKey<NavigatorState> navigatorKey;

  AntibiogramPostService({required this.navigatorKey}) {
    connectivity = Connectivity();
  }

  Future<void> init(Function onDataUploaded) async {
    // await initNetworkCheck(onDataUploaded);
  }

  Future<void> initNetworkCheck(Function onDataUploaded) async {
    // ConnectivityResult connectivityResult =
    //     await connectivity.checkConnectivity();

    // if (connectivityResult != ConnectivityResult.none) {
    //   await checkAndUploadOfflineData(onDataUploaded);
    // }

    // connectivitySubscription =
    //     connectivity.onConnectivityChanged.listen((result) async {
    //   if (result != ConnectivityResult.none) {
    //     debugPrint("Network became available.");
    //     await checkAndUploadOfflineData(onDataUploaded);
    //   }
    // });
  }

  Future<void> checkAndUploadOfflineData() async {
    if (_isUploading) {
      debugPrint("Upload already in progress. Skipping this call.");
      return;
    }

    _isUploading = true;
    final offlineAntibiogramViews =
        await DatabaseHelperAntibiogram().getAntibiogramViews();
    hasOfflineData = offlineAntibiogramViews.isNotEmpty;

    if (!hasOfflineData) {
      _isUploading = false;
      debugPrint("No offline data to upload.");
      return;
    }

    debugPrint("Offline antibiogram views found: $offlineAntibiogramViews");

    try {
      // Build request body WITHOUT the local 'id' field
      List<Map<String, dynamic>> requestBody = offlineAntibiogramViews.map((v) {
        final copy = Map<String, dynamic>.from(v);
        copy.remove('id'); // remove local PK before sending to API
        return copy;
      }).toList();

      debugPrint("Final Request body: ${jsonEncode(requestBody)}");

      if (requestBody.isEmpty) return;

      final apiService =
          AntibiogramApiService(apiClient: ApiClient(baseUrl: Strings.baseUrl));

      try {
        final response = await apiService.postAntibiogram(requestBody);

        if (response['status'] != null) {
          final int status = response['status'] is int
              ? response['status']
              : int.tryParse(response['status'].toString()) ?? -1;

          if (status == 200) {
            // Delete each uploaded row by id (preferred)
            for (var view in offlineAntibiogramViews) {
              try {
                await DatabaseHelperAntibiogram().deleteAntibiogramView(view);
              } catch (e) {
                debugPrint(
                    "Failed to delete uploaded antibiogram view (id=${view['id'] ?? 'no-id'}): $e");
              }
            }
            debugPrint("All offline antibiogram views uploaded and cleared.");
            return;
          } else if (status == 401) {
            throw UnauthorizedException('Antibiogram API returned 401');
          } else {
            throw Exception(response['message'] ?? 'Upload failed');
          }
        }

        // If apiService instead throws an exception, it will be caught below.
      } on UnauthorizedException {
        rethrow; // let the caller (DataPushingService) handle logout/navigation
      } catch (e) {
        // Some ApiClient implementations throw an Exception for HTTP 401.
        final s = e.toString().toLowerCase();
        if (s.contains('401') ||
            s.contains('user is disabled') ||
            s.contains('invalid_grant')) {
          throw UnauthorizedException(e.toString());
        }
        // Non-auth errors: log but do not escalate as Unauthorized
        debugPrint("Antibiogram upload failed (non-auth): $e");
        // optionally rethrow if you want DataPushingService to know about other failures:
        // rethrow;
      }
    } finally {
      _isUploading = false;
    }
  }

  void dispose() {
    // connectivitySubscription.cancel();
  }
}
