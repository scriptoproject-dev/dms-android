import 'package:flutter/material.dart';
import 'package:qr_scanner_app/antibiotic_policy/antibiotic_db_helper.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';

class OfflineViewAntibioticUploader {
  bool _isUploading = false;

  // Future<void> checkAndUploadOfflineViews() async {
  //   if (_isUploading) {
  //     debugPrint("Upload already in progress. Skipping this call.");
  //     return;
  //   }

  //   _isUploading = true;

  //   try {
  //     List<Map<String, dynamic>> offlineViews =
  //         await DBHelper.getAntibioticViews();

  //     if (offlineViews.isNotEmpty) {
  //       debugPrint("Offline views found: $offlineViews");

  //       List<Map<String, dynamic>> requestBody = [];

  //       for (var view in offlineViews) {
  //         // Check if the antibiotic ID is valid before attempting to upload
  //         if (!await isAntibioticIdValid(view['antibiotic_id'])) {
  //           debugPrint(
  //               "Skipping upload for invalid antibiotic ID: ${view['antibiotic_id']}");
  //           continue;
  //         }

  //         requestBody.add({
  //           "action": view['action'],
  //           "antibiotic_id": view['antibiotic_id'],
  //           "view": view['view'] == 1,
  //           "date": view['date'],
  //         });
  //       }

  //       if (requestBody.isNotEmpty) {
  //         final response = await ApiClient(baseUrl: Strings.baseUrl)
  //             .post('antibiotics/view', body: requestBody);

  //         if (response.statusCode == 200) {
  //           debugPrint("Successfully uploaded all views.");

  //           for (var view in offlineViews) {
  //             await DBHelper.deleteAntibioticView(view);
  //           }
  //         } else {
  //           debugPrint(
  //               "Failed to upload views. Response body: ${response.body}");
  //           throw Exception("Failed to upload data");
  //         }
  //       }
  //     } else {
  //       debugPrint("No offline data to upload.");
  //     }
  //   } catch (e) {
  //     debugPrint("Error uploading offline view data: $e");
  //   } finally {
  //     _isUploading = false; // Ensure this is reset even if an error occurs
  //   }
  // }

  Future<void> checkAndUploadOfflineViews() async {
    if (_isUploading) {
      debugPrint("Upload already in progress. Skipping this call.");
      return;
    }

    _isUploading = true;

    try {
      List<Map<String, dynamic>> offlineViews =
          await DBHelper.getAntibioticViews();

      if (offlineViews.isEmpty) {
        debugPrint("No offline views to upload.");
        return;
      }

      debugPrint("Offline views found: $offlineViews");

      List<Map<String, dynamic>> requestBody = [];

      for (var view in offlineViews) {
        // Check if the antibiotic ID is valid before attempting to upload
        if (!await isAntibioticIdValid(view['antibiotic_id'])) {
          debugPrint(
              "Skipping upload for invalid antibiotic ID: ${view['antibiotic_id']}");
          continue;
        }

        requestBody.add({
          "action": view['action'],
          "antibiotic_id": view['antibiotic_id'],
          "view": view['view'] == 1,
          "date": view['date'],
        });
      }

      if (requestBody.isEmpty) {
        debugPrint("Request body empty, nothing to send.");
        return;
      }

      try {
        final response = await ApiClient(baseUrl: Strings.baseUrl)
            .post('antibiotics/view', body: requestBody);

        if (response.statusCode == 200) {
          debugPrint("Successfully uploaded all views.");

          // Delete views after successful upload
          for (var view in offlineViews) {
            await DBHelper.deleteAntibioticView(view);
          }
        } else if (response.statusCode == 401) {
          debugPrint('Received 401. Response body: ${response.body}');
          throw UnauthorizedException('Antibiotic View API returned 401');
        } else {
          debugPrint("Failed to upload views. Response body: ${response.body}");
          throw Exception("Failed to upload antibiotic view data");
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

        debugPrint("Error uploading offline view data (non-auth): $e");
        // If you want the parent to also know about regular failures, rethrow:
        // throw e;
      }
    } catch (e) {
      debugPrint("Error uploading offline view data: $e");
      // If it's an UnauthorizedException, rethrow it
      if (e is UnauthorizedException) {
        rethrow;
      }
    } finally {
      _isUploading = false; // Ensure this is reset even if an error occurs
    }
  }

  Future<bool> isAntibioticIdValid(String antibioticId) async {
    try {
      var result =
          await DBHelper.getAntibiotics(); // Implement this in DBHelper
      return result.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking antibiotic ID in local database: $e");
      return false;
    }
  }
}
