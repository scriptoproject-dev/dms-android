import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/antibiotic_policy/antibiotic_db_helper.dart';
import 'package:qr_scanner_app/antibiotic_policy/compliance_popup.dart';
import 'package:qr_scanner_app/antibiotic_policy/helpfull_popup.dart';
import 'package:qr_scanner_app/antibiotic_policy/reason_popup.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/main.dart';
import 'package:qr_scanner_app/models/antibiotic_with_status.dart';

class ChooseDrugsPopup {
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

  static List<AntibioticWithStatus> _sortByIndex(
      List<AntibioticWithStatus> list) {
    return list
      ..sort((a, b) {
        final indexA = a.antibiotic.index ?? 999999;
        final indexB = b.antibiotic.index ?? 999999;
        return indexA.compareTo(indexB);
      });
  }

  static void show(
    BuildContext screenContext,
    String? antibioticId,
    Future<void> Function(List<Map<String, dynamic>>) submitForm,
    bool? redirectHome,
    bool complied,
  ) {
    // Safety check for mounted context
    if (!screenContext.mounted) return;
    debugPrint("SpecifyPopup complied value: $complied");
    showModalBottomSheet(
      context: screenContext,
      isScrollControlled: true,
      isDismissible: false, // 👈 prevents closing on outside tap
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final screenHeight = MediaQuery.of(screenContext).size.height;

        return WillPopScope(
          onWillPop: () async {
            Navigator.pop(screenContext);
            if (navigatorKey.currentContext != null) {
              Future.delayed(const Duration(milliseconds: 300), () {
                CompliancePopup.show(
                    navigatorKey.currentContext!, antibioticId!, submitForm);
                return false;
              });
            }
            return false;
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight * 0.75,
            ),
            child: FutureBuilder<List<AntibioticWithStatus>>(
              future: DBHelper.getAntibiotics(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final antibiotics = snapshot.data!;

                debugPrint("🔍 Filtering for antibioticId: $antibioticId");

                for (var abx in antibiotics) {
                  debugPrint(
                      "💊 DB Antibiotic: id=${abx.antibiotic.antibioticId}, "
                      "name=${abx.antibiotic.name}, type=${abx.antibiotic.type}, "
                      "children=${abx.antibiotic.children}");
                }

                final policy = antibiotics.firstWhereOrNull(
                  (a) => a.antibiotic.antibioticId == antibioticId,
                );

                List<AntibioticWithStatus> policyAntibiotics = [];
                if (policy != null && policy.antibiotic.children != null) {
                  policyAntibiotics = antibiotics
                      .where((a) => policy.antibiotic.children!
                          .contains(a.antibiotic.antibioticId))
                      .toList();
                }

                // final line1 = policyAntibiotics
                //     .where((a) => a.antibiotic.type == "line_1")
                //     .toList();

                // final line2 = policyAntibiotics
                //     .where((a) => a.antibiotic.type == "line_2")
                //     .toList();

                // final line3 = policyAntibiotics
                //     .where((a) => a.antibiotic.type == "line_3")
                //     .toList();

                final line1 = _sortByIndex(policyAntibiotics
                    .where((a) => a.antibiotic.type == "line_1")
                    .toList());

                final line2 = _sortByIndex(policyAntibiotics
                    .where((a) => a.antibiotic.type == "line_2")
                    .toList());

                final line3 = _sortByIndex(policyAntibiotics
                    .where((a) => a.antibiotic.type == "line_3")
                    .toList());

                debugPrint(
                    "📄 Showing drugs only for antibioticId=$antibioticId");

                debugPrint("📄 Line 1 count: ${line1.length}");
                line1.forEach((a) => debugPrint(
                    "Line1 -> ${a.antibiotic.antibioticId} - ${a.antibiotic.name}"));

                debugPrint("📄 Line 2 count: ${line2.length}");
                line2.forEach((a) => debugPrint(
                    "Line2 -> ${a.antibiotic.antibioticId} - ${a.antibiotic.name}"));

                debugPrint("📄 Line 3 count: ${line3.length}");
                line3.forEach((a) => debugPrint(
                    "Line3 -> ${a.antibiotic.antibioticId} - ${a.antibiotic.name}"));

                final selected = <String>{};
                String? selectedGroup;

                return StatefulBuilder(
                  builder: (context, setState) {
                    void toggleSelection(String group, String id) {
                      setState(() {
                        if (id == "no_abx") {
                          if (selected.contains("no_abx")) {
                            selected.remove("no_abx");
                            selectedGroup = null;
                          } else {
                            selected.clear();
                            selected.add("no_abx");
                            selectedGroup = "no_abx";
                          }
                        } else {
                          if (selected.contains("no_abx")) {
                            selected.remove("no_abx");
                          }
                          if (selectedGroup == null || selectedGroup == group) {
                            if (selected.contains(id)) {
                              selected.remove(id);
                              if (selected.isEmpty) selectedGroup = null;
                            } else {
                              selected.add(id);
                              selectedGroup = group;
                            }
                          } else {
                            selected.clear();
                            selected.add(id);
                            selectedGroup = group;
                          }
                        }
                      });
                    }

                    Widget buildCheckboxTile(
                        String name, String id, bool isChecked, String group,
                        {bool isBold = false}) {
                      return InkWell(
                        onTap: () => toggleSelection(group, id),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isChecked,
                              onChanged: (_) => toggleSelection(group, id),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isBold
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    Widget buildSection(String title, String group,
                        List<AntibioticWithStatus> list) {
                      if (list.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            title,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                          const SizedBox(height: 6),
                          ...list.map((item) {
                            final id = item.antibiotic.antibioticId;
                            final name = item.antibiotic.name ?? '';
                            final isChecked = selected.contains(id);
                            return buildCheckboxTile(
                                name, id, isChecked, group);
                          }).toList(),
                        ],
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // 👈 allows shrinking
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Choose the prescribed drug(s)",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            // 👈 replaced Expanded
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  buildSection("First Line Antibiotics",
                                      "line_1", line1),
                                  buildSection("Second Line Antibiotics",
                                      "line_2", line2),
                                  buildSection("Third Line Antibiotics",
                                      "line_3", line3),
                                  buildCheckboxTile(
                                    "No Abx as recommended in the policy",
                                    "no_abx",
                                    selected.contains("no_abx"),
                                    "no_abx",
                                    isBold: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(screenContext);
                                    if (navigatorKey.currentContext != null) {
                                      Future.delayed(
                                          const Duration(milliseconds: 300),
                                          () {
                                        CompliancePopup.show(
                                          navigatorKey.currentContext!,
                                          antibioticId!,
                                          submitForm!,
                                          redirectHome: redirectHome,
                                        );
                                      });
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    side: BorderSide(
                                        color: primaryColor, width: 2),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(50)),
                                  ),
                                  child: const Text("Go back",
                                      style: TextStyle(color: primaryColor)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    if (selected.isEmpty) {
                                      Fluttertoast.showToast(
                                          msg:
                                              "Please select at least one drug");
                                      return;
                                    }
                                    Navigator.pop(screenContext);

                                    List<String> lineItemIds;
                                    String lineType = "no_abx";

                                    if (selected.contains("no_abx")) {
                                      lineItemIds = [];
                                    } else {
                                      lineItemIds = selected.toList();

                                      if (line1.any((a) => lineItemIds.contains(
                                          a.antibiotic.antibioticId))) {
                                        lineType = "line_1";
                                      } else if (line2.any((a) =>
                                          lineItemIds.contains(
                                              a.antibiotic.antibioticId))) {
                                        lineType = "line_2";
                                      } else if (line3.any((a) =>
                                          lineItemIds.contains(
                                              a.antibiotic.antibioticId))) {
                                        lineType = "line_3";
                                      }
                                    }

                                    if (lineType == "line_1" ||
                                        lineType == "no_abx") {
                                      if (navigatorKey.currentContext != null) {
                                        Future.delayed(
                                            const Duration(milliseconds: 300),
                                            () async {
                                          HelpfulPopup.show(
                                              navigatorKey.currentContext!,
                                              antibioticId!,
                                              lineItemIds,
                                              submitForm,
                                              redirectHome: redirectHome,
                                              lineType: lineType == "no_abx"
                                                  ? null
                                                  : lineType,
                                              complied: complied);
                                        });
                                      }
                                    } else {
                                      if (navigatorKey.currentContext != null) {
                                        Future.delayed(
                                            const Duration(milliseconds: 300),
                                            () {
                                          ReasonPopup.show(
                                              navigatorKey.currentContext!,
                                              antibioticId!,
                                              lineItemIds,
                                              submitForm,
                                              category: "compliance_yes",
                                              source: "choose_drugs",
                                              lineType: lineType,
                                              complied: complied);
                                        });
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    side: BorderSide(
                                        color: primaryColor, width: 2),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(50)),
                                  ),
                                  child: const Text("Submit",
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
