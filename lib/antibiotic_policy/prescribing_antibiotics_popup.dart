import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/antibiotic_policy/reason_popup.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/main.dart';

class PrescribingAntibioticPopup {
  static void show(
    BuildContext context,
    String antibioticId,
    Future<void> Function(List<Map<String, dynamic>>) submitForm, {
    bool? redirectHome,
    String? source,
    required String reasonId,
    List<String>? selectedIds,
    String? initialMessage,
    bool? complied,
    String? otherDrugs,
    String? otherDrugsReasonId,
    String? otherDrugsMessage,
  }) {
    TextEditingController messageController =
        TextEditingController(text: initialMessage ?? "");
    bool isSubmitting = false;
    List<String> chosenIds = selectedIds ?? [];
    String otherDrugsValue = otherDrugs ?? "";

    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext modalContext) {
        return WillPopScope(
          onWillPop: () async {
            _handleGoBack(
                modalContext, context, antibioticId, submitForm, redirectHome);
            return false;
          },
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter modalSetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
                ),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 420,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Please Specify the prescribed antibiotics(s) / antibiotics(s) with anti-fungal(s)",
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w600,
                            color: fontLight,
                          ),
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: 16.0),
                        TextField(
                          controller: messageController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: "Mention",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _handleGoBack(modalContext, context,
                                      antibioticId, submitForm, redirectHome);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: primaryColor,
                                  side: const BorderSide(
                                      color: primaryColor, width: 2),
                                ),
                                child: const Text("Go back"),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () {
                                        if (messageController.text
                                                .trim()
                                                .isEmpty &&
                                            chosenIds.isEmpty) {
                                          _showToast("Please specify");
                                          return;
                                        }

                                        _handleSubmit(
                                          modalContext,
                                          context,
                                          antibioticId,
                                          submitForm,
                                          redirectHome,
                                          reasonId,
                                          messageController.text.trim(),
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                ),
                                child: const Text(
                                  "Submit",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  static void _handleGoBack(
    BuildContext modalContext,
    BuildContext originalContext,
    String antibioticId,
    Future<void> Function(List<Map<String, dynamic>>) submitForm,
    bool? redirectHome,
  ) {
    try {
      // Close the current modal first
      if (modalContext.mounted) {
        Navigator.of(modalContext).pop();
      }

      // Schedule the next popup to open after current one closes
      Future.delayed(const Duration(milliseconds: 200), () {
        BuildContext? targetContext;

        // Try to get a valid context
        if (navigatorKey.currentContext != null &&
            navigatorKey.currentContext!.mounted) {
          targetContext = navigatorKey.currentContext;
        } else if (originalContext.mounted) {
          targetContext = originalContext;
        }

        if (targetContext != null) {
          ReasonPopup.show(
            targetContext,
            antibioticId,
            [],
            submitForm,
            redirectHome: redirectHome,
            category: "compliance_no",
            source: "reason",
            complied: false,
          );
        }
      });
    } catch (e) {
      print('Error in _handleGoBack: $e');
      // Fallback: just close the modal
      if (modalContext.mounted) {
        Navigator.of(modalContext).pop();
      }
    }
  }

  static void _handleSubmit(
    BuildContext modalContext,
    BuildContext originalContext,
    String antibioticId,
    Future<void> Function(List<Map<String, dynamic>>) submitForm,
    bool? redirectHome,
    String reasonId,
    String message,
  ) {
    try {
      // Close the current modal
      if (modalContext.mounted) {
        Navigator.of(modalContext).pop();
      }

      // Schedule the next popup to open
      Future.delayed(const Duration(milliseconds: 200), () {
        BuildContext? targetContext;

        // Try to get a valid context
        if (navigatorKey.currentContext != null &&
            navigatorKey.currentContext!.mounted) {
          targetContext = navigatorKey.currentContext;
        } else if (originalContext.mounted) {
          targetContext = originalContext;
        }

        if (targetContext != null) {
          ReasonPopup.show(
            targetContext,
            antibioticId,
            [],
            submitForm,
            redirectHome: redirectHome,
            category: "other_drugs",
            source: "prescribing_abx",
            complied: false,
            message: null,
            otherDrugs: message,
            otherDrugsReasonId: reasonId,
            otherDrugsMessage: null,
            // otherDrugsMessage: message,
          );
        }
      });
    } catch (e) {
      print('Error in _handleSubmit: $e');
      // Fallback: just close the modal
      if (modalContext.mounted) {
        Navigator.of(modalContext).pop();
      }
    }
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

  static int getCurrentEpochTime() {
    final now = DateTime.now();
    return now.millisecondsSinceEpoch ~/ 1000;
  }
}
