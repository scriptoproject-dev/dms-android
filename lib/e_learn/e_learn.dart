import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/e_learn/e_learn_api_services.dart';
import 'package:qr_scanner_app/e_learn/e_learn_database_helper.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/routes.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ELearnPage extends StatefulWidget {
  const ELearnPage({super.key});

  @override
  ELearnPageState createState() => ELearnPageState();
}

class ELearnPageState extends State<ELearnPage> {
  List<Map<String, Object>> _elearns = [];
  bool _isLoading = true;
  String? _selectedCategory = 'Newest to Oldest';
  bool _isStoragePermissionGranted = false;
  List<String> likedIds = [];
  List<String> dislikedIds = [];

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, Object>> _filteredElearns = [];
  final FocusNode _searchFocusNode = FocusNode();
  final ElearnDatabaseHelper dbHelper = ElearnDatabaseHelper();

  @override
  void initState() {
    super.initState();
    checkStoragePermission();
    _selectedCategory = 'Newest to Oldest';
    fetchDatabaseData();
    _filteredElearns = _elearns;
  }

  Future<void> checkStoragePermission() async {
    final prefs = await SharedPreferences.getInstance();
    bool isPermissionGranted =
        prefs.getBool('isStoragePermissionGranted') ?? false;

    setState(() {
      _isStoragePermissionGranted = isPermissionGranted;
    });

    debugPrint('Storage permission granted: $_isStoragePermissionGranted');
  }

