import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';

class AntibiogramApiService {
  final ApiClient apiClient;

  AntibiogramApiService({required this.apiClient});

  // Fetch Antibiogram Categories by site ID
  Future<Map<String, dynamic>> fetchAntibiogram() async {
    const String endpoint = 'bulk/antibiogram';

    debugPrint('Antibiogram Endpoint: $endpoint');
    debugPrint('Full URL: ${apiClient.baseUrl}$endpoint'); // Log the full URL

    try {
      // Send GET request
      final response = await apiClient.get(endpoint);

      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body Antibiogram: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 200) {
          return responseData;
        } else {
          throw Exception(
              responseData['message'] ?? 'Unexpected response from the server');
        }
      } else {
        throw Exception(
            'HTTP Error: ${response.statusCode}. Unable to fetch data.');
      }
    } catch (error) {
      // Catch and rethrow exceptions for error handling
      debugPrint('Error fetching antibiogram data: $error');
      throw Exception('Failed to fetch antibiogram data: $error');
    }
  }

  Future<Map<String, dynamic>> postAntibiogram(
      List<Map<String, dynamic>> requestBody) async {
    const String endpoint = 'view/antibiogram';
    debugPrint('Full URL: ${apiClient.baseUrl}$endpoint');

    try {
      // Use the API client's post method
      final response = await apiClient.post(endpoint, body: requestBody);
      debugPrint('Response Status Code Antibiogram: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      final Map<String, dynamic> responseData = {
        'status': response.statusCode,
        'body': response.body,
      };

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);
        // Merge the decoded body so caller has both status and actual data
        responseData.addAll(decoded);
      }
      return responseData;
    } catch (error) {
      debugPrint('Error posting antibiogram data: $error');
      // Return a special status for network failures
      return {
        'status': -1,
        'body': error.toString(),
      };
    }
  }

  Future<String> fetchAntibiogramFile(String siteId) async {
    final String endpoint = 'file/antibiogram/$siteId';
    debugPrint('Antibiogram File Endpoint: $endpoint');
    debugPrint('Full URL: ${apiClient.baseUrl}$endpoint'); // Log the full URL

    try {
      // Send GET request
      final response = await apiClient.get(endpoint);

      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body for file: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        if (responseData['status'] == 200) {
          final String downloadUrl = responseData['data']['download_url'] ?? '';
          return downloadUrl;
        } else {
          throw Exception(
              responseData['message'] ?? 'Unexpected response from the server');
        }
      } else {
        throw Exception(
            'HTTP Error: ${response.statusCode}. Unable to fetch data.');
      }
    } catch (error) {
      debugPrint('Error fetching antibiogram file: $error');
      throw Exception('Failed to fetch antibiogram file: $error');
    }
  }
}
