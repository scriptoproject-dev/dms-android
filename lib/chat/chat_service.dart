import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  // Constructor doesn't need baseUrl anymore as it's fetched dynamically
  ChatService();

  Future<ChatResponse> fetchChatMessages({
    required int page,
    String sortOrder = 'asc',
    int limit = 10,
  }) async {
    // Fetch baseUrl and siteId dynamically
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = Strings.baseUrl;
    final siteId = prefs.getString('site_id') ?? '';

    if (siteId.isEmpty) {
      debugPrint('Error: Site ID is missing');
      throw Exception('Site ID is required.');
    }

    try {
      debugPrint('Requesting Chat API: $baseUrl/chats?site_id=$siteId');

      final response =
          await ApiClient(baseUrl: baseUrl).get('chats?site_id=$siteId');

      debugPrint('Chat API Response: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ChatResponse.fromJson(
            jsonResponse); // Parse the response into the model
      } else {
        debugPrint('Failed Chat API Response: ${response.body}');
        throw Exception(
            'Failed to fetch chat messages. Status: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error during Chat API call: $error');
      throw Exception('An error occurred while fetching chat messages.');
    }
  }
}
