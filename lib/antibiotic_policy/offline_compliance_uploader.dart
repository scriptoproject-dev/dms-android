import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_scanner_app/antibiotic_policy/antibiotic_db_helper.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';

class OfflineComplianceUploader {
  bool hasOfflineData = false; // Field to store whether offline data exists
  bool _isUploading = false;

  // Constructor
  OfflineComplianceUploader();

  Future<void> uploadOfflineComplianceRecords() async {
    if (_isUploading) {
      // If an upload is already in progress, skip the execution
      debugPrint("Upload already in progress. Skipping this call.");
      return;
    }

    _isUploading = true;
    final baseUrl = Strings.baseUrl;

    try {
      List<Map<String, dynamic>> offlineComplianceRecords =
          await getOfflineComplianceRecords();

      // Create a list to hold the request bodies
      List<Map<String, dynamic>> requestBody = [];

      for (int i = 0; i < offlineComplianceRecords.length; i++) {
        var record = offlineComplianceRecords[i];

        String antibioticId = record['antibiotic_id'];
        String compileStatus = record['compile_status'];

        // Prepare the request body based on compile status
        if (compileStatus == "yes") {
          // For compiled records
          requestBody.add({
            "antibiotic_id": antibioticId,
            "complied": true,
            "date": record['date'],
            "other_durgs": record['other_durgs'],
            "other_durgs_reason_id": record['other_durgs_reason_id'],
            "other_durgs_message": record['other_durgs_message'],
            "helpful": record['helpful'],
            "helpful_message": record['helpful_message'],
          });
        } else {
          // For non-compiled records
          requestBody.add({
            "antibiotic_id": antibioticId,
            "complied": false,
            "reason_id": record['reason_id'],
            "message": record['message'],
            "date": record['date'],
            "other_durgs": record['other_durgs'],
            "other_durgs_reason_id": record['other_durgs_reason_id'],
            "other_durgs_message": record['other_durgs_message'],
            "helpful": record['helpful'],
            "helpful_message": record['helpful_message'],
          });
        }
      }

      debugPrint("Final Request body: ${jsonEncode(requestBody)}");

      if (requestBody.isEmpty) {
        debugPrint("Request body empty, nothing to send.");
        return;
      }

      try {
        final response = await ApiClient(baseUrl: baseUrl)
            .post('antibiotics/compile', body: requestBody);

        if (response.statusCode == 200) {
          debugPrint("Successfully uploaded all compliance records.");

          // Update the connection status to 'online' for all records
          for (var record in offlineComplianceRecords) {
            String antibioticId = record['antibiotic_id'];
            await DBHelper.updateComplianceConnectionStatus(
                antibioticId, 'online');
          }

          // Reset `hasOfflineData` after successful upload
          hasOfflineData = false;
        } else if (response.statusCode == 401) {
          debugPrint('Received 401. Response body: ${response.body}');
          throw UnauthorizedException('Compliance API returned 401');
        } else {
          debugPrint("Failed to upload compliance records.");
          debugPrint("Response body: ${response.body}");
          throw Exception('Failed to post compliance data');
        }
      } on UnauthorizedException {
        rethrow; // bubble up to DataPushingService
      } catch (e) {
        // Inspect thrown exception text and convert auth-related errors to UnauthorizedException
        final s = e.toString().toLowerCase();
        if (s.contains('401') ||
            s.contains('user is disabled') ||
            s.contains('invalid_grant')) {
          debugPrint('Detected auth error from exception: $e');
          throw UnauthorizedException(e.toString());
        }

        debugPrint("Error uploading offline compliance data (non-auth): $e");
        // If you want the parent to also know about regular failures, rethrow:
        // throw e;
      }
    } catch (e) {
      debugPrint("Error uploading offline compliance records: $e");
      // If it's an UnauthorizedException, rethrow it
      if (e is UnauthorizedException) {
        rethrow;
      }
    } finally {
      _isUploading = false;
    }
  }

  Future<List<Map<String, dynamic>>> getOfflineComplianceRecords() async {
    final db = await DBHelper.getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'compliance',
      where: 'connection = ?',
      whereArgs: ['offline'], // Filter for offline connection
    );

    debugPrint("getOfflineComplianceRecords called.");
    debugPrint("Number of records found: ${maps.length}");

    // Update the `hasOfflineData` field based on the result
    hasOfflineData = maps.isNotEmpty;
    debugPrint("Has offline data: $hasOfflineData");

    return maps; // Return the list of offline compliance records
  }

  // Future<void> uploadOfflineComplianceRecords() async {
  //   if (_isUploading) {
  //     // If an upload is already in progress, skip the execution
  //     debugPrint("Upload already in progress. Skipping this call.");
  //     return;
  //   }

  //   _isUploading = true;
  //   final baseUrl = Strings.baseUrl;

  //   try {
  //     List<Map<String, dynamic>> offlineComplianceRecords =
  //         await getOfflineComplianceRecords();

  //     // Create a list to hold the request bodies
  //     List<Map<String, dynamic>> requestBody = [];

  //     for (int i = 0; i < offlineComplianceRecords.length; i++) {
  //       var record = offlineComplianceRecords[i];

  //       String antibioticId = record['antibiotic_id'];
  //       String compileStatus = record['compile_status'];

  //       // Prepare the request body based on compile status
  //       if (compileStatus == "yes") {
  //         // For compiled records
  //         requestBody.add({
  //           "antibiotic_id": antibioticId,
  //           "complied": true,
  //           "date": record['date'],
  //           "other_durgs": record['other_durgs'],
  //           "other_durgs_reason_id": record['other_durgs_reason_id'],
  //           "other_durgs_message": record['other_durgs_message'],
  //           "helpful": record['helpful'],
  //           "helpful_message": record['helpful_message'],
  //         });
  //       } else {
  //         // For non-compiled records
  //         requestBody.add({
  //           "antibiotic_id": antibioticId,
  //           "complied": false,
  //           "reason_id": record['reason_id'],
  //           "message": record['message'],
  //           "date": record['date'],
  //           "other_durgs": record['other_durgs'],
  //           "other_durgs_reason_id": record['other_durgs_reason_id'],
  //           "other_durgs_message": record['other_durgs_message'],
  //           "helpful": record['helpful'],
  //           "helpful_message": record['helpful_message'],
  //         });
  //       }
  //     }

  //     debugPrint("Final Request body: ${jsonEncode(requestBody)}");

  //     if (requestBody.isNotEmpty) {
  //       final response = await ApiClient(baseUrl: baseUrl)
  //           .post('antibiotics/compile', body: requestBody);

  //       if (response.statusCode == 200) {
  //         debugPrint("Successfully uploaded all compliance records.");

  //         // Update the connection status to 'online' for all records
  //         for (var record in offlineComplianceRecords) {
  //           String antibioticId = record['antibiotic_id'];
  //           await DBHelper.updateComplianceConnectionStatus(
  //               antibioticId, 'online');
  //         }
  //       } else {
  //         debugPrint("Failed to upload compliance records.");
  //         debugPrint("Response body yes: ${response.body}");
  //       }
  //     }
  //     hasOfflineData = false;
  //   } catch (e) {
  //     // _isUploading = false;
  //     debugPrint("Error uploading offline compliance records: $e");
  //   } finally {
  //     _isUploading = false;
  //   }
  // }
}
