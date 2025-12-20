import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/antibiotic_policy/antibiotic_db_helper.dart';
import 'package:qr_scanner_app/antibiotic_policy/choose_drugs_popup.dart';
import 'package:qr_scanner_app/antibiotic_policy/compliance_popup.dart';
import 'package:qr_scanner_app/antibiotic_policy/helpfull_popup.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/main.dart';
import 'package:qr_scanner_app/models/api_response.dart';
import 'package:qr_scanner_app/models/reasons.dart';
import 'package:qr_scanner_app/utilities/is_network.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prescribing_antibiotics_popup.dart';

class ReasonPopup {
  static Future<void> show(
    BuildContext context,
    String antibioticId,
    List<String>? lineItemIds, // 👈 new param
    Future<void> Function(List<Map<String, dynamic>>) submitForm, {
    bool? redirectHome,
    String? category,
    String? source,
    String? lineType,
    required bool complied,
    String? message,
    String? otherDrugs, // 👈 New parameter
    String? otherDrugsReasonId, // 👈 New parameter
    String? otherDrugsMessage, // 👈 New parameter
  }) async {
    debugPrint("ReasonPopup complied value: $complied");
    debugPrint("ReasonPopup category: $category, source: $source");
    debugPrint("ReasonPopup otherDrugs: $otherDrugs");
    debugPrint("ReasonPopup otherDrugsReasonId: $otherDrugsReasonId");
    debugPrint("ReasonPopup otherDrugsMessage: $otherDrugsMessage");

    List<Reason> reasons = [];
    String? othersReasonId;
    String? prescribingAnotherDrugReasonId;

    bool offline = await isNetworkOffline();
    debugPrint("reason profile network--$offline");
    if (antibioticId.isEmpty) {
      debugPrint("Error: antibioticId is empty");
      return;
    }

    if (submitForm == null) {
      debugPrint("Error: submitForm callback is null");
      return;
    }

    if (!offline) {
      try {
        final result = await fetchReasons(category: category);
        // reasons = result['reasons'];
        reasons = _sortReasonsWithOthersAtEnd(result['reasons']);
        othersReasonId = result['othersReasonId'];

        // Find the reason ID for "Prescribing another drug(s)"
        for (var reason in reasons) {
          if (reason.reason
              .trim()
              .toLowerCase()
              .contains("prescribing another drug")) {
            prescribingAnotherDrugReasonId = reason.reasonId;
            break;
          }
        }

        for (var reason in reasons) {
          await DBHelper.insertReason({
            'reason_id': reason.reasonId,
            'reason': reason.reason,
            'site_id': reason.siteId,
            'status': reason.status,
            'audit_log': jsonEncode(
              reason.auditLog?.toJson(),
            ),
            'category': reason.category,
          });
        }
      } catch (e) {
        debugPrint("Error fetching reasons from API: $e");
        Fluttertoast.showToast(
            msg: "Failed to fetch reasons. Using local data.");
        offline = true;
      }
    } else {
      reasons = await DBHelper.getReasons(category: category);
      reasons = _sortReasonsWithOthersAtEnd(reasons);
      // if (reasons.isEmpty) {
      //   debugPrint(
      //       "No reasons found for category=$category, loading all cached reasons...");
      //   // reasons = await DBHelper.getReasons();
      // }

      if (reasons.isEmpty) {
        debugPrint("⚠️ No reasons found for category=$category in offline DB");
        Fluttertoast.showToast(msg: 'No reasons available to display');
        return;
      }

      final othersReason = reasons.firstWhere(
        (reason) => reason.reason.trim().toLowerCase() == "others",
        orElse: () => Reason(
          reasonId: '',
          reason: 'Others',
          siteId: '',
          status: '',
        ),
      );

      othersReasonId = othersReason.reasonId;

      // Find the reason ID for "Prescribing another drug(s)" in offline mode
      for (var reason in reasons) {
        if (reason.reason
            .trim()
            .toLowerCase()
            .contains("prescribing another drug")) {
          prescribingAnotherDrugReasonId = reason.reasonId;
          break;
        }
      }
    }

    int selectedReason0 = -1;
    String messageText = "";
    bool isSubmitting = false;

    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return WillPopScope(
              onWillPop: () async {
                // 👇 Same logic as "Go back" button
                Navigator.pop(context);

                if (navigatorKey.currentContext != null) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (source == "choose_drugs") {
                      ChooseDrugsPopup.show(
                        navigatorKey.currentContext!,
                        antibioticId,
                        submitForm,
                        redirectHome,
                        complied,
                      );
                    } else if (source == "compliance") {
                      CompliancePopup.show(
                        navigatorKey.currentContext!,
                        antibioticId,
                        submitForm,
                        redirectHome: redirectHome,
                      );
                    } else if (source == "prescribing_abx") {
                      PrescribingAntibioticPopup.show(
                        navigatorKey.currentContext!,
                        antibioticId,
                        submitForm,
                        redirectHome: redirectHome,
                        source: source,
                        reasonId: prescribingAnotherDrugReasonId ?? "",
                        initialMessage: null,
                        otherDrugsMessage: messageText,

                        selectedIds: [], // restore ids here if needed
                      );
                    } else if (source == "reason" &&
                        category == "compliance_no") {
                      // else if (category == "compliance_no") {
                      CompliancePopup.show(
                        navigatorKey.currentContext!,
                        antibioticId,
                        submitForm,
                        redirectHome: redirectHome,
                      );
                    } else if (source == "specify" &&
                        category == "compliance_no") {
                      // else if (category == "compliance_no") {
                      CompliancePopup.show(
                        navigatorKey.currentContext!,
                        antibioticId,
                        submitForm,
                        redirectHome: redirectHome,
                      );
                    }
                  });
                }

