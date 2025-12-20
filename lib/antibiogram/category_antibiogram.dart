import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/antibiogram/antibiogram_api_services.dart';
import 'package:qr_scanner_app/antibiogram/antibiogram_list_screen.dart';
import 'package:qr_scanner_app/antibiogram/database_helper_antibiogram.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/home/home_screen.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';

class CategoryAntibiogram extends StatefulWidget {
  final String title;
  final int sampleTypeId;
  final String subCategory;
  final String categoryId;
  final List categoriesList;

  const CategoryAntibiogram({
    super.key,
    required this.title,
    required this.sampleTypeId,
    required this.subCategory,
    required this.categoryId,
    required this.categoriesList,
  });

  @override
  CategoryAntibiogramState createState() => CategoryAntibiogramState();
}

class CategoryAntibiogramState extends State<CategoryAntibiogram> {
  // final AntibiogramPostService antibiogramService = AntibiogramPostService();
  late String dropdownValue;
  bool showOldSusceptibility = false;
  String? _expandedCategory;
  List<String> antibiogramIds = [];
  List<Map<String, dynamic>> gramPositiveData = [];
  List<Map<String, dynamic>> gramNegativeData = [];
  bool isGramPositiveAPICalled = false;
  bool isGramNegativeAPICalled = false;

  // Local variable to store the current categoryId
  late String selectedCategoryId;
  List<Map<String, dynamic>> offlineAntibiogramViews = [];

  @override
  void initState() {
    super.initState();
    selectedCategoryId = widget.categoryId;
    fetchAntibiogramIds();
    dropdownValue = widget.categoriesList.isNotEmpty
        ? widget.categoriesList.first['category_name']
        : 'Select Category';
  }

  @override
  void dispose() {
    // antibiogramService.dispose();
    super.dispose();
  }

  Future<void> fetchAntibiogramIds() async {
    debugPrint(
        'Selected Category ID: $selectedCategoryId, Sub Category: ${widget.subCategory}');
    final data = await DatabaseHelperAntibiogram()
        .getAntibiogramIdsByCategoryAndSubCategory(
            selectedCategoryId, widget.subCategory);

    List<String> fetchedIds =
        data.map((e) => e['antibiogram_id'].toString()).toList();

    setState(() {
      antibiogramIds = fetchedIds;
    });

    debugPrint('Fetched Antibiogram IDs: $fetchedIds');
    var result = await DatabaseHelperAntibiogram()
        .getAntibiogramsByIdsAndType(antibiogramIds);

    List<Map<String, dynamic>> gramPositiveList = result['gram_positive']!;
    List<Map<String, dynamic>> gramNegativeList = result['gram_negative']!;

    debugPrint('Gram Positive Data: $gramPositiveList');
    debugPrint('Gram Negative Data: $gramNegativeList');
    setState(() {
      gramPositiveData = gramPositiveList;
      gramNegativeData = gramNegativeList;
    });

    await postAntibiogramData();
  }

