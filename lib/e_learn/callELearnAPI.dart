import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/e_learn/e_learn_api_services.dart';
import 'package:qr_scanner_app/e_learn/e_learn_database_helper.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class CallELearnAPI {
  final ElearnDatabaseHelper dbHelper = ElearnDatabaseHelper();
  final ApiClient apiClient = ApiClient(baseUrl: Strings.baseUrl);
  final BuildContext? context;

  CallELearnAPI(this.context) {
    checkPermissions();
  }

  Future<bool> fetchELearnData() async {
    // Clear the existing data from the tables before fetching new data
    await ElearnDatabaseHelper().clearTables();
    debugPrint('Cleared elearns_summary and elearn_files tables.');

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? siteId = prefs.getString('site_id');

    if (siteId == null) {
      return false;
    }

    final ELearnApiService apiService = ELearnApiService(apiClient: apiClient);

    try {
      // Fetch summary data from API
      final response = await apiService.fetchELearns(siteId);
      debugPrint('Summary API Response: $response');

      final int status = response['status'] ?? -1;
      final Map<String, dynamic> body =
          (response['body'] is Map<String, dynamic>) ? response['body'] : {};

      if (status == 200) {
        // store the summary body (not the wrapper) — adapt if your db expects full shape
        await dbHelper.storeApiResponse(body);
      } else if (status == 401) {
        debugPrint('Received 401 from fetchELearns. Response body: $body');
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (context != null) navigateToLoginScreen(context!);
        return false;
      } else {
        debugPrint('fetchELearns non-200 status: $status, body: $body');
        return false;
      }

      final elearnsList = await dbHelper.getAllELearns();
      for (var item in elearnsList) {
        final thumbnailId = item['thumbnail_id']?.toString();
        final elearnId = item['elearn_id']?.toString() ?? '';

        if (thumbnailId != null && thumbnailId.isNotEmpty) {
          final thumbResult =
              await _fetchAndHandleThumbnail(apiService, elearnId, thumbnailId);
          if (!thumbResult) {
            // stopped due to 401 or error — stop whole flow
            return false;
          }
        }

        final detailResult =
            await _fetchAndStoreELearnDetails(apiService, elearnId);
        if (!detailResult) {
          // stopped due to 401 or error — stop whole flow
          return false;
        }

        await _handleFilesByContentType(elearnId);
      }

      debugPrint('All eLearn data successfully fetched and stored.');
      return true;
    } catch (e) {
      debugPrint('Error during eLearn data fetch: $e');
      return false;
    }
  }

  Future<bool> checkPermissions() async {
    if (await Permission.storage.isGranted) {
      return true;
    }

    if (await Permission.photos.isGranted ||
        await Permission.photos.request().isGranted) {
      return true;
    } else if (await Permission.videos.isGranted ||
        await Permission.videos.request().isGranted) {
      return true;
    } else if (await Permission.audio.isGranted ||
        await Permission.audio.request().isGranted) {
      return true;
    }

    return false;
  }

  /// Fetch and handle thumbnail details
  /// Returns true on success or non-401 continuing; false if 401 encountered (stop).
  Future<bool> _fetchAndHandleThumbnail(
      ELearnApiService apiService, String elearnId, String thumbnailId) async {
    try {
      final response = await apiService.fetchELearnByID(elearnId);
      debugPrint('Thumbnail detail response for $elearnId: $response');

      final int status = response['status'] ?? -1;
      final Map<String, dynamic> body =
          (response['body'] is Map<String, dynamic>) ? response['body'] : {};

      if (status == 200) {
        final thumbnailDetails = body['data']?['thumbnail_details'];
        if (thumbnailDetails != null) {
          final downloadUrl = thumbnailDetails['download_url']?.toString();
          if (downloadUrl != null && downloadUrl.isNotEmpty) {
            await handleThumbnail(thumbnailId, downloadUrl);
          }
        }
        return true;
      } else if (status == 401) {
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (context != null) navigateToLoginScreen(context!);
        return false;
      } else {
        debugPrint(
            'fetchELearnByID (thumbnail) non-200 status: $status, body: $body');
        return true; // continue but no thumbnail processing
      }
    } catch (e) {
      debugPrint('Error fetching thumbnail for eLearn ID $elearnId: $e');
      return true; // don't abort the whole flow for transient errors
    }
  }

  /// Fetch detailed data for an eLearn entry and store it in the database
  /// Returns true on normal flow, false if 401 encountered.
  Future<bool> _fetchAndStoreELearnDetails(
      ELearnApiService apiService, String elearnId) async {
    try {
      final response = await apiService.fetchELearnByID(elearnId);
      debugPrint('Detail API Response for $elearnId: $response');

      final int status = response['status'] ?? -1;
      final Map<String, dynamic> body =
          (response['body'] is Map<String, dynamic>) ? response['body'] : {};

      if (status == 200) {
        final data = body['data'];
        if (data != null && data.containsKey('files')) {
          final List<dynamic> files = data['files'];
          for (var file in files) {
            await dbHelper.insertFileData(
              elearnId,
              file['file_id'] ?? '',
              file['file_name'] ?? '',
              file['download_url'] ?? '',
              file['content_type'] ?? '',
            );
          }
          debugPrint('Files for eLearn ID $elearnId stored successfully.');
        }
        return true;
      } else if (status == 401) {
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (context != null) navigateToLoginScreen(context!);
        return false;
      } else {
        debugPrint(
            'fetchELearnByID (details) non-200 status: $status, body: $body');
        return true; // continue (no files stored)
      }
    } catch (e) {
      debugPrint('Error fetching details for eLearn ID $elearnId: $e');
      return true; // don't abort entire flow for transient errors
    }
  }

  /// Handle files based on content type
  Future<void> _handleFilesByContentType(String elearnId) async {
    try {
      final filesFromDb = await dbHelper.getFilesByElearnId(elearnId);
      for (var file in filesFromDb) {
        final contentType = file['content_type']?.toString() ?? '';
        if (contentType.contains('video')) {
          await handleVideo(file);
        } else if (contentType.contains('image')) {
          await handleImage(file);
        } else if (contentType.contains('pdf')) {
          await handlePdf(file);
        } else if (contentType.contains('link')) {
          handleLink(file);
        }
      }
    } catch (e) {
      debugPrint('Error handling files for eLearn ID $elearnId: $e');
    }
  }

  void handleLink(Map<String, dynamic> file) {
    final String url = file['download_url']?.toString() ?? '';
    if (url.isNotEmpty) {
      debugPrint('Opening link: $url');
    }
  }

  Future<void> handleVideo(Map<String, dynamic> file) async {
    try {
      final String downloadUrl = file['download_url']?.toString() ?? '';
      final String fileId = file['file_id']?.toString() ?? 'video';

      if (downloadUrl.isEmpty || fileId.isEmpty) {
        debugPrint('Invalid download URL or file ID.');
        return;
      }

      Directory directory = await getApplicationDocumentsDirectory();
      String filePath = '${directory.path}/$fileId.mp4';
      final File fileCheck = File(filePath);

      if (await fileCheck.exists()) {
        debugPrint('Video already exists at: $filePath');
        return;
      }

      debugPrint('Downloading video from: $downloadUrl');
      debugPrint('Saving video to: $filePath');

      final Dio dio = Dio();
      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint(
                'Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );

      debugPrint('Video downloaded successfully and saved to $filePath.');
    } catch (e) {
      debugPrint('Error downloading video: $e');
    }
  }

  Future<void> handlePdf(Map<String, dynamic> file) async {
    try {
      final String downloadUrl = file['download_url']?.toString() ?? '';
      final String fileId = file['file_id']?.toString() ?? 'pdf';

      if (downloadUrl.isEmpty || fileId.isEmpty) {
        debugPrint('Invalid download URL or file ID.');
        return;
      }

      Directory directory = await getApplicationDocumentsDirectory();
      String filePath = '${directory.path}/$fileId.pdf';
      final File fileCheck = File(filePath);

      if (await fileCheck.exists()) {
        debugPrint('PDF already exists at: $filePath');
        return;
      }

      debugPrint('Downloading PDF from: $downloadUrl');
      debugPrint('Saving PDF to: $filePath');

      final Dio dio = Dio();
      await dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint(
                'Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );

      debugPrint('PDF downloaded successfully and saved to $filePath.');
    } catch (e) {
      debugPrint('Error downloading PDF: $e');
    }
  }

  Future<void> handleImage(Map<String, dynamic> file) async {
    try {
      final String downloadUrl = file['download_url']?.toString() ?? '';
      final String fileName = file['file_name']?.toString() ?? 'image.jpg';
      final String fileId = file['file_id']?.toString() ?? 'file';
      final String contentType = file['content_type']?.toString() ?? '';

      if (downloadUrl.isEmpty || fileName.isEmpty) {
        debugPrint('Invalid download URL or file name.');
        return;
      }

      String fileExtension = 'jpg';
      if (contentType.contains('png')) {
        fileExtension = 'png';
      } else if (contentType.contains('jpeg')) {
        fileExtension = 'jpg';
      }

      Directory directory = await getApplicationDocumentsDirectory();
      String filePath = '${directory.path}/$fileId.$fileExtension';
      final File fileCheck = File(filePath);

      if (await fileCheck.exists()) {
        debugPrint('Image already exists at: $filePath');
        return;
      }

      debugPrint('Downloading image from: $downloadUrl');
      debugPrint('Saving image to: $filePath');

      final Dio dio = Dio();
      await dio.download(
        downloadUrl,
        filePath,
      );

      debugPrint('Image downloaded successfully and saved to $filePath.');
    } catch (e) {
      debugPrint('Error downloading image: $e');
    }
  }

  Future<void> handleThumbnail(String thumbnailId, String downloadUrl) async {
    try {
      Directory? directory;

      if (Platform.isAndroid) {
        debugPrint('Downloading thumbnail files for Android.');
        directory = await getApplicationCacheDirectory();
      } else if (Platform.isIOS) {
        debugPrint('Downloading thumbnail files for iOS.');
        directory = await getApplicationDocumentsDirectory();
      } else {
        debugPrint('Unsupported platform.');
        return;
      }

      final String filePath = '${directory.path}/$thumbnailId.jpg';
      final File fileCheck = File(filePath);
      debugPrint('Thumbnail path: $filePath');

      if (await fileCheck.exists()) {
        debugPrint('Thumbnail already exists at: $filePath');
        return;
      }

      debugPrint('Downloading thumbnail from: $downloadUrl');
      debugPrint('Saving thumbnail to: $filePath');

      final Dio dio = Dio();
      await dio.download(
        downloadUrl,
        filePath,
      );

      debugPrint('Thumbnail downloaded successfully and saved to $filePath.');
    } catch (e) {
      debugPrint('Error downloading thumbnail: $e');
    }
  }
}
