// import 'package:amsp_flutter/antibiotic_policy/choose_drugs_popup.dart';
// import 'package:amsp_flutter/antibiotic_policy/compliance_popup.dart';
// import 'package:amsp_flutter/antibiotic_policy/reason_popup.dart';
// import 'package:flutter/material.dart';

// class PopupManager {
//   static void showCompliancePopup(BuildContext context) {
//     Navigator.pop(context); // Close any open popup
//     Future.delayed(const Duration(milliseconds: 100), () {
//       CompliancePopup.show(context, "some_antibiotic_id", (data) {});
//     });
//   }

//   static void showChooseDrugsPopup(BuildContext context) {
//     Navigator.pop(context); // Close any open popup
//     Future.delayed(const Duration(milliseconds: 100), () {
//       ChooseDrugsPopup.show(context);
//     });
//   }

//   static void showReasonPopup(BuildContext context, String antibioticId,
//       {String category = "compliance_yes", String source = "choose_drugs"}) {
//     Navigator.pop(context); // Close any open popup
//     Future.delayed(const Duration(milliseconds: 100), () {
//       ReasonPopup.show(
//         context,
//         antibioticId,
//         (data) async {
//           debugPrint("Submitted data: $data");
//         },
//         category: category,
//         source: source,
//       );
//     });
//   }
// }
