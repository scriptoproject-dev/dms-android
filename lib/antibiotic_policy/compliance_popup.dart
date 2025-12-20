import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/antibiotic_policy/choose_drugs_popup.dart';
import 'package:qr_scanner_app/antibiotic_policy/reason_popup.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/main.dart';

class CompliancePopup {
  static int getCurrentEpochTime() {
    final now = DateTime.now();
    return now.millisecondsSinceEpoch ~/ 1000;
  }

  static void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  static void show(
    BuildContext context,
    String antibioticId,
    Future<void> Function(List<Map<String, dynamic>>) submitForm, {
    bool? redirectHome,
  }) {
    // Safety check for mounted context
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false, // 👈 Prevent swipe-down to close
      builder: (bottomSheetContext) {
        return WillPopScope(
          onWillPop: () async {
            // 👇 Return false to prevent back button from closing
            return false;
          },
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Strings.compliancePopupTitle,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w500,
                        color: fontLight,
                      ),
                    ),
                    // IconButton(
                    //   icon: const Icon(Icons.close, color: fontLight),
                    //   onPressed: () {
                    //     Navigator.of(bottomSheetContext).pop();
                    //   },
                    // ),
                  ],
                ),
                const SizedBox(height: 16.0),
                const Text(
                  Strings.compliancePopupMessage,
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                    color: lightBlack,
                  ),
                ),
                const SizedBox(height: 24.0),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(bottomSheetContext).pop();

                          // Use the global navigator key to ensure we have a valid context
                          if (navigatorKey.currentContext != null) {
                            Future.delayed(const Duration(milliseconds: 300),
                                () {
                              if (redirectHome ?? false) {
                                ReasonPopup.show(
                                  navigatorKey.currentContext!,
                                  antibioticId,
                                  [],
                                  submitForm,
                                  redirectHome: redirectHome,
                                  category: "compliance_no",
                                  source: "compliance",
                                  complied: false,
                                );
                              } else {
                                ReasonPopup.show(
                                  navigatorKey.currentContext!,
                                  antibioticId,
                                  [],
                                  submitForm,
                                  category: "compliance_no",
                                  source: "compliance",
                                  complied: false,
                                );
                              }
                            });
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: primaryColor, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        child: const Text(
                          "No",
                          style: TextStyle(
                              color: primaryColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(bottomSheetContext).pop();

                          // Use the global navigator key to ensure we have a valid context
                          if (navigatorKey.currentContext != null) {
                            Future.delayed(const Duration(milliseconds: 200),
                                () {
                              ChooseDrugsPopup.show(
                                  navigatorKey.currentContext!,
                                  antibioticId,
                                  submitForm,
                                  redirectHome,
                                  true);
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          side: const BorderSide(color: primaryColor, width: 2),
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        child: const Text(
                          "Yes",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
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
}
