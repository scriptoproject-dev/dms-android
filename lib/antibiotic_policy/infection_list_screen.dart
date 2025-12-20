import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/antibiotic_policy/OfflineAntibioticUploader.dart';
import 'package:qr_scanner_app/antibiotic_policy/antibiotic_db_helper.dart';
import 'package:qr_scanner_app/antibiotic_policy/compliance_popup.dart';
import 'package:qr_scanner_app/antibiotic_policy/condition_list_screen.dart';
import 'package:qr_scanner_app/antibiotic_policy/html_content_page.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/antibiotic.dart';
import 'package:qr_scanner_app/models/antibiotic_with_status.dart';
import 'package:qr_scanner_app/utilities/is_truely_offline.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Database helper

class InfectionListScreen extends StatefulWidget {
  // final List<Antibiotic> infections;
  // final List<AntibioticWithStatus> antibiotics;
  // final Function onRefreshBookmarks;
  final Function? onRefreshBookmarks;

  const InfectionListScreen({
    super.key,
    // required this.infections,
    // required this.antibiotics,
    // required this.onRefreshBookmarks,
    this.onRefreshBookmarks,
  });

  @override
  InfectionListScreenState createState() => InfectionListScreenState();
}

class InfectionListScreenState extends State<InfectionListScreen> {
  // List<Antibiotic> infections = [];
  List<AntibioticWithStatus> antibiotics = [];
  bool isLoading = true;
  late OfflineAntibioticUploader offlineUploader;
  String searchQuery = '';
  final ApiClient apiClient = ApiClient(baseUrl: Strings.baseUrl);
  List<Antibiotic> searchedPolicies = [];
  bool fromSearchNavigation = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // offlineUploader = OfflineAntibioticUploader(); // Initialize the uploader
    // offlineUploader.checkAndUploadOfflineAntibiotics();
    _loadAntibioticsFromDatabase(); // Load data from the database

    // infections = widget.infections;
    // antibiotics = widget.antibiotics;
    //  _loadAntibioticsFromDatabase(); // Load data from the database
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAntibioticsFromDatabase() async {
    setState(() {
      isLoading = true; // Show loading indicator
    });

    try {
      // Fetch antibiotics from the local database
      final localAntibiotics = await DBHelper.getAntibiotics();
      setState(() {
        antibiotics =
            localAntibiotics; // Update the state with the fetched data
      });
    } catch (e) {
      debugPrint('Error loading antibiotics from database: $e');
      _showToast("Failed to load data from the database.");
    } finally {
      setState(() {
        isLoading = false; // Hide loading indicator
      });
    }
  }

