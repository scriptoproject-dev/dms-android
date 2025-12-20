import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:qr_scanner_app/antibiotic_policy/antibiotic_db_helper.dart';
import 'package:qr_scanner_app/antibiotic_policy/compliance_popup.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/antibiotic.dart';
import 'package:qr_scanner_app/models/antibiotic_with_status.dart';
import 'package:qr_scanner_app/routes.dart';
import 'package:qr_scanner_app/utilities/connectivity_helper.dart';
import 'package:qr_scanner_app/utilities/is_truely_offline.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:url_launcher/url_launcher.dart';

class HtmlContentPage extends StatefulWidget {
  final AntibioticWithStatus condition;
  final Function? onRefreshBookmarks;
  final Function? onBookmarkToggle;

  const HtmlContentPage({
    super.key,
    required this.condition,
    this.onRefreshBookmarks,
    this.onBookmarkToggle,
  });

  @override
  HtmlScreenState createState() => HtmlScreenState();
}

class HtmlScreenState extends State<HtmlContentPage> {
  late bool isBookmarked;
  late AntibioticWithStatus currentAntibiotic;
  bool isLoading = true;
  double _uploadProgress = 0.0;
  late Connectivity connectivity;

  Future<bool> _onWillPop() async {
    if (widget.onBookmarkToggle != null) {
      widget.onBookmarkToggle!();
    }

    Navigator.pop(context, {
      'refresh': true,
      'antibioticId': widget.condition.antibiotic.antibioticId,
      'compliance': true,
    });

    return false;
  }

  bool _isDataLoaded = false;
  bool _showBookmarkIcon = false;
  List<AntibioticWithStatus> _allAntibiotics = [];

  final Map<String, bool> _expanded = {
    'line_1': true,
    'line_2': true,
    'line_3': true,
  };
  bool get _anyExpanded => _expanded.values.any((v) => v == true);

  @override
  void initState() {
    super.initState();
    connectivity = Connectivity();
    debugPrint("Initial bookmark state: ${widget.condition.bookmarked}");
    debugPrint("Condition data: ${widget.condition.toString()}");
    debugPrint(
        "Aware Classification: ${widget.condition.antibiotic.awareClassification}"); // ⬅️ ADD THIS
    isBookmarked = false;
    isLoading = true;
    currentAntibiotic = AntibioticWithStatus(
      antibiotic: Antibiotic(
          antibioticId: '',
          name: '',
          parent: '',
          ancestors: [],
          siteId: '',
          status: ''),
      bookmarked: false,
      connection: '',
    );
    _loadAntibioticData().then((_) {
      setState(() {
        _isDataLoaded = true;
        _showBookmarkIcon = true;
      });
    });
    _sendViewAPI();
    getOfflineAntibiotics();

    DBHelper.getAntibiotics().then((list) {
      setState(() {
        _allAntibiotics = list;
      });
    });
  }

