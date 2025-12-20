import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';

class ELearnApiService {
  final ApiClient apiClient;

  ELearnApiService({required this.apiClient});

  // Fetch eLearns by site ID
  Future<Map<String, dynamic>> fetchELearns(String siteId) async {
    final String endpoint = 'elearns?site_id=$siteId';
    debugPrint('Elearns Endpoint: $endpoint');

    try {
      final response = await apiClient.get(endpoint);
      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      Map<String, dynamic> responseData = {};
      try {
        if (response.body != null && response.body.isNotEmpty) {
          responseData = json.decode(response.body) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Failed to decode response body: $e');
        responseData = {'raw': response.body};
      }

      return {
        'status': response.statusCode,
        'body': responseData,
      };
    } catch (e) {
      debugPrint('Error fetching e-learns: $e');
      return {
        'status': -1,
        'error': e.toString(),
      };
    }
  }

// Fetch eLearn by ID
  Future<Map<String, dynamic>> fetchELearnByID(String elearnId) async {
    final String endpoint = 'elearns/$elearnId';
    debugPrint('Elearn by ID Endpoint: $endpoint');

    try {
      final response = await apiClient.get(endpoint);
      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body : ${response.body}');

      Map<String, dynamic> responseData = {};
      try {
        if (response.body != null && response.body.isNotEmpty) {
          responseData = json.decode(response.body) as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('Failed to decode response body: $e');
        responseData = {'raw': response.body};
      }

      return {
        'status': response.statusCode,
        'body': responseData,
      };
    } catch (e) {
      debugPrint('Error fetching e-learn by ID: $e');
      return {
        'status': -1,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> postElearnMetric(
      List<Map<String, dynamic>> metrics) async {
    const String endpoint = 'metric/elearns';

    debugPrint('Post ELearn Metric Endpoint: $endpoint');

    try {
      final response = await apiClient.post(endpoint, body: metrics);

      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      Map<String, dynamic> responseData = {};
      try {
        responseData = json.decode(response.body);
      } catch (e) {
        debugPrint('Failed to decode response body: $e');
      }

      return {
        'status': response.statusCode,
        'body': responseData,
      };
    } catch (e) {
      // Only throw on real network / unexpected errors
      throw Exception('Error posting e-learn metrics: $e');
    }
  }
}
