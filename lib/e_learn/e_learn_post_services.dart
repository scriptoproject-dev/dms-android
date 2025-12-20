import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_scanner_app/antibiogram/database_helper_antibiogram.dart';
import 'package:qr_scanner_app/antibiotic_policy/OfflineAntibioticUploader.dart';
import 'package:qr_scanner_app/antibiotic_policy/antibiotic_db_helper.dart';
import 'package:qr_scanner_app/antibiotic_policy/offline_compliance_uploader.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/e_learn/e_learn_api_services.dart';
import 'package:qr_scanner_app/e_learn/e_learn_database_helper.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/notification/database_helper_notification.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';

class ELearnPostServices {
  final ElearnDatabaseHelper dbHelper = ElearnDatabaseHelper();

  final GlobalKey<NavigatorState> navigatorKey;

  bool hasOfflineData = false;
  bool _isUploading = false;

  ELearnPostServices({required this.navigatorKey});

  /// Retrieves offline metrics from the database and uploads them to the API.
  Future<void> checkAndUploadOfflineMetrics() async {
    if (_isUploading) {
      debugPrint("Upload already in progress. Skipping this call.");
      return;
    }

    _isUploading = true;
    try {
      List<Map<String, dynamic>> offlineMetrics =
          await dbHelper.getOfflineMetrics();

      if (hasOfflineData) {
        debugPrint("Offline data found: $offlineMetrics");

        try {
          final apiClient = ApiClient(baseUrl: Strings.baseUrl);
          final eLearnApiService = ELearnApiService(apiClient: apiClient);

          List<Map<String, dynamic>> cleanedMetrics =
              offlineMetrics.map((metric) {
            return {
              'elearn_id': metric['elearn_id']?.toString(),
              'view': metric['view'] == 1,
              'date': metric['date'],
              'completed': metric['completed'] == 1,
              'helpful': metric['helpful'] == 1,
            };
          }).toList();

          List<Map<String, dynamic>> requestBody = [];
          for (int i = 0; i < offlineMetrics.length; i++) {
            requestBody.add(cleanedMetrics[i]);
          }
          debugPrint("Final Request body: ${jsonEncode(requestBody)}");

          if (requestBody.isEmpty) {
            debugPrint("Request body empty, nothing to send.");
            return;
          }

          try {
            final response =
                await eLearnApiService.postElearnMetric(requestBody);

            if (response is Map && response.containsKey('status')) {
              final int status = response['status'];
              if (status == 201) {
                debugPrint("Successfully uploaded all metrics.");
                for (var originalMetric in offlineMetrics) {
                  await dbHelper.deleteOfflineMetricById(originalMetric['id']);
                }
                return;
              } else if (status == 401) {
                debugPrint('Received 401. Response body: $response');
                throw UnauthorizedException('ELearn API returned 401');
              } else {
                debugPrint("Failed to upload metrics. Response: $response");
                throw Exception(response['message'] ?? 'Failed to post data');
              }
            }
          } on UnauthorizedException {
            // Preserve auth exceptions for callers to handle (do NOT swallow).
            rethrow;
          } catch (e) {
            final s = e.toString().toLowerCase();
            if (s.contains('401') ||
                s.contains('user is disabled') ||
                s.contains('invalid_grant')) {
              debugPrint('Detected auth error from exception: $e');
              throw UnauthorizedException(e.toString());
            }
            debugPrint("Error uploading offline data (non-auth): $e");
          }
        } catch (e) {
          // IMPORTANT: If the error is UnauthorizedException, rethrow so the caller (DataPushingService)
          // can handle navigation/logging out immediately.
          if (e is UnauthorizedException) {
            rethrow;
          }
          debugPrint("Error uploading offline data: $e");
        }
      }
    } finally {
      _isUploading = false;
    }
  }

  Future<bool> checkOfflineDataAvailable() async {
    List<Map<String, dynamic>> offlineMetrics =
        await dbHelper.getOfflineMetrics();

    List<Map<String, dynamic>> offlineComplianceRecords =
        await OfflineComplianceUploader().getOfflineComplianceRecords();

    List<Map<String, dynamic>> offlineAntibiogramViews =
        await DatabaseHelperAntibiogram().getAntibiogramViews();

    List<Map<String, dynamic>> offlineAntibioticData =
        await OfflineAntibioticUploader().getOfflineAntibiotics();

    List<Map<String, dynamic>> offlineAntibioticDataViews =
        await DBHelper.getAntibioticViews();
    List<String> pendingNotifications =
        await DatabaseHelperNotification().getPendingViewedNotifications();

    hasOfflineData = offlineMetrics.isNotEmpty ||
        offlineComplianceRecords.isNotEmpty ||
        offlineAntibiogramViews.isNotEmpty ||
        offlineAntibioticData.isNotEmpty ||
        pendingNotifications.isNotEmpty ||
        offlineAntibioticDataViews.isNotEmpty;
    return hasOfflineData;
  }
}