  // Image viewer method
  void _showImageViewer(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageViewerPage(imageUrl: imageUrl),
      ),
    );
  }

  // Helper method to get image provider
  ImageProvider _getImageProvider(String imageUrl) {
    // Handle base64 images
    if (imageUrl.startsWith('data:image')) {
      final base64String = imageUrl.split(',')[1];
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    }

    // Handle network images
    if (imageUrl.startsWith('http')) {
      return NetworkImage(imageUrl);
    }

    // Handle asset images
    return AssetImage(imageUrl);
  }

  // Method to build HTML with clickable images
  List<Widget> _buildHtmlWithClickableImages(String htmlData) {
    final List<Widget> widgets = [];

    // Split HTML by image tags to handle images separately
    final RegExp imgRegExp =
        RegExp(r'<img[^>]*src="([^"]*)"[^>]*>', caseSensitive: false);

    int lastEnd = 0;
    final matches = imgRegExp.allMatches(htmlData);

    for (final match in matches) {
      // Add HTML content before the image
      if (match.start > lastEnd) {
        final htmlBefore = htmlData.substring(lastEnd, match.start);
        if (htmlBefore.trim().isNotEmpty) {
          widgets.add(Html(data: htmlBefore));
        }
      }

      // Add the clickable image
      final src = match.group(1);
      if (src != null && src.isNotEmpty) {
        widgets.add(
          GestureDetector(
            onTap: () => _showImageViewer(src),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: _getImageProvider(src),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: const Text('Image not available'),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      }

      lastEnd = match.end;
    }

    // Add remaining HTML content after the last image
    if (lastEnd < htmlData.length) {
      final htmlAfter = htmlData.substring(lastEnd);
      if (htmlAfter.trim().isNotEmpty) {
        widgets.add(_buildHtmlWithLinks(htmlAfter));
        // widgets.add(Html(data: htmlAfter));
      }
    }

    // If no images found, just return the HTML as is
    if (widgets.isEmpty) {
      widgets.add(_buildHtmlWithLinks(htmlData));
      // widgets.add(Html(data: htmlData));
    }

    return widgets;
  }

  Widget _buildHtmlWithLinks(String htmlData) {
    return Html(
      data: htmlData,
      onLinkTap: (url, attributes, element) {
        if (url != null) {
          _handleLinkTap(url);
        }
      },
      style: {
        "a": Style(
          color: Colors.blue,
          textDecoration: TextDecoration.underline,
        ),
        "p": Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
        ),
      },
    );
  }

  Future<void> _handleLinkTap(String url) async {
    try {
      final Uri uri = Uri.parse(url);

      // Check if the URL can be launched
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Opens in external browser
        );
      } else {
        _showToast("Cannot open link: $url");
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      _showToast("Error opening link");
      debugPrint('Error launching URL: $e');
    }
  }

  Map<String, List<AntibioticWithStatus>> groupByLine(
      List<AntibioticWithStatus> antibiotics, String parentId) {
    final Map<String, List<AntibioticWithStatus>> grouped = {
      "line_1": [],
      "line_2": [],
      "line_3": [],
    };

    for (final ab in antibiotics) {
      if (ab.antibiotic.parent == parentId) {
        if (ab.antibiotic.type == "line_1") {
          grouped["line_1"]!.add(ab);
        } else if (ab.antibiotic.type == "line_2") {
          grouped["line_2"]!.add(ab);
        } else if (ab.antibiotic.type == "line_3") {
          grouped["line_3"]!.add(ab);
        }
      }
    }

    // Sort each line by index
    grouped["line_1"]!.sort((a, b) {
      final indexA = a.antibiotic.index ?? 999999;
      final indexB = b.antibiotic.index ?? 999999;
      return indexA.compareTo(indexB);
    });

    grouped["line_2"]!.sort((a, b) {
      final indexA = a.antibiotic.index ?? 999999;
      final indexB = b.antibiotic.index ?? 999999;
      return indexA.compareTo(indexB);
    });

    grouped["line_3"]!.sort((a, b) {
      final indexA = a.antibiotic.index ?? 999999;
      final indexB = b.antibiotic.index ?? 999999;
      return indexA.compareTo(indexB);
    });

    return grouped;
  }

  @override
  void dispose() {
    super.dispose();
  }

  static Future<List<Map<String, dynamic>>> getOfflineAntibiotics() async {
    final db = await DBHelper.getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'antibiotics',
      where: 'connection = ?',
      whereArgs: ['offline'],
    );

    debugPrint("getOfflineAntibiotics called.");
    debugPrint("Number of records found: ${maps.length}");

    return maps;
  }

  Future<bool> isAntibioticIdValid(String antibioticId) async {
    try {
      var result = await DBHelper.getAntibiotics();
      return result.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking antibiotic ID in local database: $e");
      return false;
    }
  }

  Future<void> _loadAntibioticData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      bool offline = await isTrulyOffline();
      List<String> bookmarkedIds = [];

      final fetchedAntibiotic = await DBHelper.getAntibioticsByIds(
          [widget.condition.antibiotic.antibioticId]);

      if (!mounted) return;

      if (fetchedAntibiotic.isNotEmpty) {
        setState(() {
          currentAntibiotic = fetchedAntibiotic.first;
          isBookmarked = fetchedAntibiotic.first.bookmarked;
        });

        debugPrint("✅ Loaded Antibiotic: ${currentAntibiotic.antibiotic.name}");
        debugPrint(
            "✅ Causative Organism: ${currentAntibiotic.antibiotic.causativeOrganism}");
        debugPrint(
            "✅ Full Antibiotic Data: ${currentAntibiotic.antibiotic.toString()}");
      } else {
        _showToast("Antibiotic not found.");
      }

      Future<void> fetchBookmarks() async {
        debugPrint("Checking bookmark status...");

        final offlineBookmarks = await getAllBookmarksFromDatabase();
        bookmarkedIds = offlineBookmarks
            .map((bookmark) => bookmark.antibiotic.antibioticId)
            .toList();

        if (!mounted) return;
        setState(() {
          isBookmarked =
              bookmarkedIds.contains(widget.condition.antibiotic.antibioticId);
        });

        if (!offline) {
          debugPrint("Online detected, trying to fetch from API...");
          try {
            final onlineBookmarks = await getAllBookmarksAPI();
            bookmarkedIds = onlineBookmarks
                .map((bookmark) => bookmark.antibiotic.antibioticId)
                .toList();

            if (!mounted) return;
            setState(() {
              isBookmarked = bookmarkedIds
                  .contains(widget.condition.antibiotic.antibioticId);
            });

            await DBHelper.updateBookmarkStatus(
                widget.condition.antibiotic.antibioticId, isBookmarked);
          } catch (e) {
            debugPrint("Online fetch failed, keeping offline bookmarks: $e");
          }
        } else {
          debugPrint("Offline mode - using local bookmarks.");
        }
      }

      fetchBookmarks();
    } catch (e) {
      debugPrint('Error loading antibiotic data: $e');
      _showToast("Failed to load antibiotic data.");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<List<AntibioticWithStatus>> getAllBookmarksAPI() async {
    final baseUrl = Strings.baseUrl;

    try {
      final response =
          await ApiClient(baseUrl: baseUrl).get('bookmarks/antibiotics');
      debugPrint("response body bookmarklistss--${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> bookmarks = responseData['data'];
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
      return [];
    }
  }

  int getCurrentEpochTime() {
    final now = DateTime.now();
    return now.millisecondsSinceEpoch ~/ 1000;
  }

  Future<void> _sendViewAPI() async {
    final baseUrl = Strings.baseUrl;
    debugPrint(
        "antibiotic_condition--${widget.condition.antibiotic.antibioticId}");
    final requestBody = [
      {
        "action": "view",
        "antibiotic_id": widget.condition.antibiotic.antibioticId,
        "view": true,
        "date": getCurrentEpochTime()
      }
    ];
    debugPrint('Calling antibiotic view API with body: $requestBody');

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.first == ConnectivityResult.none) {
        debugPrint('No internet connection. Storing data locally.');
        await storeViewDataLocally(requestBody);
        return;
      }

      final response = await ApiClient(baseUrl: baseUrl)
          .post('antibiotics/view', body: requestBody);
      debugPrint('API Response antibiotic view ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _showToast(data['message'] ?? "API call successful");
      } else if (response.statusCode == 401) {
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (mounted) navigateToLoginScreen(context);
      } else {
        _showToast("Failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('Error in antibiotic view: $e');
    }
  }

  Future<void> storeViewDataLocally(
      List<Map<String, dynamic>> requestBody) async {
    for (var data in requestBody) {
      debugPrint('Attempting to store view data locally: $data');

      if (data.containsKey('view') && data.containsKey('date')) {
        debugPrint('Storing view data locally: $data');
        await DBHelper.insertView(data);
      } else {
        debugPrint('Data does not contain required keys: $data');
      }
    }
    debugPrint('View data stored locally.');
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

  void _toggleBookmark() async {
    bool offline = await ConnectivityHelper.isOffline();
    final baseUrl = Strings.baseUrl;
    final requestBody = [
      {
        "antibiotic_id": widget.condition.antibiotic.antibioticId,
        "bookmarked": !isBookmarked
      }
    ];
    if (offline) {
      await DBHelper.updateBookmarkStatus(
          widget.condition.antibiotic.antibioticId, !isBookmarked);

      await DBHelper.updateConnectionStatus(
          widget.condition.antibiotic.antibioticId, 'offline');

      setState(() {
        isBookmarked = !isBookmarked;
      });
      _showToast(isBookmarked
          ? "Bookmarked ${widget.condition.antibiotic.name} Successfully!"
          : "Bookmark Removed for ${widget.condition.antibiotic.name}!");
    } else {
      try {
        final response = await ApiClient(baseUrl: baseUrl)
            .post('antibiotics/bookmark', body: requestBody);

        debugPrint('Bookmark API Response: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 200) {
            setState(() {
              isBookmarked = !isBookmarked;
            });

            await DBHelper.updateBookmarkStatus(
                widget.condition.antibiotic.antibioticId, isBookmarked);

            if (widget.onRefreshBookmarks != null) {
              widget.onRefreshBookmarks!();
            }

            _showToast(isBookmarked
                ? "Bookmarked ${widget.condition.antibiotic.name} Successfully!"
                : "Bookmark Removed for ${widget.condition.antibiotic.name}!");
          } else if (data['status'] == 401) {
            Fluttertoast.showToast(
                msg: 'Account Disabled. Please contact support.');
            await unregisterDeviceFromPushNotificationServer();
            if (mounted) navigateToLoginScreen(context);
          } else {
            _showToast(data['message'] ?? "Failed to update bookmark!");
          }
        } else if (response.statusCode == 401) {
          Fluttertoast.showToast(
              msg: 'Account Disabled. Please contact support.');
          await unregisterDeviceFromPushNotificationServer();
          if (mounted) navigateToLoginScreen(context);
        } else {
          _showToast("Failed to update bookmark: ${response.statusCode}");
        }
      } catch (e) {
        _showToast("Error: $e");
        debugPrint('Error in bookmark API: $e');
      }
    }
  }

  Future<List<AntibioticWithStatus>> getAllBookmarksFromDatabase() async {
    final allAntibiotics = await DBHelper.getAntibiotics();
    return allAntibiotics.where((antibiotic) => antibiotic.bookmarked).toList();
  }

  Future<void> _submitForm(List<Map<String, dynamic>> requestBody) async {
    debugPrint("🚨🚨🚨 _submitForm ACTUALLY CALLED IN HTML PAGE 🚨🚨🚨");
    debugPrint("🚨 Request Body: $requestBody");
    debugPrint("🚨 Stack trace: ${StackTrace.current}");

    try {
      final response = await ApiClient(baseUrl: Strings.baseUrl)
          .post('antibiotics/compile', body: requestBody);

      debugPrint('📡 API Response Status: ${response.statusCode}');
      debugPrint('📡 API Response Body: ${response.body}');

      // ✅ CHECK 401 FIRST - Throw exception immediately
      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('🚨🚨🚨 401/403 DETECTED - THROWING UnauthorizedException');
        throw UnauthorizedException(
            'Account Disabled. Status: ${response.statusCode}');
      }

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        final message = responseBody['message'] ?? "Submission successful";
        debugPrint("✅ Success submit: $message");
        // ✅ Return normally on success - no exception
        return;
      } else {
        // ✅ Other error codes - throw exception
        final errorMessage =
            responseBody['message'] ?? "Submission failed. Try again.";
        debugPrint("❌ API Error: $errorMessage");
        throw Exception(errorMessage);
      }
    } catch (e) {
      // ✅ If it's already UnauthorizedException, rethrow it
      if (e is UnauthorizedException) {
        debugPrint('🚨 Rethrowing UnauthorizedException: $e');
        rethrow;
      }

      // ✅ For other errors, log and rethrow
      debugPrint('❌ Error during submission: $e');
      rethrow; // ✅ Rethrow so ComplianceService can handle it
    }
  }

  // String _cleanHtmlData(String? htmlData) {
  //   if (htmlData == null || htmlData.isEmpty) return "";

  //   return htmlData
  //       .replaceAll(RegExp(r'\.{2,}'), '.')
  //       .replaceAll(RegExp(r'\?â€¦'), '?.')
  //       .replaceAll(RegExp(r'\s+\.\s+'), '. ')
  //       .replaceAll("'", "")
  //       .trim();
  // }
  String _cleanHtmlData(String? htmlData) {
    if (htmlData == null || htmlData.isEmpty) return "";

    // Map of common encoding issues to their correct characters
    final Map<String, String> replacements = {
      // Currency symbols - Rupee (multiple corrupted versions)
      'â‚¹': '₹',
      '&#8377;': '₹',
      '&rupee;': '₹',
      'â?1': '₹', // 👈 ADD THIS - corrupted rupee symbol
      'â‚¹': '₹', // Another variant
      'â‚¨': '₹', // Another variant

      // Currency symbols - Dollar
      '&#36;': '\$',
      '&dollar;': '\$',

      // Currency symbols - Euro
      'â‚¬': '€',
      '&#8364;': '€',
      '&euro;': '€',

      // Currency symbols - Pound
      'Â£': '£',
      '&#163;': '£',
      '&pound;': '£',

      // Currency symbols - Yen
      'Â¥': '¥',
      '&#165;': '¥',
      '&yen;': '¥',

      // General symbols
      '&amp;': '&',

      // Quotes
      'â€˜': ''',
    'â€™': ''',
      'â€œ': '"',
      'â€': '"',
      '&lsquo;': ''',
    '&rsquo;': ''',
      '&ldquo;': '"',
      '&rdquo;': '"',

      // Dashes
      'â€"': '—',
      'â€"': '–',
      '&mdash;': '—',
      '&ndash;': '–',

      // Other symbols
      'â€¦': '…',
      'â€¢': '•',
      'Â°': '°',
      'Â±': '±',
      'Ã—': '×',
      'Ã·': '÷',
      '¬': '', // Remove "not sign"

      // Percentage and math
      '&percnt;': '%',
      '&plus;': '+',
      '&minus;': '−',

      // Non-breaking space
      'Â ': ' ',
      '&nbsp;': ' ',

      // Common problematic combinations
      '¬?': '',
      '_?': '',

      // Zero-width characters
      '\u200B': '',
      '\u200C': '',
      '\u200D': '',
      '\uFEFF': '',

      // Replacement character
      '\uFFFD': '',
      '�': '',
    };

    String cleaned = htmlData;

    // Apply all replacements
    replacements.forEach((key, value) {
      cleaned = cleaned.replaceAll(key, value);
    });

    // Remove all remaining "Â" characters (single or multiple)
    cleaned = cleaned.replaceAll(RegExp(r'Â+'), '');

    // Remove any remaining problematic characters
    cleaned = cleaned.replaceAll(RegExp(r'[\uFFFD�¬]+'), '');

    // Additional cleanup
    cleaned = cleaned
        .replaceAll(RegExp(r'\.{2,}'), '.')
        .replaceAll(RegExp(r'\?â€¦'), '?.')
        .replaceAll(RegExp(r'\s+\.\s+'), '. ')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("html data ---${currentAntibiotic.antibiotic.data}");
    debugPrint(
        "🔍 Causative Organism in build: ${currentAntibiotic.antibiotic.causativeOrganism}");
    debugPrint(
        "🔍 Is null? ${currentAntibiotic.antibiotic.causativeOrganism == null}");
    debugPrint(
        "🔍 Is empty? ${currentAntibiotic.antibiotic.causativeOrganism?.isEmpty}");

    debugPrint("html data ---${currentAntibiotic.antibiotic.data}");
    String createdAt = widget.condition.antibiotic.auditLog?.modifiedOn != null
        ? DateFormat('dd MMMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(
            (widget.condition.antibiotic.auditLog!.modifiedOn! * 1000).toInt()))
        : widget.condition.antibiotic.auditLog?.createdOn != null
            ? DateFormat('dd MMMM yyyy').format(
                DateTime.fromMillisecondsSinceEpoch(
                    (widget.condition.antibiotic.auditLog!.createdOn * 1000)
                        .toInt()))
            : "Unknown Date";

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            widget.condition.antibiotic.name,
            maxLines: 2,
            softWrap: true,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
          backgroundColor: primaryColor,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (widget.onBookmarkToggle != null) {
                widget.onBookmarkToggle!();
              }
              Navigator.pop(context, {
                'refresh': true,
                'antibioticId': currentAntibiotic.antibiotic.antibioticId,
                'compliance': true,
              });
            },
          ),
          actions: [
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, Routes.home);
                CompliancePopup.show(
                  context,
                  widget.condition.antibiotic.antibioticId,
                  _submitForm,
                  redirectHome: true,
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Image.asset(
                  'assets/images/home_icon.png',
                  height: 24.0,
                  width: 24.0,
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        "Bookmark",
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.black,
                        ),
                      ),
                      _showBookmarkIcon
                          ? IconButton(
                              icon: Icon(
                                isBookmarked ?? false
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: primaryColor,
                              ),
                              onPressed: () {
                                _toggleBookmark();
                              },
                            )
                          : const SizedBox(
                              height: 45,
                            ),
                    ],
                  ),
                  Text(
                    createdAt,
                    style: const TextStyle(
                      fontSize: 12.0,
                      color: gray,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      final shouldExpand = !_anyExpanded;
                      _expanded.updateAll((key, value) => shouldExpand);
                    });
                  },
                  icon: Icon(
                      _anyExpanded ? Icons.unfold_less : Icons.unfold_more),
                  label: Text(_anyExpanded ? 'Collapse All' : 'Expand All'),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