  Future<String> _getThumbnailPath(String thumbnailId) async {
    Directory? directory;

    if (Platform.isAndroid) {
      // Get external storage directory for Android

      directory = await getApplicationCacheDirectory();
    } else if (Platform.isIOS) {
      // Get application documents directory for iOS
      directory = await getApplicationDocumentsDirectory();
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    return '${directory.path}/$thumbnailId.jpg';
  }

  Future<void> fetchDatabaseData() async {
    setState(() {
      _isLoading = true;
    });

    final ElearnDatabaseHelper dbHelper = ElearnDatabaseHelper();
    try {
      final elearnsList = await dbHelper.getAllELearns();
      final updatedElearns = elearnsList.map((item) {
        final modifiedOnEpoch =
            int.tryParse(item['modified_on']?.toString() ?? '0') ?? 0;
        final modifiedOnDate =
            DateTime.fromMillisecondsSinceEpoch(modifiedOnEpoch * 1000);
        final formattedDate =
            '${modifiedOnDate.day.toString().padLeft(2, '0')} '
            '${_monthName(modifiedOnDate.month)} '
            '${modifiedOnDate.year}';
        return {
          'elearn_id': item['elearn_id']?.toString() ?? '',
          'heading': item['heading']?.toString() ?? '',
          'description': item['description']?.toString() ?? '',
          'thumbnail_id': item['thumbnail_id']?.toString() ?? '',
          'completed': item['completed']?.toString() ?? '0',
          'modified_on': formattedDate,
          'modified_on_date': modifiedOnDate,
          'liked': item['liked'] == 1 ? 1 : 0,
          'disliked': item['disliked'] == 1 ? 1 : 0,
          'user_completed': item['user_completed']?.toString() ?? '0',
        };
      }).toList();

      // Apply default sort here (Newest to Oldest)
      updatedElearns.sort((a, b) {
        return (b['modified_on_date'] as DateTime)
            .compareTo(a['modified_on_date'] as DateTime);
      });

      setState(() {
        _elearns = updatedElearns;
        _filteredElearns = updatedElearns;
        _isLoading = false;
        debugPrint('Liked values: ${_elearns.map((e) => e['liked']).toList()}');
        debugPrint(
            'User Completed values: ${_elearns.map((e) => e['user_completed']).toList()}');

        debugPrint(
            'Disliked values: ${_elearns.map((e) => e['disliked']).toList()}');
        debugPrint(
            'Thumbnail values: ${_elearns.map((e) => e['thumbnail_id']).toList()}');
      });
    } catch (e) {
      debugPrint('Error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterElearns(String query) {
    setState(() {
      // Filter the _elearns list based on the query and update _filteredElearns
      _filteredElearns = _elearns.where((elearn) {
        String title = elearn['heading']?.toString() ?? '';
        return title.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void _onSearchClose() {
    setState(() {
      _searchController.clear();
      _filteredElearns = _elearns;
    });
    _searchFocusNode.unfocus();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _searchFocusNode.unfocus();
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(120), // Adjust AppBar height
          child: AppBar(
            backgroundColor: primaryColor,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'E-Learn',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            flexibleSpace: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    bottom: 8.0,
                  ),
                  child: Container(
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
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (value) {
                          _filterElearns(value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle: const TextStyle(color: searchColor),
                          border: InputBorder.none,
                          icon: const Icon(Icons.search, color: searchColor),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: searchColor),
                                  onPressed: _onSearchClose,
                                )
                              : null,
                        ),
                        style:
                            const TextStyle(fontSize: 16, color: Colors.black),
                      )),
                ),
              ],
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : GestureDetector(
                onTap: () {
                  _searchFocusNode
                      .unfocus(); // Unfocus the search when tapping anywhere
                },
                behavior: HitTestBehavior.translucent,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: _showSortOptions,
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.5,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0, vertical: 10.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _selectedCategory ?? '',
                                    style: const TextStyle(
                                        fontSize: 16, color: searchColor),
                                  ),
                                  Image.asset('assets/images/dropdown.png'),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _filteredElearns.isEmpty
                          // child: _elearns.isEmpty
                          ? const Center(child: Text('No e-learns available.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              // itemCount: _elearns.length,
                              itemCount: _filteredElearns.length, // search
                              itemBuilder: (context, index) {
                                var elearn = _filteredElearns[index]; //Search
                                // var elearn = _elearns[index];
                                final liked = elearn['liked'] is int
                                    ? elearn['liked'] as int
                                    : int.tryParse(
                                            elearn['liked'].toString()) ??
                                        0;

                                final disliked = elearn['disliked'] is int
                                    ? elearn['disliked'] as int
                                    : int.tryParse(
                                            elearn['disliked'].toString()) ??
                                        0;

                                final userCompleted =
                                    elearn['user_completed'] is int
                                        ? elearn['user_completed'] as int
                                        : int.tryParse(elearn['user_completed']
                                                .toString()) ??
                                            0;

                                return Column(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: userCompleted == 0
                                            ? backgroundColors // Light rose background
                                            : Colors
                                                .transparent, // Default background
                                        borderRadius: BorderRadius.circular(
                                            10), // Corner radius
                                      ),
                                      padding: const EdgeInsets.all(
                                          8.0), // Padding inside the container
                                      child: _buildVideoTile(
                                        title: elearn['heading']?.toString() ??
                                            'No Title',
                                        description:
                                            elearn['description']?.toString() ??
                                                'No Description',
                                        eLearnId:
                                            elearn['elearn_id']?.toString() ??
                                                'No ID',
                                        thumbnailId: elearn['thumbnail_id']
                                                ?.toString() ??
                                            'No ID',
                                        modifiedOn:
                                            elearn['modified_on']?.toString() ??
                                                'No Date',
                                        liked: liked,
                                        disliked: disliked,
                                        userCompleted: userCompleted,
                                      ),
                                    ),
                                    const SizedBox(
                                        height:
                                            2), // Small spacing before divider
                                    const Divider(
                                        color: Colors.grey, thickness: 1),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildVideoTile({
    required String title,
    required String description,
    required String eLearnId,
    required String thumbnailId,
    required String modifiedOn,
    required int liked,
    required int disliked,
    required int userCompleted,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          Routes.eLearnContent,
          arguments: {
            'title': title,
            'description': description,
            'eLearnId': eLearnId,
            'thumbnailId': thumbnailId,
            'modifiedOn': modifiedOn,
            'liked': liked,
            'disliked': disliked,
          },
        ).then((result) {
          if (result != null && result is Map<String, bool?>) {
            setState(() {
              debugPrint('Back button pressed: ${result['backPressed']}');
              debugPrint('Returned ELearnID: $eLearnId');
              debugPrint('User Completed: $userCompleted');
              if (result['backPressed'] == true && userCompleted == 0) {
                showBottomSheet(eLearnId);
              }
              debugPrint(
                  'Received values: Liked: ${result['liked']}, Disliked: ${result['disliked']}');
              // Safely handle null values by providing default values
              bool likedBool = result['liked'] ?? false;
              bool dislikedBool = result['disliked'] ?? false;
              // Convert the bool values to int
              int likedValue = likedBool ? 1 : 0;
              int dislikedValue = dislikedBool ? 1 : 0;
              // Locate the e-learning item in _elearns
              var elearnIndex =
                  _elearns.indexWhere((e) => e['elearn_id'] == eLearnId);
              if (elearnIndex != -1) {
                // Update the values directly in _elearns
                _elearns[elearnIndex]['liked'] = likedValue;
                _elearns[elearnIndex]['disliked'] = dislikedValue;
                if (likedValue == 1) {
                  if (!likedIds.contains(eLearnId)) {
                    likedIds.add(eLearnId);
                  }
                  dislikedIds.remove(eLearnId);
                } else if (dislikedValue == 1) {
                  if (!dislikedIds.contains(eLearnId)) {
                    dislikedIds.add(eLearnId);
                  }
                  likedIds.remove(eLearnId);
                } else {
                  likedIds.remove(eLearnId);
                  dislikedIds.remove(eLearnId);
                }
              }
            });
          } else {
            debugPrint('Invalid or null result received: $result');
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: FutureBuilder<String>(
                    future: _getThumbnailPath(thumbnailId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator(); // Loader while waiting
                      }

                      final filePath = snapshot.data ?? '';
                      debugPrint('Resolved Thumbnail path: $filePath');
                      return File(filePath).existsSync()
                          ? Image.file(
                              File(filePath),
                              fit: BoxFit.cover,
                            )
                          : Image.asset(
                              'assets/images/dummy.png',
                              fit: BoxFit.cover,
                            );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 0, right: 16),
              child: Row(
                children: [
                  // Row(
                  //   children: [
                  //     GestureDetector(
                  //       onTap: () {
                  //         var elearn = _elearns
                  //             .firstWhere((e) => e['elearn_id'] == eLearnId);
                  //         if (liked == 0) {
                  //           elearn['liked'] = '1';
                  //           elearn['disliked'] = '0';
                  //           if (!likedIds.contains(eLearnId)) {
                  //             likedIds.add(eLearnId);
                  //           }
                  //           dislikedIds.remove(eLearnId);
                  //           _postMetric('like', eLearnId, 1, isAdding: true);
                  //         } else {
                  //           elearn['liked'] = '0';
                  //           likedIds.remove(eLearnId);
                  //           _postMetric('like', eLearnId, 0, isAdding: false);
                  //         }
                  //         ElearnDatabaseHelper dbHelper =
                  //             ElearnDatabaseHelper();
                  //         dbHelper.updateLikeDislikeStatus(
                  //             eLearnId, elearn['liked'] == '1' ? 1 : 0, 0);
                  //         setState(() {}); // Trigger a rebuild
                  //       },
                  //       child: Image.asset(
                  //         liked == 1
                  //             ? 'assets/images/liked.png'
                  //             : 'assets/images/like.png',
                  //         width: 20,
                  //         height: 20,
                  //       ),
                  //     ),
                  //     const SizedBox(width: 4),
                  //     const Text(
                  //       'Like',
                  //       style: TextStyle(
                  //         fontSize: 12,
                  //         fontWeight: FontWeight.w500,
                  //       ),
                  //     ),
                  //     const SizedBox(width: 12),
                  //     GestureDetector(
                  //       onTap: () {
                  //         var elearn = _elearns
                  //             .firstWhere((e) => e['elearn_id'] == eLearnId);
                  //         if (disliked == 0) {
                  //           disliked = 1;
                  //           liked = 0;
                  //           if (!dislikedIds.contains(eLearnId)) {
                  //             dislikedIds.add(eLearnId);
                  //           }
                  //           likedIds.remove(eLearnId);
                  //           elearn['liked'] = '0';
                  //           elearn['disliked'] = '1';
                  //           _postMetric('dislike', eLearnId, 1,
                  //               isAdding: false);
                  //         } else {
                  //           disliked = 0;
                  //           dislikedIds.remove(eLearnId);
                  //           elearn['disliked'] = '0';
                  //           _postMetric('dislike', eLearnId, 0, isAdding: true);
                  //         }
                  //         ElearnDatabaseHelper dbHelper =
                  //             ElearnDatabaseHelper();
                  //         dbHelper.updateLikeDislikeStatus(
                  //             eLearnId, 0, disliked == 1 ? 1 : 0);
                  //         setState(() {});
                  //       },
                  //       child: Transform.rotate(
                  //         angle: 3.14159,
                  //         child: Image.asset(
                  //           disliked == 1
                  //               ? 'assets/images/liked.png'
                  //               : 'assets/images/like.png',
                  //           width: 20,
                  //           height: 20,
                  //         ),
                  //       ),
                  //     ),
                  //     const SizedBox(width: 4),
                  //     const Text(
                  //       'Dislike',
                  //       style: TextStyle(
                  //         fontSize: 12,
                  //         fontWeight: FontWeight.w500,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  const Spacer(),
                  Text(
                    modifiedOn,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  void showBottomSheet(String eLearnId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // <- prevent tapping outside
      enableDrag: false, // <- prevent swipe-down
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16.0),
        ),
      ),
      builder: (BuildContext context) {
        return WillPopScope(
          // Prevent Android back button from closing the sheet
          onWillPop: () async => false,
          child: Container(
            width: MediaQuery.of(context).size.width, // Full width
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Completion Confirmation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: likeColour,
                      ),
                    ),
                    // IconButton(
                    //   icon: const Icon(
                    //     Icons.close,
                    //     color: likeColour,
                    //   ),
                    //   onPressed: () {
                    //     Navigator.pop(context);
                    //   },
                    // ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Did you finish viewing/reading the content?',
                  style: TextStyle(
                    fontSize: 14,
                    color: lightBlack,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: primaryColor, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showToast('Thank you for your response.');
                        },
                        child: const Text(
                          'No',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8), // Spacing between buttons
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          side: const BorderSide(color: primaryColor, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await ElearnDatabaseHelper()
                              .updateUserCompleted(eLearnId, 1);
                          await fetchDatabaseData();
                          // postComplete(eLearnId);

                          showHelpfulSheet(eLearnId);
                        },
                        child: const Text(
                          'Yes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
              ],
            ),
          ),
        );
      },
    );
  }

  void showHelpfulSheet(String eLearnId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // <- prevent tapping outside
      enableDrag: false, // <- prevent swipe-down
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Container(
            width: MediaQuery.of(context).size.width,
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Was this content helpful?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: likeColour,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please let us know if the content helped you.',
                  style: TextStyle(
                    fontSize: 14,
                    color: lightBlack,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    // Not Helpful
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: primaryColor, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await postComplete(eLearnId, helpful: false);
                          _showToast('Thank you for your response.');
                        },
                        child: const Text(
                          'Not Helpful',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Helpful
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          side: const BorderSide(color: primaryColor, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await postComplete(eLearnId, helpful: true);
                          _showToast('Thanks — glad it helped!');
                        },
                        child: const Text(
                          'Helpful',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateModal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sort',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: likeColour,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Icon(Icons.close,
                            color: likeColour, size: 26),
                      ),
                    ],
                  ),
                ),
                // Newest to Oldest option
                ListTile(
                  title: const Text(
                    'Newest to Oldest',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: lightBlack,
                    ),
                  ),
                  trailing: Icon(
                    _selectedCategory == 'Newest to Oldest'
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 22,
                    color: _selectedCategory == 'Newest to Oldest'
                        ? primaryColor
                        : lightBlack,
                  ),
                  onTap: () {
                    setStateModal(() {
                      _selectedCategory = 'Newest to Oldest';
                    });
                    Navigator.pop(context);
                    setState(() {
                      _elearns.sort((a, b) {
                        return (b['modified_on_date'] as DateTime)
                            .compareTo(a['modified_on_date'] as DateTime);
                      });
                    });
                  },
                ),
                ListTile(
                  title: const Text(
                    'Oldest to Newest',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: lightBlack,
                    ),
                  ),
                  trailing: Icon(
                    _selectedCategory == 'Oldest to Newest'
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 22,
                    color: _selectedCategory == 'Oldest to Newest'
                        ? primaryColor
                        : lightBlack,
                  ),
                  onTap: () {
                    setStateModal(() {
                      _selectedCategory = 'Oldest to Newest';
                    });
                    Navigator.pop(context);
                    setState(() {
                      _elearns.sort((a, b) {
                        return (a['modified_on_date'] as DateTime)
                            .compareTo(b['modified_on_date'] as DateTime);
                      });
                    });
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }

  Future<void> postComplete(
    String eLearnId, {
    bool completed = true,
    bool? helpful,
  }) async {
    Map<String, dynamic> metrics = {
      'elearn_id': eLearnId,
      'date': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'completed': completed,
    };

    if (helpful != null) {
      metrics['helpful'] = helpful;
    }

    List<ConnectivityResult> connectivityResult =
        await Connectivity().checkConnectivity();

    if (connectivityResult.first != ConnectivityResult.none) {
      debugPrint("Posting metrics to API: $metrics");
      final apiClient = ApiClient(baseUrl: Strings.baseUrl);
      final eLearnApiService = ELearnApiService(apiClient: apiClient);

      final response = await eLearnApiService.postElearnMetric([metrics]);
      debugPrint("Response for post: $response");

      if (response['status'] == 201) {
        debugPrint("Successfully posted metrics");
      } else if (response['status'] == 401) {
        debugPrint('Received 401. Response body: $response');
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        try {
          await unregisterDeviceFromPushNotificationServer();
          if (mounted) {
            navigateToLoginScreen(context);
          }
        } catch (e) {
          debugPrint('Error while unregistering device: $e');
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to post data');
      }
    } else {
      debugPrint("No network. Storing metrics in database: $metrics");
      await dbHelper.storeOfflineMetric(metrics);
    }
  }
}