                return false; // 👈 Prevent default pop (we handled it)
              },
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
                ),
                child: IntrinsicHeight(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 420, // max height of popup
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                category == "compliance_yes"
                                    ? "Reason for choosing 2nd or 3rd line of antibiotic(s) / antibiotic(s) with antifungal(s)"
                                    : Strings.reasonPopupTitle,
                                style: const TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w600,
                                  color: fontLight,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        Flexible(
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (int i = 0; i < reasons.length; i++)
                                    _buildRadioRow(
                                        modalSetState,
                                        reasons[i].reason,
                                        i,
                                        selectedReason0, (value) {
                                      modalSetState(() {
                                        selectedReason0 = value;
                                      });
                                    }),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        if (selectedReason0 != -1 &&
                            reasons[selectedReason0].reasonId == othersReasonId)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: TextField(
                              onChanged: (text) {
                                modalSetState(() {
                                  messageText = text;
                                });
                              },
                              maxLines: 4,
                              decoration: const InputDecoration(
                                hintText: "Reason",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16.0),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);

                                  // Use the global navigator key to ensure we have a valid context
                                  if (navigatorKey.currentContext != null) {
                                    Future.delayed(
                                        const Duration(milliseconds: 300), () {
                                      if (source == "choose_drugs") {
                                        ChooseDrugsPopup.show(
                                            navigatorKey.currentContext!,
                                            antibioticId,
                                            submitForm,
                                            redirectHome,
                                            complied);
                                      } else if (source == "compliance") {
                                        CompliancePopup.show(
                                          navigatorKey.currentContext!,
                                          antibioticId,
                                          submitForm,
                                          redirectHome: redirectHome,
                                        );
                                      } else if (source == "prescribing_abx") {
                                        PrescribingAntibioticPopup.show(
                                            navigatorKey.currentContext!,
                                            antibioticId,
                                            submitForm,
                                            redirectHome: redirectHome,
                                            source: source,
                                            reasonId:
                                                prescribingAnotherDrugReasonId ??
                                                    "",
                                            // 👇 restore values
                                            initialMessage: null,
                                            selectedIds: [],
                                            otherDrugsMessage:
                                                messageText // pass stored ids here
                                            );
                                      } else if (source == "reason" &&
                                          category == "compliance_no") {
                                        // 👇 Final step back → Compliance popup
                                        CompliancePopup.show(
                                          navigatorKey.currentContext!,
                                          antibioticId,
                                          submitForm,
                                          redirectHome: redirectHome,
                                        );
                                      } else if (source == "specify" &&
                                          category == "compliance_no") {
                                        // else if (category == "compliance_no") {
                                        CompliancePopup.show(
                                          navigatorKey.currentContext!,
                                          antibioticId,
                                          submitForm,
                                          redirectHome: redirectHome,
                                        );
                                      }
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: primaryColor,
                                  side: const BorderSide(
                                      color: primaryColor, width: 2),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12.0),
                                ),
                                child: const Text(
                                  "Go back",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        if (selectedReason0 == -1) {
                                          _showToast("Please select a reason.");
                                          return;
                                        }

                                        // Check if the selected reason is "Prescribing another drug(s)"
                                        if (prescribingAnotherDrugReasonId !=
                                                null &&
                                            reasons[selectedReason0].reasonId ==
                                                prescribingAnotherDrugReasonId) {
                                          Navigator.pop(context);
                                          // Show the PrescribingAntibioticPopup
                                          PrescribingAntibioticPopup.show(
                                            context,
                                            antibioticId,
                                            submitForm,
                                            redirectHome: redirectHome,
                                            source: source,
                                            reasonId:
                                                prescribingAnotherDrugReasonId!,
                                            // reasonId: "",
                                            otherDrugsReasonId:
                                                prescribingAnotherDrugReasonId!,
                                            complied: complied,
                                          );
                                          return;
                                        }

                                        if (reasons[selectedReason0].reasonId ==
                                                othersReasonId &&
                                            messageText.trim().isEmpty) {
                                          _showToast(
                                              "Please specify the reason.");
                                          return;
                                        }

                                        final selectedReason =
                                            reasons[selectedReason0];

                                        // ✅ NEW LOGIC: Determine correct reasonId and otherDrugsReasonId
                                        String? finalReasonId;
                                        String? finalOtherDrugsReasonId;
                                        String? finalMessage;
                                        String? finalOtherDrugsMessage;

                                        if (source == "prescribing_abx") {
                                          // Coming from PrescribingAntibioticPopup
                                          // The CURRENT selection is for "other drugs reason"
                                          finalReasonId = otherDrugsReasonId ??
                                              prescribingAnotherDrugReasonId; // Keep original "Prescribing another drug" ID
                                          // finalReasonId = selectedReason
                                          //     .reasonId; // or keep existing reasonId if needed
                                          finalOtherDrugsReasonId =
                                              selectedReason.reasonId;
                                          finalMessage = null;
                                          finalOtherDrugsMessage =
                                              selectedReason.reasonId ==
                                                      othersReasonId
                                                  ? messageText
                                                  : null;
                                        } else {
                                          // Normal flow (compliance_no, etc.)
                                          finalReasonId =
                                              selectedReason.reasonId;
                                          finalOtherDrugsReasonId =
                                              otherDrugsReasonId; // pass through existing
                                          // finalMessage =
                                          //     selectedReason.reasonId ==
                                          //             othersReasonId
                                          //         ? messageText
                                          //         : null;
                                          // finalOtherDrugsMessage =
                                          //     otherDrugsMessage; // pass through existing
                                        }

                                        // ✅ Call HelpfulPopup BEFORE submission
                                        if (navigatorKey.currentContext !=
                                            null) {
                                          Navigator.pop(
                                              context); // ✅ Close ReasonPopup first
                                          Future.delayed(
                                              const Duration(milliseconds: 300),
                                              () {
                                            HelpfulPopup.show(
                                              navigatorKey.currentContext!,
                                              antibioticId,
                                              lineItemIds ?? [],
                                              submitForm, // pass the submit API function
                                              redirectHome: redirectHome,
                                              reasonId: finalReasonId,
                                              // reasonId: selectedReason.reasonId,
                                              // message: finalMessage,
                                              message: source ==
                                                      "prescribing_abx"
                                                  ? null
                                                  : (selectedReason.reasonId ==
                                                          othersReasonId
                                                      ? messageText
                                                      : null),

                                              lineType: lineType,
                                              complied: complied,
                                              otherDrugs:
                                                  otherDrugs, // 👈 Pass the value
                                              otherDrugsReasonId:
                                                  finalOtherDrugsReasonId,
                                              // otherDrugsReasonId:
                                              //     otherDrugsReasonId, // 👈 Pass the reason ID

                                              otherDrugsMessage:
                                                  source == "prescribing_abx"
                                                      ? messageText
                                                      : null,

                                              source: source, // 👈 ADD THIS
                                              category: category,
                                            );
                                          });
                                        }

                                        // final selectedReason =
                                        //     reasons[selectedReason0];
                                        // final requestBody = {
                                        //   "antibiotic_id": antibioticId,
                                        //   "line_item_ids": lineItemIds,
                                        //   "complied": false,
                                        //   "reason_id": selectedReason.reasonId,
                                        //   if (selectedReason.reasonId ==
                                        //       othersReasonId)
                                        //     "message": messageText,
                                        //   "date": getCurrentEpochTime()
                                        // };

                                        // modalSetState(() {
                                        //   isSubmitting = true;
                                        // });

                                        // try {
                                        //   bool offline = await isNetworkOffline();
                                        //   if (!offline) {
                                        //     await submitForm([requestBody]);
                                        //     Navigator.pop(context);
                                        //     _showToast(
                                        //         "Thank you for your response.");
                                        //     if (redirectHome ?? false) {
                                        //       Navigator.pushNamed(
                                        //           context, Routes.home);
                                        //     }
                                        //   } else {
                                        //     final complianceData = {
                                        //       "antibiotic_id": antibioticId,
                                        //       "complied": false,
                                        //       "reason_id": selectedReason.reasonId,
                                        //       "message": selectedReason.reasonId ==
                                        //               othersReasonId
                                        //           ? messageText
                                        //           : null,
                                        //       "date": getCurrentEpochTime(),
                                        //       "connection": "offline",
                                        //       "compile_status": "no"
                                        //     };

                                        //     if (selectedReason.reasonId ==
                                        //             othersReasonId &&
                                        //         messageText.trim().isEmpty) {
                                        //       _showToast(
                                        //           "Please specify the reason.");
                                        //       return;
                                        //     }

                                        //     try {
                                        //       await DBHelper.insertCompliance(
                                        //           complianceData);
                                        //       Navigator.pop(context);
                                        //       _showToast(
                                        //           "Thank you for your response.");
                                        //       if (redirectHome ?? false) {
                                        //         Navigator.pushNamed(
                                        //             context, Routes.home);
                                        //       }
                                        //     } catch (e) {
                                        //       debugPrint(
                                        //           'Error inserting compliance record: $e');
                                        //       _showToast(
                                        //           "An error occurred while saving offline data. Please try again.");
                                        //     }
                                        //   }
                                        // } catch (e) {
                                        //   debugPrint(
                                        //       'Error during form submission: $e');
                                        //   _showToast(
                                        //       "An error occurred. Please try again.");
                                        // } finally {
                                        //   modalSetState(() {
                                        //     isSubmitting = false;
                                        //   });
                                        // }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12.0),
                                ),
                                child: isSubmitting
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text(
                                        Strings.submitButtonLabel,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static List<Reason> _sortReasonsWithOthersAtEnd(List<Reason> reasons) {
    final otherReasons = <Reason>[];
    final regularReasons = <Reason>[];

    for (var reason in reasons) {
      if (reason.reason.trim().toLowerCase() == "others") {
        otherReasons.add(reason);
      } else {
        regularReasons.add(reason);
      }
    }

    return [...regularReasons, ...otherReasons];
  }

  static Widget _buildRadioRow(StateSetter modalSetState, String text,
      int value, int groupValue, Function(int) onChanged) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0.0),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal, // 👈 Horizontal scroll
                physics: const BouncingScrollPhysics(),
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 14.0),
                  maxLines: 1, // Keep it single line
                ),
              ),
            ),
            const SizedBox(width: 8), // 👈 Add spacing between text and radio
            Radio<int>(
              value: value,
              groupValue: groupValue,
              onChanged: (int? newValue) {
                onChanged(newValue ?? -1);
              },
              activeColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  // static Widget _buildRadioRow(StateSetter modalSetState, String text,
  //     int value, int groupValue, Function(int) onChanged) {
  //   return InkWell(
  //     onTap: () => onChanged(value),
  //     child: Padding(
  //       padding: const EdgeInsets.symmetric(
  //           vertical: 6.0), // 👈 Add some vertical padding
  //       child: Row(
  //         crossAxisAlignment: CrossAxisAlignment.start, // 👈 Align to top
  //         children: [
  //           Expanded(
  //             child: Padding(
  //               padding: const EdgeInsets.only(
  //                   top: 10.0), // 👈 Align text with radio center
  //               child: Text(
  //                 text,
  //                 style: const TextStyle(fontSize: 14.0),
  //                 // No maxLines - shows all text
  //               ),
  //             ),
  //           ),
  //           Radio<int>(
  //             value: value,
  //             groupValue: groupValue,
  //             onChanged: (int? newValue) {
  //               onChanged(newValue ?? -1);
  //             },
  //             activeColor: primaryColor,
  //             materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  //             visualDensity: VisualDensity.compact,
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // static Widget _buildRadioRow(StateSetter modalSetState, String text,
  //     int value, int groupValue, Function(int) onChanged) {
  //   return Row(
  //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //     children: [
  //       Expanded(
  //         child: Text(
  //           text,
  //           style: const TextStyle(fontSize: 14.0),
  //           overflow: TextOverflow.ellipsis,
  //         ),
  //       ),
  //       Radio<int>(
  //         value: value,
  //         groupValue: groupValue,
  //         onChanged: (int? newValue) {
  //           onChanged(newValue ?? -1);
  //         },
  //         activeColor: primaryColor,
  //       ),
  //     ],
  //   );
  // }

  static Future<Map<String, dynamic>> fetchReasons({
    String? category,
    BuildContext? context,
  }) async {
    final baseUrl = Strings.baseUrl;
    final prefs = await SharedPreferences.getInstance();
    String siteId = prefs.getString('site_id') ?? '';

    try {
      final response = await ApiClient(baseUrl: baseUrl).get(
          'reasons?site_id=$siteId&page=1&sort_order=asc&limit=10000&category=$category');

      debugPrint('API Response reasons: ${response.body}');
      if (response.statusCode == 200) {
        // final apiResponse = ApiResponse<List<Reason>>.fromJson(
        //   json.decode(response.body),
        final apiResponse = ApiResponse<List<Reason>>.fromJson(
          json.decode(utf8.decode(response.bodyBytes)),
          (data) =>
              (data as List).map((item) => Reason.fromJson(item)).toList(),
        );

        final sortedReasons = _sortReasonsWithOthersAtEnd(apiResponse.data);

        // final othersReason = apiResponse.data.isNotEmpty
        final othersReason = sortedReasons.isNotEmpty
            ? apiResponse.data.firstWhere(
                (reason) => reason.reason.trim().toLowerCase() == "others",
                orElse: () => Reason(
                  reasonId: '',
                  reason: 'Others',
                  siteId: '',
                  status: '',
                ),
              )
            : null;

        String? othersReasonId = othersReason?.reasonId;

        // Find the reason ID for "Prescribing another drug(s)"
        String? prescribingAnotherDrugReasonId;
        // for (var reason in apiResponse.data) {
        for (var reason in sortedReasons) {
          if (reason.reason
              .trim()
              .toLowerCase()
              .contains("prescribing another drug")) {
            prescribingAnotherDrugReasonId = reason.reasonId;
            break;
          }
        }

        return {
          // 'reasons': apiResponse.data,
          'reasons': sortedReasons,
          'othersReasonId': othersReasonId,
          'prescribingAnotherDrugReasonId': prescribingAnotherDrugReasonId,
        };
      } else if (response.statusCode == 401) {
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (context != null && context.mounted) {
          navigateToLoginScreen(context);
        }
        throw Exception('Unauthorized - redirecting to login');
      } else {
        throw Exception('Failed to fetch reasons');
      }
    } catch (error) {
      debugPrint('Error fetching reason from API: $error');
      // _showToast("An error occurred while fetching reason data.");
      throw Exception('Failed to fetch reasons: $error');
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
