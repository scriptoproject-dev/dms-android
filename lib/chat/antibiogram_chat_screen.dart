import 'dart:convert';

import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';

class AntibiogramChatScreen {
  Future<Map<String, dynamic>> fetchAntibiogram() async {
    const String endpoint = 'bulk/antibiogram';

    try {
      final response = await ApiClient(baseUrl: Strings.baseUrl).get(endpoint);

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
      throw Exception('Failed to fetch antibiogram data: $error');
    }
  }
}
