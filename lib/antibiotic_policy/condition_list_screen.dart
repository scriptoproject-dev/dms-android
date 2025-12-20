import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/antibiotic_policy/OfflineAntibioticUploader.dart';
import 'package:qr_scanner_app/antibiotic_policy/compliance_popup.dart';
import 'package:qr_scanner_app/antibiotic_policy/html_content_page.dart';
import 'package:qr_scanner_app/antibiotic_policy/offline_compliance_uploader.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/antibiotic_with_status.dart';
import 'package:qr_scanner_app/models/reasons.dart';
import 'package:qr_scanner_app/routes.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';

class ConditionListScreen extends StatefulWidget {
  final String parentId;
  final String infectionName;
  final List<AntibioticWithStatus> antibiotics;
  final Function? onRefreshBookmarks;
  final String? currentLevel;

  const ConditionListScreen({
    super.key,
    required this.parentId,
    required this.infectionName,
    required this.antibiotics,
    this.onRefreshBookmarks,
    this.currentLevel,
  });

  @override
  ConditionListScreenState createState() => ConditionListScreenState();
}

class ConditionListScreenState extends State<ConditionListScreen> {
  List<Reason> reasons = []; // Holds reasons from API
  String? selectedReasonId; // To store the selected reason ID
  String? selectedReason; // To store the selected reason text
  String? othersReasonId;
  String messageText = ""; // Stores the text input for "Others"
  bool isSubmitting = false; // Tracks submission state
  late OfflineAntibioticUploader offlineUploader;
  late OfflineComplianceUploader complianceUploader;

  late String currentParentId;
  late String currentTitle;
  late List<AntibioticWithStatus> currentChildren;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    currentParentId = widget.parentId;
    currentTitle = widget.infectionName;
    currentChildren = _getChildren(widget.parentId);
  }

  List<AntibioticWithStatus> _getChildren(String parentId) {
    return widget.antibiotics
        .where((item) => item.antibiotic.parent == parentId)
        .toList();
  }

  Future<void> _navigateToNext(AntibioticWithStatus selectedChild) async {
    debugPrint("selectedChild---$selectedChild");

    // ✅ First priority: If type == policy, go to HTML page directly
    if (selectedChild.antibiotic.type == 'policy') {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HtmlContentPage(
            condition: selectedChild,
            onRefreshBookmarks: widget.onRefreshBookmarks,
          ),
        ),
      );

      // Check for compliance on returning
      if (result is Map) {
        if (result['compliance'] == true) {
          final antibioticId = result['antibioticId'] as String;
          CompliancePopup.show(context, antibioticId, _submitForm);
        }
      }
      return; // ✅ Stop here, don’t go to children check
    }

    // ✅ Otherwise, check children
    final children = _getChildren(selectedChild.antibiotic.antibioticId);
    if (children.isNotEmpty) {
      // Navigate to next condition list
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConditionListScreen(
            parentId: selectedChild.antibiotic.antibioticId,
            infectionName: selectedChild.antibiotic.name,
            antibiotics: widget.antibiotics,
            onRefreshBookmarks: widget.onRefreshBookmarks,
          ),
        ),
      );
    } else {
      // Show a message or update UI
      setState(() {
        currentTitle = selectedChild.antibiotic.name;
        currentChildren = [];
        searchQuery = '';
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final result = ModalRoute.of(context)?.settings.arguments;
    if (result is Map && result['showCompliancePopup'] == true) {
      final antibioticId = result['antibioticId'] as String;
      CompliancePopup.show(context, antibioticId, _submitForm);
    }
  }

  Future<void> _submitForm(List<Map<String, dynamic>> requestBody) async {
    debugPrint("submitForm requestBody condition-- $requestBody");
    try {
      final response = await ApiClient(baseUrl: Strings.baseUrl)
          .post('antibiotics/compile', body: requestBody);

      debugPrint('API Response submit: ${response.body}');

      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('Unauthorized (${response.statusCode}) - logging out');
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (mounted) {
          navigateToLoginScreen(context);
        }
        // return; // Exit early
        throw Exception('Authentication failed: ${response.statusCode}');
      }

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        final message = responseBody['message'] ?? "Submission successful";
        // _showToast(message);
        debugPrint("success submit --$message");
        if (context.mounted) {
          Navigator.pop(context);
        }
        if (context.mounted) {
          // ThankYouPopup.show(context);
          // CelebrationPopup.show(navigatorKey.currentContext!);
        }
      }
      //  else if (response.statusCode == 401) {
      //   navigateToLoginScreen(context);
      // }
      else {
        final errorMessage =
            responseBody['message'] ?? "Submission failed. Try again.";
        _showToast(errorMessage);
        throw Exception('Submission failed: $errorMessage');
      }
    } catch (e) {
      debugPrint('Error during submission: $e');
      // _showToast("An error occurred during submission. Please try again.");
      if (!e.toString().contains('Authentication failed')) {
        _showToast("An error occurred during submission. Please try again.");
      }
      rethrow;
    }
  }

  int getCurrentEpochTime() {
    final now = DateTime.now(); // Get the current date and time
    return now.millisecondsSinceEpoch ~/
        1000; // Convert milliseconds to seconds
  }

  // Display a toast message
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
    final filteredChildren = currentChildren
        .where((item) => item.antibiotic.name
            .toLowerCase()
            .contains(searchQuery.toLowerCase()))
        .toList();

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
                Expanded(
                  child: Text(
                    currentTitle,
                    maxLines: 2,
                    softWrap: true,
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // Navigate to Home
                    Navigator.pushNamed(context, Routes.home);
                  },
                  child: Image.asset(
                    'assets/images/home_icon.png',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16), // Space between title and search bar
            Container(
              // padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.grey,
                  width: 1.0,
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  Fluttertoast.showToast(
                    msg: "Search is disabled here",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400], // 👈 Light grey background
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.grey,
                      width: 1.0,
                    ),
                  ),
                  child: TextField(
                    enabled: false,
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value; // Update the search query
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      // hintStyle: TextStyle(color: searchColor),
                      hintStyle: TextStyle(
                        color: Color.fromARGB(255, 117, 116, 116),
                      ),
                      border: InputBorder.none,
                      // icon: Icon(Icons.search, color: searchColor),
                      icon: Icon(Icons.search,
                          color: Color.fromARGB(255, 117, 116, 116)),
                    ),
                    style: const TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
        toolbarHeight: 140, // Adjust height to accommodate the layout
      ),
      body: filteredChildren.isEmpty
          ? _buildNoConditionsMessage()
          : Column(
              children: [
                const SizedBox(height: 8.0), // Add spacing at the top
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredChildren.length,
                    itemBuilder: (context, index) {
                      final child = filteredChildren[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: backgroundColors,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: ListTile(
                            title: Text(
                              child.antibiotic.name,
                              style: const TextStyle(color: Colors.black),
                            ),
                            onTap: () => _navigateToNext(child),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNoConditionsMessage() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          Strings.noConditionsMessage,
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
