import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/antibiotic_with_status.dart';

class BookmarkUploader {
  Future<void> uploadOfflineBookmarks(
      List<AntibioticWithStatus> offlineBookmarks) async {
    final baseUrl = Strings.baseUrl;

    try {
      for (var bookmark in offlineBookmarks) {
        final requestBody = [
          {
            "antibiotic_id": bookmark.antibiotic.antibioticId,
            "bookmarked": bookmark.bookmarked
          }
        ];

        final response = await ApiClient(baseUrl: baseUrl)
            .post('antibiotics/bookmark', body: requestBody);

        if (response.statusCode == 200) {
          debugPrint('Bookmark uploaded successfully');
        } else {
          debugPrint('Error uploading bookmark: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Error uploading offline bookmarks: $e');
    }
  }
}
