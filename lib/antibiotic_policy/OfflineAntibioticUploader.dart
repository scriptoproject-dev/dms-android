import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_scanner_app/antibiotic_policy/antibiotic_db_helper.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';

class OfflineAntibioticUploader {
  OfflineAntibioticUploader();

  bool _isUploading = false;

  Future<List<Map<String, dynamic>>> getOfflineAntibiotics() async {
    final db = await DBHelper.getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'antibiotics',
      where: 'connection = ?',
      whereArgs: ['offline'], // Filter for offline connection
    );
    debugPrint("getOfflineAntibiotics called.");
    debugPrint("Number of records found: ${maps.length}");
    return maps; // Return the list of offline antibiotics
  }

  Future<void> uploadOfflineAntibiotics() async {
    final baseUrl = Strings.baseUrl;

    if (_isUploading) {
      // If an upload is already in progress, skip the execution
      debugPrint("Upload already in progress. Skipping this call.");
      return;
    }

    _isUploading = true;

    try {
      List<Map<String, dynamic>> offlineAntibiotics =
          await getOfflineAntibiotics();

      if (offlineAntibiotics.isEmpty) {
        debugPrint("No offline antibiotics to upload.");
        return;
      }

      List<Map<String, dynamic>> requestBody = [];
      for (int i = 0; i < offlineAntibiotics.length; i++) {
        var antibiotic = offlineAntibiotics[i];
        requestBody.add({
          "antibiotic_id": antibiotic['antibiotic_id'],
          "bookmarked": antibiotic['bookmarked'] == 1, // Convert to boolean
        });
      }

      if (requestBody.isEmpty) {
        debugPrint("Request body empty, nothing to send.");
        return;
      }

      try {
        final response = await ApiClient(baseUrl: baseUrl)
            .post('antibiotics/bookmark', body: requestBody);

        if (response.statusCode == 200) {
          debugPrint("Successfully uploaded antibiotics.");

          // Update connection status for all uploaded antibiotics
          for (int i = 0; i < offlineAntibiotics.length; i++) {
            var antibiotic = offlineAntibiotics[i];
            await DBHelper.updateConnectionStatus(
                antibiotic['antibiotic_id'], 'online');
          }
        } else if (response.statusCode == 401) {
          debugPrint('Received 401. Response body: ${response.body}');
          throw UnauthorizedException('Antibiotic API returned 401');
        } else {
          debugPrint("Failed to upload antibiotics.");
          debugPrint("Response body: ${response.body}");
          throw Exception('Failed to post antibiotic data');
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

        debugPrint("Error uploading offline antibiotics (non-auth): $e");
        // If you want the parent to also know about regular failures, rethrow:
        // throw e;
      }
    } catch (e) {
      debugPrint("Error uploading offline antibiotics: $e");
      // If it's an UnauthorizedException, rethrow it
      if (e is UnauthorizedException) {
        rethrow;
      }
    } finally {
      _isUploading = false;
    }
  }

  // Future<void> uploadOfflineAntibiotics() async {
  //   final baseUrl = Strings.baseUrl;

  //   if (_isUploading) {
  //     // If an upload is already in progress, skip the execution
  //     debugPrint("Upload already in progress. Skipping this call.");
  //     return;
  //   }

  //   _isUploading = true;

  //   try {
  //     List<Map<String, dynamic>> offlineAntibiotics =
  //         await getOfflineAntibiotics();

  //     if (offlineAntibiotics.isNotEmpty) {
  //       List<Map<String, dynamic>> requestBody = [];
  //       for (int i = 0; i < offlineAntibiotics.length; i++) {
  //         var antibiotic = offlineAntibiotics[i];
  //         requestBody.add({
  //           "antibiotic_id": antibiotic['antibiotic_id'],
  //           "bookmarked": antibiotic['bookmarked'] == 1, // Convert to boolean
  //         });
  //         // await DBHelper.updateConnectionStatus(
  //         //     antibiotic['antibiotic_id'], 'online');
  //       }

  //       if (requestBody.isNotEmpty) {
  //         final response = await ApiClient(baseUrl: baseUrl)
  //             .post('antibiotics/bookmark', body: requestBody);

  //         if (response.statusCode == 200) {
  //           // final data = jsonDecode(response.body);
  //           for (int i = 0; i < offlineAntibiotics.length; i++) {
  //             var antibiotic = offlineAntibiotics[i];
  //             await DBHelper.updateConnectionStatus(
  //                 antibiotic['antibiotic_id'], 'online');
  //           }
  //           debugPrint("Successfully uploaded antibiotics.");
  //         }
  //       }
  //     }

  //     // _isUploading = false;
  //   } catch (e) {
  //     // _isUploading = false;
  //     debugPrint("Error uploading offline antibiotics: $e");
  //   } finally {
  //     _isUploading = false;
  //   }
  // }
}
