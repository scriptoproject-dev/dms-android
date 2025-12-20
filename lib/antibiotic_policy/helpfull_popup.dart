import 'package:flutter/material.dart';
import 'package:qr_scanner_app/antibiotic_policy/compliance_popup.dart';
import 'package:qr_scanner_app/antibiotic_policy/compliance_service.dart';
import 'package:qr_scanner_app/antibiotic_policy/specify_popup.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/main.dart';

class HelpfulPopup {
  static void show(
    BuildContext context,
    String antibioticId, // ✅ single string
    List<String> lineItemIds, // ✅ list of strings
    Future<void> Function(List<Map<String, dynamic>>) submitForm, {
    bool? redirectHome,
    String? lineType,
    String? reasonId,
    bool? complied, // optional
    String? message,
    String? otherDrugs, // 👈 New parameter
    String? otherDrugsReasonId, // 👈 New parameter
    String? otherDrugsMessage,
    String? source, // 👈 NEW param
    String? category,
  }) {
    debugPrint("HelpfulPopup complied value: $complied");
    debugPrint("HelpfulPopup lineType: $lineType");
    debugPrint("HelpfulPopup otherDrugs: $otherDrugs");
    debugPrint("HelpfulPopup otherDrugsReasonId: $otherDrugsReasonId");
    debugPrint("HelpfulPopup otherDrugsMessage: $otherDrugsMessage");

    debugPrint("HelpfulPopup source: $source, category: $category");

    showModalBottomSheet(
      context: context,
      isDismissible: false, // 👈 prevents closing on outside tap
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return WillPopScope(
          onWillPop: () async {
            Navigator.pop(context);

            Future.delayed(const Duration(milliseconds: 200), () {
              CompliancePopup.show(
                navigatorKey.currentContext!,
                antibioticId,
                submitForm,
                redirectHome: redirectHome,
              );
            });

            return false; // prevent default back close
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 👇 Title + Close button
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Feedback",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: fontLight,
                      ),
                    ),
                    // IconButton(
                    //   icon: const Icon(Icons.close, color: Colors.black),
                    //   onPressed: () {
                    //     Navigator.pop(context);

                    //     Future.delayed(const Duration(milliseconds: 200), () {
                    //       // CompliancePopup.show(
                    //       //   navigatorKey.currentContext!,
                    //       //   antibioticId,
                    //       //   submitForm,
                    //       //   redirectHome: redirectHome,
                    //       // );
                    //       Navigator.pushNamedAndRemoveUntil(
                    //         navigatorKey.currentContext!,
                    //         Routes
                    //             .home, // or '/' depending on your route configuration
                    //         (route) => false,
                    //       );
                    //     });
                    //   },
                    // ),
                  ],
                ),
                const SizedBox(height: 12),

                const Text(
                  "Was this content helpful?",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: lightBlack,
                  ),
                ),
                const SizedBox(height: 20),

                // 👇 Buttons Row
                Row(
                  children: [
                    // ❌ No button → opens SpecifyPopup
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          SpecifyPopup.show(
                            navigatorKey.currentContext!,
                            antibioticId, // String
                            lineItemIds, // List<String>
                            submitForm,
                            redirectHome: redirectHome,
                            lineType: lineType,
                            reasonId: reasonId, // optional
                            message: message,
                            helpful: false,
                            complied: complied,
                            otherDrugs: otherDrugs, // 👈 Pass to SpecifyPopup
                            otherDrugsReasonId:
                                otherDrugsReasonId, // 👈 Pass to SpecifyPopup
                            otherDrugsMessage: otherDrugsMessage,
                            category: category,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: primaryColor, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: const Text(
                          "No",
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ✅ Yes button → send payload
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          debugPrint("🎯".padRight(50, "🎯"));
                          debugPrint("🎯 HelpfulPopup YES button clicked");
                          debugPrint("🎯 antibioticId: $antibioticId");
                          debugPrint("🎯 lineItemIds: $lineItemIds");
                          debugPrint("🎯 lineType: $lineType");
                          debugPrint("🎯 reasonId: $reasonId");
                          debugPrint("🎯 message: $message");
                          debugPrint("🎯 complied: $complied");
                          debugPrint("🎯 otherDrugs: $otherDrugs");
                          debugPrint(
                              "🎯 otherDrugsReasonId: $otherDrugsReasonId");
                          debugPrint(
                              "🎯 otherDrugsMessage: $otherDrugsMessage");
                          debugPrint("🎯".padRight(50, "🎯"));

                          Navigator.pop(context);

                          final payload = ComplianceService.buildPayload(
                            antibioticId: antibioticId, // ✅ FIX
                            lineItemIds: lineItemIds, // ✅ FIX
                            complied: complied,
                            helpful: true,
                            lineType: lineType,
                            reasonId: reasonId, // optional
                            message: message,
                            otherDrugs: otherDrugs, // 👈 Include in payload
                            otherDrugsReasonId:
                                otherDrugsReasonId, // 👈 Include in payload
                            otherDrugsMessage: otherDrugsMessage,
                            category: category,
                          );

                          debugPrint(
                              "🚀 About to submit from HelpfulPopup with reasonId: $reasonId");
                          debugPrint("🚀 Full payload: $payload");

                          await ComplianceService.submitCompliance(
                            payload,
                            submitForm,
                            redirectHome: redirectHome,
                            context: context,
                          );

                          if (!(redirectHome ?? false)) {
                            // ThankYouPopup.show(navigatorKey.currentContext!);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: const Text(
                          "Yes",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