  Future<void> _searchPolicies(String query) async {
    final prefs = await SharedPreferences.getInstance();
    String siteId = prefs.getString('site_id') ?? '';

    // final connectivityResult = await Connectivity().checkConnectivity();
    // if (connectivityResult == ConnectivityResult.none) {
    //   _showToast("Please connect to the internet for search");
    //   return;
    // }
    final offline = await isTrulyOffline();
    if (offline) {
      _showToast(
          "No internet connection. Please connect to the internet to search.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await apiClient.get(
          'antibiotics?search=$query&site_id=$siteId&type=policy&page=1&sort_order=asc&limit=10000');
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> data = jsonResponse['data'] ?? [];

        final List<Antibiotic> policies = data
            .map((item) => Antibiotic.fromJson(item))
            .where((item) => item.type == 'policy')
            .toList();

        setState(() {
          searchedPolicies = policies;
        });
      } else if (response.statusCode == 401) {
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (mounted) navigateToLoginScreen(context);
      } else {
        _showToast("Failed to fetch policies from server.");
      }
    } catch (e) {
      _showToast("Something went wrong during search.");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showSearchResults = searchQuery.isNotEmpty;
    final rootCategories = antibiotics
        .where((item) =>
            (item.antibiotic.parent == 'root' ||
                item.antibiotic.type == 'category') &&
            item.antibiotic.name
                .toLowerCase()
                .contains(searchQuery.toLowerCase()))
        .toList();
    debugPrint('Root Categories: $rootCategories');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false, // Disable default back button
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context); // Navigate back
                  },
                ),
                const Text(
                  "Antibiotic Policy",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16), // Space between title and search bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.grey, // Border color
                  width: 1.0, // Border width
                ),
              ),
              child: TextField(
                focusNode: _searchFocusNode,
                onChanged: (value) {
                  setState(() {
                    searchQuery = value; // Update the search query
                  });
                  if (value.isNotEmpty) {
                    _searchPolicies(value);
                  } else {
                    setState(() => searchedPolicies = []);
                  }
                },
                decoration: const InputDecoration(
                  hintText: 'Search',
                  hintStyle: TextStyle(color: searchColor),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: searchColor),
                ),
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
            ),
            const SizedBox(height: 8), // Optional: Space below the search bar
          ],
        ),
        toolbarHeight: 140, // Adjust height to accommodate the layout
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : showSearchResults
              ? _buildPolicySearchResults()
              : _buildRootCategoryList(rootCategories),
    );
  }

  Widget _buildPolicySearchResults() {
    if (searchedPolicies.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text("No matching policies found.",
              style: TextStyle(fontSize: 18, color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: searchedPolicies.length,
      itemBuilder: (context, index) {
        final item = searchedPolicies[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColors,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ListTile(
              title:
                  Text(item.name, style: const TextStyle(color: Colors.black)),
              onTap: () async {
                _searchFocusNode.unfocus();
                fromSearchNavigation = true;
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HtmlContentPage(
                      condition: AntibioticWithStatus(
                          antibiotic: item,
                          bookmarked: false,
                          connection: 'true'),
                      onRefreshBookmarks: widget.onRefreshBookmarks,
                    ),
                  ),
                );

                // if (result is Map &&
                //     result['compliance'] == true &&
                //     fromSearchNavigation) {
                //   final antibioticId = result['antibioticId'] as String;
                //   CompliancePopup.show(context, antibioticId, _submitForm);
                // }
                if (result is Map &&
                    result['compliance'] == true &&
                    fromSearchNavigation) {
                  // Close keyboard before showing popup
                  FocusScope.of(context).unfocus();

                  final antibioticId = result['antibioticId'] as String;
                  await Future.delayed(const Duration(
                      milliseconds: 100)); // Small delay for smooth UX
                  CompliancePopup.show(context, antibioticId, _submitForm);
                }

                fromSearchNavigation = false; // Reset after handling
              },
            ),
          ),
        );
      },
    );
  }

  // Future<void> _submitForm(List<Map<String, dynamic>> requestBody) async {
  //   debugPrint("submitForm requestBody-- $requestBody");
  //   try {
  //     final response = await ApiClient(baseUrl: Strings.baseUrl)
  //         .post('antibiotics/compile', body: requestBody);

  //     debugPrint('API Response submit: ${response.body}');
  //     final responseBody = json.decode(response.body);

  //     if (response.statusCode == 200) {
  //       final message = responseBody['message'] ?? "Submission successful";
  //       // _showToast(message);
  //       debugPrint("success submit --$message");
  //       // ThankYouPopup.show(context);
  //       // Navigator.pop(context);
  //       if (context.mounted) {
  //         Navigator.pop(context);
  //       }
  //       if (context.mounted) {
  //         // ThankYouPopup.show(context);
  //         // CelebrationPopup.show(navigatorKey.currentContext!);
  //       }
  //     } else if (response.statusCode == 401) {
  //       Fluttertoast.showToast(
  //           msg: 'Account Disabled. Please contact support.');
  //       await unregisterDeviceFromPushNotificationServer();
  //       if (mounted) navigateToLoginScreen(context);
  //     } else {
  //       final errorMessage =
  //           responseBody['message'] ?? "Submission failed. Try again.";
  //       _showToast(errorMessage);
  //     }
  //   } catch (e) {
  //     debugPrint('Error during submission: $e');
  //     _showToast("An error occurred during submission. Please try again.");
  //   }
  // }
  Future<void> _submitForm(List<Map<String, dynamic>> requestBody) async {
    debugPrint("submitForm requestBody infection-- $requestBody");

    try {
      final response = await ApiClient(baseUrl: Strings.baseUrl)
          .post('antibiotics/compile', body: requestBody);

      debugPrint('📡 API Response Status: ${response.statusCode}');
      debugPrint('📡 API Response Body: ${response.body}');

      // ✅ CHECK 401/403 FIRST - Throw exception immediately
      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('🚨 401/403 DETECTED - THROWING UnauthorizedException');
        throw UnauthorizedException(
            'Account Disabled. Status: ${response.statusCode}');
      }

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        final message = responseBody['message'] ?? "Submission successful";
        debugPrint("✅ Success submit: $message");

        // ✅ Close the current dialog/bottom sheet
        if (context.mounted) {
          Navigator.pop(context);
        }

        // ✅ Return normally - ComplianceService will show celebration
        return;
      } else {
        // ✅ Other error status codes
        final errorMessage =
            responseBody['message'] ?? "Submission failed. Try again.";
        debugPrint("❌ API Error: $errorMessage");
        throw Exception(errorMessage);
      }
    } catch (e) {
      // ✅ If it's UnauthorizedException, rethrow it immediately
      if (e is UnauthorizedException) {
        debugPrint('🚨 Rethrowing UnauthorizedException: $e');
        rethrow;
      }

      // ✅ For other errors, log and rethrow
      debugPrint('❌ Error during submission: $e');
      rethrow; // Rethrow so ComplianceService can handle it
    }
  }

  Widget _buildRootCategoryList(List<AntibioticWithStatus> categories) {
    if (categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "No Categories Available",
            style: TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final infection = categories[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColors,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ListTile(
              title: Text(infection.antibiotic.name,
                  style: const TextStyle(color: Colors.black)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ConditionListScreen(
                      parentId: infection.antibiotic.antibioticId,
                      infectionName: infection.antibiotic.name,
                      antibiotics: antibiotics,
                      onRefreshBookmarks: widget.onRefreshBookmarks,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
