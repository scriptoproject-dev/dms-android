import 'dart:convert';

import 'package:flutter_html/flutter_html.dart';
import 'package:qr_scanner_app/chat/chat_manager.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatApiService {
  final String baseUrl;

  ChatApiService(this.baseUrl);

  Future<Map<String, dynamic>> fetchAntibiogramData() async {
    const String endpoint = 'bulk/antibiogram';

    try {
      final response = await ApiClient(baseUrl: baseUrl).get(endpoint);

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

  Future<void> fetchReasonsFromApi(
      Function setState, ChatManager chatManager) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String siteId = prefs.getString('site_id') ?? '';

      final response = await ApiClient(baseUrl: baseUrl)
          .get('reasons?site_id=$siteId&page=1&sort_order=asc&limit=10000');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> reasons = data['data'];

        if (reasons.isNotEmpty) {
          chatManager.fetchedReasons = reasons
              .map<String>((reason) => reason['reason'] as String)
              .toList();

          setState(() {
            chatManager.dynamicOptions = chatManager.fetchedReasons;
            chatManager.showDynamicOptions = true;
          });
        }
      }
    } catch (e) {
      setState(() {
        chatManager.chatMessages.add({
          'sender': 'bot',
          'message': "Failed to fetch reasons. Please try again later.",
        });
      });
    }
  }

  Future<void> fetchInfectionsFromApi(
      Function setState, ChatManager chatManager) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String siteId = prefs.getString('site_id') ?? '';

      final response =
          await ApiClient(baseUrl: baseUrl).get('antibiotics?site_id=$siteId');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['data'];
        final categoryOptions = data
            .where((item) => item['type'] == 'category')
            .map<String>((item) => item['name'] as String)
            .toList();

        setState(() {
          chatManager.chatMessages.add({
            'sender': 'bot',
            'message':
                "Enter the disease for which you need the antibiotic policy.",
          });
          chatManager.dynamicOptions = categoryOptions
              .where((option) => option != "Antibiotic Policy")
              .toList();
          chatManager.showDynamicOptions = true;
        });
      }
    } catch (e) {
      setState(() {
        chatManager.chatMessages.add({
          'sender': 'bot',
          'message': "Failed to fetch data. Please try again later.",
        });
      });
    }
  }

  Future<void> fetchSubcategoriesFromApi(
      String selectedOption, Function setState, ChatManager chatManager) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String siteId = prefs.getString('site_id') ?? '';

      final response =
          await ApiClient(baseUrl: baseUrl).get('antibiotics?site_id=$siteId');
      final jsonResponse = response.body;

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(jsonResponse)['data'];
        final selectedAntibiotic = data.firstWhere(
          (item) => item['name'] == selectedOption,
          orElse: () => null,
        );

        if (selectedAntibiotic != null) {
          if (selectedAntibiotic['type'] == 'policy') {
            setState(() {
              chatManager.chatMessages.add({
                'sender': 'bot',
                'message': Html(data: selectedAntibiotic['data']),
              });
            });
            // Call a method to ask follow-up questions if needed
          } else {
            final List<String>? childrenIds =
                selectedAntibiotic['children'] != null
                    ? List<String>.from(selectedAntibiotic['children'])
                    : null;

            if (childrenIds == null || childrenIds.isEmpty) {
              setState(() {
                chatManager.chatMessages.add({
                  'sender': 'bot',
                  'message': "No subcategories available for $selectedOption.",
                });
                chatManager.dynamicOptions = ["Go Back", "Main Menu"];
                chatManager.showDynamicOptions = true;
              });
            } else {
              final List<String> subcategoryOptions = data
                  .where((item) => childrenIds.contains(item['antibiotic_id']))
                  .map<String>((item) => item['name'] as String)
                  .toList();

              setState(() {
                chatManager.chatMessages.add({
                  'sender': 'bot',
                  'message': "Choose from the options below:",
                });
                chatManager.dynamicOptions = subcategoryOptions;
                chatManager.showDynamicOptions = true;
              });
            }
          }
        } else {
          setState(() {
            chatManager.chatMessages.add({
              'sender': 'bot',
              'message': "No matching antibiotic found.",
            });
            chatManager.dynamicOptions = ["Go Back", "Main Menu"];
            chatManager.showDynamicOptions = true;
          });
        }
      } else {
        setState(() {
          chatManager.chatMessages.add({
            'sender': 'bot',
            'message': "Failed to fetch data. Please try again later.",
          });
          chatManager.dynamicOptions = ["Go Back", "Main Menu"];
          chatManager.showDynamicOptions = true;
        });
      }
    } catch (e) {
      setState(() {
        chatManager.chatMessages.add({
          'sender': 'bot',
          'message':
              "An error occurred while fetching data. Please try again later.",
        });
        chatManager.dynamicOptions = ["Go Back", "Main Menu"];
        chatManager.showDynamicOptions = true;
      });
    }
  }
}
