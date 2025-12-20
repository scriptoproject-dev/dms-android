import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/home/bottom_nav.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/feedback_link.dart';
import 'package:qr_scanner_app/styles.dart';
import 'package:qr_scanner_app/utilities/notification_service.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  FeedbackScreenState createState() => FeedbackScreenState();
}

class FeedbackScreenState extends State<FeedbackScreen> {
  bool _isFormSubmitted = false;
  final TextEditingController _messageController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedCategory;
  bool isUnreadNotification = false;
  String? _feedbackLink; // Store the fetched link
  bool _isLoadingLink = true;
  bool _isOnline = true; // Track online/offline status
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Future<String?> _getPhotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    String? photoUrl = prefs.getString('photo_url');
    debugPrint('Stored Photo URL: $photoUrl');
    return photoUrl;
  }

  final Map<String, String> _categoryKeywords = {
    'Tech Support': 'tech_support',
    'Content Related': 'content_related',
    'General Feedback': 'general_feedback',
  };

  final List<String> _categories = [
    'Tech Support',
    'Content Related',
    'General Feedback'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUnreadNotifications();
    _checkInitialConnectivity();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  // Check initial connectivity status
  Future<void> _checkInitialConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult.first != ConnectivityResult.none;
    });

    if (_isOnline) {
      _fetchFeedbackLink();
    } else {
      setState(() {
        _isLoadingLink = false;
      });
    }
  }

  // Setup connectivity listener
  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final bool wasOffline = !_isOnline;
        final bool isNowOnline = results.first != ConnectivityResult.none;

        setState(() {
          _isOnline = isNowOnline;
        });

        // If device was offline and now comes online, fetch the link
        if (wasOffline && isNowOnline) {
          debugPrint('Network connection restored, fetching feedback link...');
          setState(() {
            _isLoadingLink = true;
          });
          _fetchFeedbackLink();
        }

        // If device goes offline
        if (!isNowOnline) {
          debugPrint('Network connection lost');
        }
      },
    );
  }

  Future<void> _fetchFeedbackLink() async {
    try {
      final baseUrl = Strings.baseUrl;
      final response = await ApiClient(baseUrl: baseUrl).get('feedback_link');

      debugPrint("Feedback link response: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 200 && responseData['data'] != null) {
          // Parse using the model class
          final feedbackLinkData = FeedbackLink.fromJson(responseData['data']);

          if (feedbackLinkData.link != null &&
              feedbackLinkData.link!.isNotEmpty &&
              feedbackLinkData.link!.startsWith('http')) {
            setState(() {
              _feedbackLink = feedbackLinkData.link;
              _isLoadingLink = false;
            });

            debugPrint("Feedback link fetched: $_feedbackLink");
            debugPrint("Unique ID: ${feedbackLinkData.uniqueId}");
            debugPrint("Active: ${feedbackLinkData.active}");
            debugPrint("Created by: ${feedbackLinkData.auditLog?.createdBy}");
          } else {
            // Link is not proper
            setState(() {
              _feedbackLink = null;
              _isLoadingLink = false;
            });
            _showToast('Link is not available. Please verify');
            debugPrint("Invalid or empty feedback link received");
          }
        } else {
          setState(() {
            _feedbackLink = null;
            _isLoadingLink = false;
          });
          _showToast('Link is not available. Please verify');
          debugPrint("Failed to parse feedback link from response");
        }
        //   setState(() {
        //     _feedbackLink = feedbackLinkData.link;
        //     _isLoadingLink = false;
        //   });

        //   debugPrint("Feedback link fetched: $_feedbackLink");
        //   debugPrint("Unique ID: ${feedbackLinkData.uniqueId}");
        //   debugPrint("Active: ${feedbackLinkData.active}");
        //   debugPrint("Created by: ${feedbackLinkData.auditLog?.createdBy}");
        // } else {
        //   setState(() {
        //     _isLoadingLink = false;
        //   });
        //   debugPrint("Failed to parse feedback link from response");
        // }
      } else if (response.statusCode == 401) {
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (mounted) navigateToLoginScreen(context);
      } else {
        setState(() {
          _isLoadingLink = false;
        });
        debugPrint("Failed to fetch feedback link: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _isLoadingLink = false;
      });
      debugPrint("Error fetching feedback link: $e");
    }
  }

  // Pull to refresh handler
  Future<void> _onRefresh() async {
    debugPrint('Pull to refresh triggered');

    if (!_isOnline) {
      _showToast('No internet connection');
      return;
    }

    setState(() {
      _isLoadingLink = true;
    });

    await _fetchFeedbackLink();
    await _fetchUnreadNotifications();
  }

  Future<void> _launchREDCapUrl() async {
    if (_feedbackLink == null || _feedbackLink!.isEmpty) {
      _showToast('Feedback link not available');
      return;
    }

    final Uri redcapUrl = Uri.parse(_feedbackLink!);

    try {
      if (await canLaunchUrl(redcapUrl)) {
        await launchUrl(
          redcapUrl,
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showToast('Unable to open feedback survey link');
        debugPrint('Could not launch $redcapUrl');
      }
    } catch (e) {
      _showToast('Error opening feedback survey link');
      debugPrint('Error launching URL: $e');
    }
  }

  Future<void> _fetchUnreadNotifications() async {
    final notificationService = NotificationService();
    final notifications =
        await notificationService.checkForUnreadNotifications();
    setState(() {
      isUnreadNotification = notifications;
    });
  }

  Future<void> _copyToClipboard(String text, String type) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showToast('$type copied to clipboard');
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final Uri url = Uri(scheme: 'tel', path: phoneNumber);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        _showToast('No phone app found on your device');
      }
    } catch (e) {
      debugPrint('Could not launch phone app: $e');
      _showToast('Unable to make phone call');
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: _encodeQueryParameters(<String, String>{
        'subject': 'Support Request',
        'body': 'Hello,',
      }),
    );

    try {
      final launched = await launchUrl(
        emailLaunchUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showToast('No email app found on your device');
      }
    } catch (e) {
      debugPrint('Could not launch email client: $e');
      _showToast('No email app found on your device');
    }
  }

  // ✅ Helper method to properly encode query parameters
  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void _showCategoryBottomSheet() {
    final ScrollController scrollController = ScrollController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Category',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 180,
                child: Scrollbar(
                  thickness: 6,
                  radius: const Radius.circular(8),
                  thumbVisibility: true,
                  controller: scrollController,
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(right: 0.0, left: 0.0),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      return RadioListTile<String>(
                        value: _categories[index],
                        groupValue: _selectedCategory,
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                          Navigator.pop(context);
                        },
                        title: Text(_categories[index]),
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitFeedback() async {
    if (_formKey.currentState?.validate() ?? false) {
      String selectedKeyword = _categoryKeywords[_selectedCategory]!;
      String message = _messageController.text;
      final baseUrl = Strings.baseUrl;

      Map<String, dynamic> requestBody = {
        'category': selectedKeyword,
        'message': message,
      };

      try {
        final response = await ApiClient(baseUrl: baseUrl)
            .post('feedbacks', body: requestBody);
        debugPrint("Feedback response ${response.body}");
        if (response.statusCode == 201) {
          _showToast("Feedback submitted successfully");

          setState(() {
            _selectedCategory = null;
            _messageController.clear();
            _isFormSubmitted = false;
          });
        } else if (response.statusCode == 401) {
          Fluttertoast.showToast(
              msg: 'Account Disabled. Please contact support.');
          await unregisterDeviceFromPushNotificationServer();
          if (mounted) navigateToLoginScreen(context);
        } else {
          _showToast("Failed to submit feedback: ${response.body}");
        }
      } catch (e) {
        _showToast("Error: $e");
      }
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        automaticallyImplyLeading: false,
        title: const Text(
          "Feedback",
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
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: primaryColor,
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(), // Enable pull to refresh even when content doesn't scroll
          child: Form(
            key: _formKey,
            autovalidateMode: _isFormSubmitted
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _showCategoryBottomSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (_isFormSubmitted && _selectedCategory == null)
                              ? Colors.red
                              : gray,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCategory ?? 'Category',
                            style: TextStyle(
                              fontSize: 16,
                              color: _selectedCategory == null
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  if (_isFormSubmitted && _selectedCategory == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Please select a category',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _messageController,
                    maxLines: 6,
                    decoration: CustomStyles.textFieldDecoration.copyWith(
                      alignLabelWithHint: true,
                      labelText: Strings.enterMessageHint,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a message';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _isFormSubmitted = true;
                      });

                      if (_formKey.currentState?.validate() ?? false) {
                        await _submitFeedback();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      Strings.submitButton,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer Support',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: darkBlack,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _launchPhone('7411324485'),
                              child: const Row(
                                children: [
                                  Icon(Icons.phone, color: Colors.black54),
                                  SizedBox(width: 8),
                                  Text(
                                    '7411324485',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: primaryColor,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _copyToClipboard(
                                  '7411324485', 'Phone number'),
                              child: const Icon(
                                Icons.content_copy,
                                size: 18,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _launchEmail('bharat.k@sjri.res.in'),
                              child: const Row(
                                children: [
                                  Icon(Icons.email, color: Colors.black54),
                                  SizedBox(width: 8),
                                  Text(
                                    'bharat.k@sjri.res.in',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: primaryColor,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _copyToClipboard(
                                  'bharat.k@sjri.res.in', 'Email'),
                              child: const Icon(
                                Icons.content_copy,
                                size: 18,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // REDCap Survey Link
                        _isLoadingLink
                            ? const Row(
                                children: [
                                  Icon(Icons.assignment, color: Colors.black54),
                                  SizedBox(width: 8),
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Loading feedback link...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              )
                            : _feedbackLink != null && _feedbackLink!.isNotEmpty
                                ? GestureDetector(
                                    onTap: _launchREDCapUrl,
                                    child: const Row(
                                      children: [
                                        Icon(Icons.assignment,
                                            color: Colors.black54),
                                        SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Monthly Feedback Survey (REDCap)',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: primaryColor,
                                              fontWeight: FontWeight.w500,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.launch,
                                          size: 16,
                                          color: primaryColor,
                                        ),
                                      ],
                                    ),
                                  )
                                : const Row(
                                    children: [
                                      Icon(Icons.assignment,
                                          color: Colors.black54),
                                      SizedBox(width: 8),
                                      Text(
                                        'Feedback link not available',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: 4,
        isUnreadNotification: isUnreadNotification,
      ),
    );
  }
}
