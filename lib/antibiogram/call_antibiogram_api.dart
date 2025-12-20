import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:dio/dio.dart';
import 'package:qr_scanner_app/antibiogram/antibiogram_api_services.dart';
import 'package:qr_scanner_app/antibiogram/database_helper_antibiogram.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class CallAntibiogramAPI {
  final DatabaseHelperAntibiogram dbHelper = DatabaseHelperAntibiogram();
  final ApiClient apiClient = ApiClient(baseUrl: Strings.baseUrl);

  /// Fetch and store antibiogram data in the database
  Future<bool> fetchAndStoreAntibiogramData() async {
    debugPrint('Fetching and storing antibiogram data...');
    try {
      final apiService = AntibiogramApiService(apiClient: apiClient);
      final response = await apiService.fetchAntibiogram();
      final apiData = json.decode(json.encode(response));

      // List categories = apiData['data']['categorys'];

      // Extract categories from the response
      List categories = apiData['data']['categorys'] ?? [];

      // Check if categories list is empty
      if (categories.isEmpty) {
        debugPrint('No data received. Clearing existing antibiogram data.');
        await dbHelper.clearAllData();
        return false; // Return an empty list if no data
      }

      // Clear existing data from the tables
      await dbHelper.clearAllData();
      debugPrint('Existing antibiogram data cleared.');

      for (var category in categories) {
        final categoryId = category['category_id'];
        final categoryName = category['name'];
        await dbHelper.insertCategory({
          'category_id': categoryId,
          'category_name': categoryName,
        });

        List antibiogramsData = category['antibiograms_data'];
        for (var antibiogram in antibiogramsData) {
          await dbHelper.insertAntibiogram({
            'antibiogram_id': antibiogram['antibiogram_id'],
            'type': antibiogram['type'],
            'category_id': antibiogram['category_id'],
            'category_name': antibiogram['category_name'],
            'site_id': antibiogram['site_id'],
            'sub_category': antibiogram['sub_category'],
            'x_axis_id': antibiogram['x_axis_id'],
            'x_axis_name': antibiogram['x_axis_name'],
            'y_axis_id': antibiogram['y_axis_id'],
            'y_axis_name': antibiogram['y_axis_name'],
            'new_value': antibiogram['new_value'],
            'old_value': antibiogram['old_value'],
          });
        }
      }

      debugPrint('Antibiogram data successfully inserted into the database.');
      debugPrint('Categories: ${await dbHelper.getCategories()}');
      debugPrint('Antibiograms: ${await dbHelper.getAntibiograms()}');
      return true;
    } catch (error) {
      debugPrint('Error fetching antibiogram data: $error');
      return false;
    }
  }

  /// Download and save antibiogram PDF
  Future<void> fetchAndDownloadAntibiogramPDF() async {
    debugPrint('Fetching and downloading antibiogram PDF...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final siteId = prefs.getString('site_id') ?? '';
      final apiService = AntibiogramApiService(apiClient: apiClient);

      // Fetch the antibiogram file URL
      final downloadUrl = await apiService.fetchAntibiogramFile(siteId);

      // If the response is null, set the path as null in SharedPreferences
      if (downloadUrl.isEmpty) {
        await prefs.setString('antibiogram_file_path', '');
        debugPrint('Download URL is null or empty, file path set to null.');
        return;
      }

      debugPrint('Download URL: $downloadUrl');

      // Check if the download URL is empty
      if (downloadUrl.isEmpty) {
        debugPrint(
            'Download URL is empty. Deleting existing file if it exists.');
        final filePath = prefs.getString('antibiogram_file_path') ?? '';
        if (filePath.isNotEmpty) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
            debugPrint('Existing PDF deleted from $filePath');
          }
        }
        return;
      }
      // Determine the directory based on the platform
      Directory directory = await getApplicationDocumentsDirectory();

      final filePath = '${directory.path}/antibiogram.pdf';
      final file = File(filePath);

      // Clear existing PDF file if it exists
      if (await file.exists()) {
        debugPrint('Existing PDF found, deleting the old file.');
        await file.delete();
      }

      final dio = Dio();

      // Download the new file
      try {
        await dio.download(downloadUrl, filePath);
        debugPrint('PDF downloaded to $filePath');

        // Store the new file path in SharedPreferences
        await prefs.setString('antibiogram_file_path', filePath);
      } catch (error) {
        debugPrint('Error downloading antibiogram PDF: $error');
        // Handle case where the user might have removed the file or no internet
        if (error.toString().contains('NoSuchFileException') ||
            error.toString().contains('404')) {
          debugPrint('The file does not exist or cannot be downloaded.');
        }
      }
    } catch (error) {
      debugPrint('Error fetching antibiogram PDF: $error');
      // In case of an error, set the path to null
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('antibiogram_file_path', '');
    }
  }
}