  Future<void> postAntibiogramData([String? type]) async {
    final requestBody = [
      {
        "category_id": selectedCategoryId,
        "sub_category": widget.subCategory,
        "type": type ?? "gram positive",
        "view": true,
        "chat": false,
        "date": DateTime.now().millisecondsSinceEpoch ~/ 1000
      }
    ];
    debugPrint('Calling postAntibiogram API with body: $requestBody');

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.first == ConnectivityResult.none) {
        debugPrint('No internet connection. Storing data locally.');
        await storeDataLocally(requestBody);
        return;
      }
      debugPrint('Calling postAntibiogram API with body: $requestBody');
      final apiService = AntibiogramApiService(
        apiClient: ApiClient(baseUrl: Strings.baseUrl),
      );
      final response = await apiService.postAntibiogram(requestBody);
      if (response.containsKey('status') && response['status'] == 200) {
        debugPrint('Data posted successfully.');
      } else if (response.containsKey('status') && response['status'] == 401) {
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
      }
      debugPrint('API Response for Post View: $response');
    } catch (e) {
      debugPrint('Error in postAntibiogram API: $e');
    }
  }

  // Function to store data locally
  Future<void> storeDataLocally(List<Map<String, dynamic>> requestBody) async {
    final dbHelper = DatabaseHelperAntibiogram();

    for (var data in requestBody) {
      if (data.containsKey('view') && data.containsKey('date')) {
        await dbHelper.insertAntibiogramView(data);
      } else {
        // Insert into antibiograms if the data doesn't include 'view' or 'date'
        await dbHelper.insertAntibiogram(data);
      }
    }
    debugPrint('Data stored locally.');
    final allData = await dbHelper.getAntibiogramViews();

    // Print the entire table
    debugPrint('Entire antibiogram_views Table:');
    for (var row in allData) {
      debugPrint(row.toString());
    }
  }

  void _showDropdownBottomSheet() {
    // Build the dropdown list dynamically from the widget.categoriesList
    List<String> categoryNames = widget.categoriesList
        .map((e) => e['category_name'].toString())
        .toList();

    const double tileHeight = 56.0;
    const double maxHeightFactor = 0.6;
    final double calculatedHeight =
        (categoryNames.isEmpty ? 1 : categoryNames.length + 1) * tileHeight +
            16;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final double screenHeight = MediaQuery.of(context).size.height;
        final double maxHeight = screenHeight * maxHeightFactor;

        return Container(
          padding: const EdgeInsets.all(16.0),
          height: calculatedHeight > maxHeight ? maxHeight : calculatedHeight,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text(
                    'Select Category',
                    style: TextStyle(
                      color: likeColour,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Close the bottom sheet
                    },
                    child: const Icon(
                      Icons.close,
                      color: likeColour,
                      size: 18,
                    ),
                  ),
                ),
                categoryNames.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No categories available',
                          style: TextStyle(
                              color: lightBlack,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: categoryNames.length,
                        itemBuilder: (context, index) {
                          final option = categoryNames[index];
                          return ListTile(
                            title: Text(
                              option,
                              style: const TextStyle(
                                color: lightBlack,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              color: iconColor,
                              size: 14,
                            ),
                            onTap: () {
                              setState(() {
                                dropdownValue = option;
                              });
                              String selectedCatId =
                                  widget.categoriesList.firstWhere(
                                        (e) => e['category_name'] == option,
                                        orElse: () => {'category_id': ''},
                                      )['category_id'] ??
                                      '';

                              if (selectedCatId.isNotEmpty) {
                                setState(() {
                                  selectedCategoryId = selectedCatId;
                                });
                                debugPrint(
                                    "Updated selected category ID: $selectedCatId");
                                fetchAntibiogramIds();
                              }
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: fontLight,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList(List<Map<String, dynamic>> dataList, String type) {
    // Extract unique y_axis_name values
    final uniqueYAxisNames =
        dataList.map((item) => item['y_axis_name']).toSet().toList();

    return Center(
      child: uniqueYAxisNames.isNotEmpty
          ? ListView.builder(
              itemCount: uniqueYAxisNames.length,
              itemBuilder: (context, index) {
                String yAxisName = uniqueYAxisNames[index];
                bool isExpanded = _expandedCategory == yAxisName;

                // Filter data for the current y_axis_name
                final filteredData = dataList
                    .where((item) => item['y_axis_name'] == yAxisName)
                    .toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 4.0, horizontal: 16.0),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: backgroundColors,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: ListTile(
                          title: Text(
                            yAxisName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                fontSize: 14),
                          ),
                          trailing: ExpandIconButton(
                            isExpanded: isExpanded,
                            onTap: () {
                              setState(() {
                                _expandedCategory =
                                    isExpanded ? null : yAxisName;
                              });
                            },
                          ),
                          onTap: () {
                            setState(() {
                              _expandedCategory = isExpanded ? null : yAxisName;
                            });
                          },
                        ),
                      ),
                      if (isExpanded)
                        Container(
                          margin: const EdgeInsets.only(top: 4.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border:
                                Border.all(color: backgroundColors, width: 1.0),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: AntibiogramListScreen(
                            categoryName: yAxisName,
                            susceptibility: showOldSusceptibility,
                            dataList: filteredData,
                          ),
                        ),
                    ],
                  ),
                );
              },
            )
          : Text(
              'No data available for $type',
              style: const TextStyle(fontSize: 18),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: primaryColor,
          titleSpacing: 10.0,
          title: Text(
            widget.title,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          actions: [
            IconButton(
              icon: Image.asset(
                'assets/images/home_icon.png',
                width: 24.0,
                height: 24.0,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              child: TabBar(
                labelPadding: const EdgeInsets.symmetric(vertical: 10),
                indicatorColor: primaryColor,
                unselectedLabelColor: gray,
                labelColor: primaryColor,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [
                  Tab(text: 'Gram Positive'),
                  Tab(text: 'Gram Negative'),
                ],
                onTap: (index) async {
                  if (index == 0 && !isGramPositiveAPICalled) {
                    setState(() {
                      isGramPositiveAPICalled = true;
                    });
                  } else if (index == 1 && !isGramNegativeAPICalled) {
                    await postAntibiogramData("gram negative");
                    setState(() {
                      isGramNegativeAPICalled = true;
                    });
                  }
                },
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _showDropdownBottomSheet,
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: gray),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                dropdownValue,
                                style: const TextStyle(
                                  color: gray,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            Image.asset(
                              'assets/images/dropdown.png',
                              width: 16,
                              height: 16,
                              color: gray,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 28),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Show previous',
                        style: TextStyle(
                            color: lightBlack,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'susceptibility',
                        style: TextStyle(
                            color: lightBlack,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(width: 1),
                  Switch(
                    value: showOldSusceptibility,
                    onChanged: (value) {
                      setState(() {
                        showOldSusceptibility = value;
                      });
                    },
                    activeColor: Colors.white,
                    activeTrackColor: primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem(greenGraph, 'Empirical Therapy Drugs (ETD)'),
                  const SizedBox(height: 4),
                  _buildLegendItem(
                      yellowGraph, 'ETD for stable patients in OPD settings'),
                  const SizedBox(height: 4),
                  _buildLegendItem(
                      redGraph, 'Drugs unsuitable for empirical therapy'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildCategoryList(gramPositiveData, 'Gram Positive'),
                  _buildCategoryList(gramNegativeData, 'Gram Negative'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A widget that isolates the trailing expansion icon to improve tap responsiveness.
class ExpandIconButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const ExpandIconButton({
    super.key,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primaryColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(
            isExpanded ? Icons.remove : Icons.add,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}