// 1. FIRST: Show causative organism (if exists)
                      if (currentAntibiotic.antibiotic.causativeOrganism !=
                              null &&
                          currentAntibiotic
                              .antibiotic.causativeOrganism!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 6.0, horizontal: 6.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: primaryColor, width: 1),
                            borderRadius: BorderRadius.circular(8.0),
                            color: primaryColor.withOpacity(0.05),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  // Icon(
                                  //   Icons.bug_report,
                                  //   color: primaryColor,
                                  //   size: 20,
                                  // ),
                                  // SizedBox(width: 8),
                                  Text(
                                    "Causative Organism",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentAntibiotic.antibiotic.causativeOrganism!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ..._buildLineSections(
                        _allAntibiotics,
                        widget.condition.antibiotic.antibioticId,
                      ),
                      // const Padding(
                      //   padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                      //   child: Text(
                      //     "Other Instructions",
                      //     style: TextStyle(
                      //       fontSize: 16,
                      //       fontWeight: FontWeight.bold,
                      //       color: Colors.black,
                      //     ),
                      //   ),
                      // ),

                      // Display HTML content with manual image extraction and placement
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildHtmlWithClickableImages(
                          _cleanHtmlData(currentAntibiotic.antibiotic.data),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add this method to your HtmlScreenState class
  List<Widget> _extractAndDisplayImages(String htmlData) {
    final List<Widget> imageWidgets = [];
    final RegExp imgRegExp =
        RegExp(r'<img[^>]*src="([^"]*)"[^>]*>', caseSensitive: false);
    final matches = imgRegExp.allMatches(htmlData);

    for (final match in matches) {
      final src = match.group(1);
      if (src != null && src.isNotEmpty) {
        imageWidgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: GestureDetector(
              onTap: () => _showImageViewer(src),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image(
                    image: _getImageProvider(src),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 100,
                        alignment: Alignment.center,
                        child: const Text('Image not available'),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return imageWidgets;
  }

  Color _getAwareClassificationColor(String? classification) {
    if (classification == null) return Colors.grey;

    switch (classification.toLowerCase()) {
      case 'access':
        return const Color(0xFF7BA5C9);
      case 'watch':
        return const Color(0xFF7BA5C9);
      // return const Color(0xFF9DBFD9);
      case 'reserve':
        // return const Color(0xFFB8D4E8);
        return const Color(0xFF7BA5C9);
      default:
        return Colors.grey.shade300;
    }
  }

  Widget _buildAwareClassificationBadge(String? classification) {
    if (classification == null || classification.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      width: 63,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getAwareClassificationColor(classification).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getAwareClassificationColor(classification),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          classification.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: _getAwareClassificationColor(classification),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLineSections(
      List<AntibioticWithStatus> allAntibiotics, String parentId) {
    final grouped = groupByLine(allAntibiotics, parentId);

    grouped.keys.forEach((k) {
      _expanded.putIfAbsent(k, () => true);
    });

    debugPrint("Parent ID passed to _buildLineSections: $parentId");

    Widget buildSection(
        String title, String key, List<AntibioticWithStatus> items) {
      if (items.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6.0),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent, // This removes the lines
          ),
          child: ExpansionTile(
            key: ValueKey<bool>(_expanded[key] ?? false),
            initiallyExpanded: _expanded[key] ?? false,
            onExpansionChanged: (expanded) {
              setState(() {
                _expanded[key] = expanded;
              });
            },
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.only(left: 16, right: 16),
            title: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            children: items.map((ab) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            ab.antibiotic.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        _buildAwareClassificationBadge(
                          ab.antibiotic.awareClassification,
                        ),
                      ],
                    ),
                    // const SizedBox(height: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._buildHtmlWithClickableImages(
                          _cleanHtmlData(ab.antibiotic.data ?? ''),
                        ),
                      ],
                    ),
                    const Divider(),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    return [
      buildSection("First Line Antibiotics", "line_1", grouped["line_1"]!),
      buildSection("Second Line Antibiotics", "line_2", grouped["line_2"]!),
      buildSection("Third Line Antibiotics", "line_3", grouped["line_3"]!),
    ];
  }
}

// Image Viewer Page with zoom functionality
class ImageViewerPage extends StatelessWidget {
  final String imageUrl;

  const ImageViewerPage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Image Viewer',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: PhotoView(
        imageProvider: _getImageProvider(imageUrl),
        minScale: PhotoViewComputedScale.contained * 0.8,
        maxScale: PhotoViewComputedScale.covered * 2,
        initialScale: PhotoViewComputedScale.contained,
        heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
        backgroundDecoration: const BoxDecoration(
          color: Colors.black,
        ),
        loadingBuilder: (context, event) => Center(
          child: Container(
            width: 20.0,
            height: 20.0,
            child: CircularProgressIndicator(
              value: event == null
                  ? 0
                  : event.cumulativeBytesLoaded /
                      (event.expectedTotalBytes ?? 1),
            ),
          ),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error,
                color: Colors.white,
                size: 60,
              ),
              SizedBox(height: 16),
              Text(
                'Failed to load image',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider _getImageProvider(String imageUrl) {
    // Handle base64 images
    if (imageUrl.startsWith('data:image')) {
      final base64String = imageUrl.split(',')[1];
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    }

    // Handle network images
    if (imageUrl.startsWith('http')) {
      return NetworkImage(imageUrl);
    }

    // Handle asset images
    return AssetImage(imageUrl);
  }
}
