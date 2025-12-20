import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/antibiotic_policy/antibiotic_db_helper.dart';
import 'package:qr_scanner_app/antibiotic_policy/compliance_popup.dart';
import 'package:qr_scanner_app/bookmark_list.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/home/bottom_nav.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/antibiotic.dart';
import 'package:qr_scanner_app/models/antibiotic_with_status.dart';
import 'package:qr_scanner_app/utilities/connectivity_helper.dart';
import 'package:qr_scanner_app/utilities/notification_service.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkScreen extends StatefulWidget {
  // final List<AntibioticWithStatus> bookmarkedAntibiotics;
  final Function? onRefreshBookmarks;

  const BookmarkScreen(
      {super.key,
      // required this.bookmarkedAntibiotics,
      required this.onRefreshBookmarks});

  @override
  _BookmarkScreenState createState() => _BookmarkScreenState();
}

class _BookmarkScreenState extends State<BookmarkScreen> {
  // late Future<List<BookmarkData>> _bookmarksFuture;
  List<AntibioticWithStatus> bookmarkedAntibiotics =
      []; // Local state for bookmarks
  bool _isLoading = true;
  bool isUnreadNotification = false;

  @override
  void initState() {
    super.initState();
    // print("bookmarkedAntibiotics--${widget.bookmarkedAntibiotics}");
    _fetchUnreadNotifications();
    // _fetchBookmarks(); // Fetch bookmarks when the screen is initialized
    _fetchBookmarks().then((_) {
      setState(() {
        _isLoading = false; // Set flag to false when bookmarks are loaded
      });
    });
  }

  Future<void> _fetchUnreadNotifications() async {
    final notificationService = NotificationService();
    final notifications =
        await notificationService.checkForUnreadNotifications();
    setState(() {
      isUnreadNotification = notifications;
    });
  }

  // Future<void> _fetchBookmarks() async {
  //   final bookmarks = await getAllBookmarksFromDatabase();
  //   setState(() {
  //     bookmarkedAntibiotics =
  //         bookmarks; // Update local state with fetched bookmarks
  //   });
  // }

  Future<void> _fetchBookmarks() async {
    bool offline = await ConnectivityHelper.isOffline();

    if (offline) {
      // Offline: Fetch bookmarks from the database
      final bookmarks = await getAllBookmarksFromDatabase();
      setState(() {
        bookmarkedAntibiotics = bookmarks;
        // bookmarkedAntibiotics =
        //     bookmarks; // Update local state with fetched bookmarks
      });
    } else {
      // Online: Fetch bookmarks from the API
      try {
        final bookmarks = await getAllBookmarksAPI();
        setState(() {
          bookmarkedAntibiotics =
              bookmarks; // Update local state with fetched bookmarks
        });

        // Check if there are any offline bookmarks and upload them to the server
        // final offlineBookmarks = await getAllBookmarksFromDatabase();
        // if (offlineBookmarks.isNotEmpty) {
        //   final bookmarkUploader = BookmarkUploader();
        //   await bookmarkUploader.uploadOfflineBookmarks(offlineBookmarks);
        // }
      } catch (error) {
        debugPrint('Error fetching bookmarks: $error');
        // Fallback to fetching from the database if the API call fails
        final bookmarks = await getAllBookmarksFromDatabase();
        setState(() {
          bookmarkedAntibiotics = bookmarks;
        });
      }
    }
  }

  Future<List<AntibioticWithStatus>> getAllBookmarksFromDatabase() async {
    // Fetch only the antibiotics that are bookmarked (bookmarked = true)
    final allAntibiotics = await DBHelper.getAntibiotics();
    return allAntibiotics.where((antibiotic) => antibiotic.bookmarked).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Listen for results when navigating back from the HTML screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final result = ModalRoute.of(context)?.settings.arguments;
      if (result is Map) {
        final refresh = result['refresh'] as bool? ?? false;
        final antibioticId = result['antibioticId'] as String;
        final compliance = result['compliance'] as bool? ?? false;
        debugPrint("Compliancess: $compliance, Antibiotic ID: $antibioticId");

        if (refresh) {
          debugPrint("Refreshing bookmarks...");
          // Call the function to fetch the updated bookmarks
          _fetchBookmarks();
        }
        debugPrint("compliance--scrren$compliance");
        debugPrint("mounted --scrren$mounted");
        if (compliance && mounted && (bookmarkedAntibiotics.isNotEmpty)) {
          // Show compliance popup if needed

          Future.delayed(const Duration(milliseconds: 100), () {
            CompliancePopup.show(context, antibioticId, _submitForm);
          });
        }
      }
    });
  }

  Future<List<AntibioticWithStatus>> getAllBookmarksAPI() async {
    final baseUrl = Strings.baseUrl;

    try {
      final response =
          await ApiClient(baseUrl: baseUrl).get('bookmarks/antibiotics');
      debugPrint("response body bookmarklistss--${response.body}");

      if (response.statusCode == 200) {
        // final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> responseData =
            json.decode(utf8.decode(response.bodyBytes) // 👈 Fix encoding here
                );
        final List<dynamic> bookmarks = responseData['data'];
        // return bookmarks
        //     .map((json) => AntibioticWithStatus.fromJson(json))
        //     .toList();
        return bookmarks.map((json) {
          final antibiotic = Antibiotic.fromJson(json);
          return AntibioticWithStatus(
            antibiotic: antibiotic,
            bookmarked: json['bookmarked'] ?? true,
            connection: json['connection'] ?? '',
          );
        }).toList();
      } else {
        throw Exception(
            'Failed to fetch bookmarks, status code: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('Error fetching bookmarks: $error');
      return []; // Gracefully handle errors with an empty list
    }
  }

  Future<String?> _getPhotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('photo_url');
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

  // @override
  // void initState() {
  //   super.initState();
  //   // _bookmarksFuture = _fetchBookmarks();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        automaticallyImplyLeading: false,
        title: const Text(
          "Bookmarks",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/profile');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FutureBuilder<String?>(
                future: _getPhotoUrl(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey,
                      child: CircularProgressIndicator(),
                    );
                  } else if (snapshot.data != null &&
                      snapshot.data!.isNotEmpty) {
                    return CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(snapshot.data!),
                    );
                  } else {
                    return const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    );
                  }
                },
              ),
            ),
          ),
        ],
        toolbarHeight: 66,
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(), // Show loading progress
                )
              : bookmarkedAntibiotics.isEmpty
                  ? const Center(
                      child: Text('No bookmarks found'),
                    )
                  : Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 8.0),
                      child: BookmarkList(
                        bookmarkedAntibiotics: bookmarkedAntibiotics,
                        submitForm: _submitForm,
                        onRefreshBookmarks: widget.onRefreshBookmarks,
                        fetchBookmarks: _fetchBookmarks,
                      ),
                    )
        ],
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: 1,
        onRefreshBookmarks: widget.onRefreshBookmarks,
        isUnreadNotification: isUnreadNotification,
      ),
    );
  }

  Future<void> _submitForm(List<Map<String, dynamic>> requestBody) async {
    debugPrint("submitForm requestBody bookmark-- $requestBody");
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
        return; // Exit early
      }

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        final message = responseBody['message'] ?? "Submission successful";
        debugPrint("success submit --$message");
      } else {
        final errorMessage =
            responseBody['message'] ?? "Submission failed. Try again.";
        _showToast(errorMessage);
      }
    } catch (e) {
      debugPrint('Error during submission: $e');
      _showToast("An error occurred during submission. Please try again.");
    }
  }
}
