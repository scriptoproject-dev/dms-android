import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/antibiotic_policy/choose_drugs_popup.dart';
import 'package:qr_scanner_app/antibiotic_policy/compliance_service.dart';
import 'package:qr_scanner_app/antibiotic_policy/reason_popup.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/main.dart';

class SpecifyPopup {
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
    String antibioticId, // single antibiotic id
    List<String> lineItemIds, // multiple ids
    Future<void> Function(List<Map<String, dynamic>>) submitForm, {
    // callback
    bool? redirectHome,
    String? lineType,
    bool? helpful,
    String? reasonId, // <- add this
    String? message,
    bool? complied,
    String? otherDrugs, // 👈 New parameter
    String? otherDrugsReasonId, // 👈 New parameter
    String? otherDrugsMessage,
    String? category,
  }) {
    final TextEditingController controller = TextEditingController();

    debugPrint("SpecifyPopup complied value: $complied");
    debugPrint("SpecifyPopup otherDrugs: $otherDrugs");
    debugPrint("SpecifyPopup otherDrugsReasonId: $otherDrugsReasonId");
    debugPrint("SpecifyPopup otherDrugsMessage: $otherDrugsMessage");
    debugPrint("SpecifyPopup category: $category");

    void handleGoBack() {
      Navigator.pop(context);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (complied == true) {
          // ✅ Compliance Yes → back to ChooseDrugsPopup
          ChooseDrugsPopup.show(
            navigatorKey.currentContext!,
            antibioticId,
            submitForm,
            redirectHome,
            complied!,
          );
        } else {
          // ❌ Compliance No → go to ReasonPopup
          ReasonPopup.show(
            navigatorKey.currentContext!,
            antibioticId,
            lineItemIds,
            submitForm,
            redirectHome: redirectHome,
            category: "compliance_no",
            source: "specify",
            lineType: lineType,
            complied: complied ?? false,
            otherDrugs: otherDrugs,
            otherDrugsReasonId: otherDrugsReasonId,
            otherDrugsMessage: otherDrugsMessage,
          );
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // 👈 prevents closing on outside tap
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return WillPopScope(
          onWillPop: () async {
            handleGoBack(); // 👈 same as button
            return false; // prevent default dismiss
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Please specify",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: fontLight),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Enter your reason",
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: handleGoBack,
                        // onPressed: () {
                        // Navigator.pop(context);
                        // // 🔹 Go back → reopen ChooseDrugsPopup
                        // // ChooseDrugsPopup.show(navigatorKey.currentContext!,
                        // //     antibioticId, submitForm, redirectHome, complied!);
                        // Future.delayed(const Duration(milliseconds: 200), () {
                        //   if (complied == true) {
                        //     // ✅ Compliance Yes → back to ChooseDrugsPopup
                        //     ChooseDrugsPopup.show(
                        //       navigatorKey.currentContext!,
                        //       antibioticId,
                        //       submitForm,
                        //       redirectHome,
                        //       complied!,
                        //     );
                        //   } else {
                        //     // ❌ Compliance No → go to ReasonPopup
                        //     ReasonPopup.show(
                        //       navigatorKey.currentContext!,
                        //       antibioticId,
                        //       lineItemIds,
                        //       submitForm,
                        //       redirectHome: redirectHome,
                        //       category: "compliance_no",
                        //       source: "specify",
                        //       lineType: lineType,
                        //       complied: complied ?? false,
                        //       otherDrugs: otherDrugs,
                        //       otherDrugsReasonId: otherDrugsReasonId,
                        //       otherDrugsMessage: otherDrugsMessage,
                        //     );
                        //   }
                        // });
                        // },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: primaryColor, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                        ),
                        child: const Text(
                          "Go back",
                          style: TextStyle(color: primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (controller.text.trim().isEmpty) {
                            _showToast("Please enter a reason");
                            return;
                          }
                          Navigator.pop(context);

                          // 🔹 Build payload using ComplianceService
                          final payload = ComplianceService.buildPayload(
                            antibioticId: antibioticId,
                            lineItemIds: lineItemIds, // ✅ use list passed in
                            complied: complied, // ❌ user said "No"
                            helpful: helpful,
                            helpfulMessage: controller.text.trim(),
                            lineType: lineType,
                            reasonId: reasonId,
                            message: message,
                            otherDrugs: otherDrugs, // 👈 Include in payload
                            otherDrugsReasonId:
                                otherDrugsReasonId, // 👈 Include in payload
                            otherDrugsMessage: otherDrugsMessage,
                          );

                          // 🔹 Submit (handles online/offline)
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
                          "Submit",
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
