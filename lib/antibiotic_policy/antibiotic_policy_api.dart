import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_scanner_app/antibiotic_policy/antibiotic_db_helper.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/antibiotic.dart';
import 'package:qr_scanner_app/models/antibiotic_with_status.dart';
import 'package:qr_scanner_app/models/api_response.dart';
import 'package:qr_scanner_app/utilities/connectivity_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AntibioticPolicyAPI {
  final ApiClient apiClient = ApiClient(baseUrl: Strings.baseUrl);

  // Future<List<AntibioticWithStatus>> fetchInfectionsFromApi() async {
  Future<bool> fetchInfectionsFromApi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String siteId = prefs.getString('site_id') ?? '';
      final isOnline = await ConnectivityHelper.isOffline() == false;

      final response = await apiClient.get('antibiotics?site_id=$siteId');
      debugPrint('API Response antibiotic: ${response.body}');
      // Call the function to print names with parent = root
      final jsonResponse = response.body;
      printRootAntibioticNames(jsonResponse);

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
            json.decode(utf8.decode(response.bodyBytes)), (data) {
          // final apiResponse =
          //     ApiResponse.fromJson(json.decode(response.body), (data) {
          return (data as List).map((e) {
            final antibiotic = Antibiotic.fromJson(e);
            return AntibioticWithStatus(
              antibiotic: antibiotic,
              bookmarked: false, // Default value
              connection:
                  isOnline ? 'online' : 'offline', // Set connection status
            );
          }).toList();
        });

        // Clear old data
        // await DBHelper.clearDatabase();

        if (apiResponse.data.isEmpty) {
          // Clear old data if the new data is empty
          await DBHelper.clearDatabase();
          debugPrint('Database cleared due to empty server response.');
          return false;
        } else {
          // Clear old data
          await DBHelper.clearDatabase();

          // Store antibiotics in the local database
          for (var antibiotic in apiResponse.data) {
            await DBHelper.insertAntibiotic(antibiotic);
          }

          // // Store antibiotics in the local database
          // for (var antibiotic in apiResponse.data) {
          //   await DBHelper.insertAntibiotic(antibiotic);
          // }

          // After storing in the database, fetch the data from the local database
          // final List<AntibioticWithStatus> localData =
          //     await DBHelper.getAntibiotics();

          // return localData;
          debugPrint('Antibiotic data successfully stored in the database.');
          return true;
        }
        // setState(() {
        //   _allAntibiotics = localData;
        // });

        // // Now call the bookmarks API
        // await getAllBookmarksAPI();

        // offlineUploader =
        //     OfflineAntibioticUploader(context); // Initialize the uploader
        // offlineUploader.checkAndUploadOfflineAntibiotics();
      } else if (response.statusCode == 401) {
        debugPrint('Unauthorized: ${response.body}');
        // navigateToLoginScreen(context);
        throw Exception('Unauthorized. Please check your credentials.');
      } else {
        debugPrint('Failed to load data from API: ${response.statusCode}');
        throw Exception('Failed to load data from API');
      }
    } catch (e) {
      debugPrint('Error fetching from API: $e');
      return false;
      // throw Exception('Error fetching from API');
      // _showToast("Failed to fetch data.");
    }
  }

  Future<List<AntibioticWithStatus>> getAllBookmarksAPI() async {
    final baseUrl = Strings.baseUrl;

    try {
      // Make the API call to fetch bookmarks
      final response =
          await ApiClient(baseUrl: baseUrl).get('bookmarks/antibiotics');
      debugPrint("Response body bookmark list: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json
            .decode(utf8.decode(response.bodyBytes) // 👈 Fix encoding here too
                );
        // final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData.containsKey('data') && responseData['data'] is List) {
          final bookmarks = responseData['data'] as List;
          final bookmarkedIds = bookmarks
              .map((bookmark) => bookmark['antibiotic_id'] as String)
              .toList();

          // Update the local database based on bookmarked IDs
          for (var id in bookmarkedIds) {
            await DBHelper.updateBookmarkStatus(
                id, true); // Set bookmark to true
          }

          // Clear bookmarks that are not in the new list
          // await DBHelper.clearBookmarksNotInList(bookmarkedIds);

          // Fetch the updated bookmarked antibiotics
          final filteredData =
              await DBHelper.getAntibioticsByIds(bookmarkedIds);
          debugPrint("Filtered bookmarked antibiotics: $filteredData");

          // setState(() {
          //   _bookmarkedAntibiotics =
          //       filteredData; // Update the state with the new bookmarks
          // });

          return filteredData; // Return the updated list of bookmarked antibiotics
        }
      }
      //  else if (response.statusCode == 401) {
      //   navigateToLoginScreen(context);
      // }
      else if (response.statusCode == 404) {
        debugPrint('404 Error: No bookmarked antibiotics found.');
        return []; // Return an empty list on 404
      }

      throw Exception(
          'Failed to fetch bookmarks, status code: ${response.statusCode}');
    } catch (error) {
      debugPrint('Error fetching bookmarks: $error');
      return []; // Gracefully handle errors with an empty list
    }
  }

  void printRootAntibioticNames(String jsonResponse) {
    try {
      // Parse the JSON response
      final parsedJson = json.decode(jsonResponse);

      // Ensure the data is present and a list
      if (parsedJson['data'] is List) {
        final antibiotics = parsedJson['data'];

        // Filter and extract names where parent == "root"
        final rootAntibiotics = antibiotics
            .where((antibiotic) =>
                antibiotic['parent'] == 'root') // Filter by parent
            .map((antibiotic) => antibiotic['name']) // Extract names
            .toList();

        debugPrint('Antibiotic Names with parent = root: $rootAntibiotics');
      } else {
        debugPrint('No data found or invalid structure');
      }
    } catch (e) {
      debugPrint('Error parsing JSON response: $e');
    }
  }
}
