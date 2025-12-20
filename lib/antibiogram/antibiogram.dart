import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/antibiogram/database_helper_antibiogram.dart';
import 'package:qr_scanner_app/antibiogram/pdf_Viewer.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AntibiogramScreen extends StatefulWidget {
  const AntibiogramScreen({super.key});

  @override
  AntibiogramScreenState createState() => AntibiogramScreenState();
}

class AntibiogramScreenState extends State<AntibiogramScreen> {
  // final AntibiogramPostService antibiogramService = AntibiogramPostService();
  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;

  // Hardcoded list of antibiogram items
  final List<String> antibiogramData = [
    'Urine',
    'Pus/Wound Swab/Aspirate',
    'Blood',
    'BAL, Tracheal Aspirate & Endotracheal Secretions',
    'All Clinical Samples',
    'Growth Culture Data',
  ];

  // Hardcoded sample type IDs
  final List<int> sampleTypeIds = [
    1,
    2,
    3,
    4,
    5,
    6,
  ];

  // Subcategory list corresponding to each item
  final List<String> subCategories = [
    'urine',
    'pus',
    'blood',
    'bal',
    'all',
    'growth',
  ];

  @override
  void initState() {
    super.initState();
    fetchCategories();
    // antibiogramService.init(context, () {
    //   debugPrint("Data uploaded callback received in screen.");
    // });
  }

  @override
  void dispose() {
    // antibiogramService.dispose();
    super.dispose();
  }

  Future<void> fetchCategories() async {
    try {
      final data = await DatabaseHelperAntibiogram().getCategories();
      setState(() {
        categories = data;
        isLoading = false;
      });
      debugPrint('Categories: $categories');
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 10.0,
        title: const Text(
          'Antibiogram',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 8.0),
                Expanded(
                  child: ListView.builder(
                    itemCount: antibiogramData.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Container(
                            color: backgroundColors,
                            child: ListTile(
                              title: Text(
                                antibiogramData[index],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                                textAlign: TextAlign.left,
                              ),
                              onTap: () {
                                if (antibiogramData[index] ==
                                    'Growth Culture Data') {
                                  navigateToPDFViewer();
                                } else {
                                  navigateToCategoryAntibiogram(index);
                                }
                              },
                            ),
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

  Future<void> navigateToPDFViewer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedFilePath = prefs.getString('antibiogram_file_path');

      debugPrint('Saved File Path: $savedFilePath');

      if (!mounted) return;
      if (savedFilePath == null || savedFilePath.isEmpty) {
        // Show toast message
        Fluttertoast.showToast(
          msg: 'File not found',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.white,
          textColor: Colors.black,
          fontSize: 16.0,
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFViewerScreen(pdfFilePath: savedFilePath),
        ),
      );
    } catch (e) {
      if (mounted) {
        // Show toast message for errors
        Fluttertoast.showToast(
          msg: 'An error occurred: $e',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.white,
          textColor: Colors.black,
          fontSize: 16.0,
        );
      }
    }
  }

  void navigateToCategoryAntibiogram(int index) {
    final categoryId = categories.isNotEmpty ? categories[0]['category_id'] : 0;

    Navigator.pushNamed(
      context,
      Routes.categoryAntibiogram,
      arguments: {
        'title': '${antibiogramData[index]} Antibiogram',
        'sampleTypeId': sampleTypeIds[index],
        'subCategory': subCategories[index],
        'categoryId': categoryId,
        'categoriesList': categories,
      },
    );
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
