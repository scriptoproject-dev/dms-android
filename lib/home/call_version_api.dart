import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/antibiogram/call_antibiogram_api.dart';
import 'package:qr_scanner_app/antibiotic_policy/antibiotic_db_helper.dart';
import 'package:qr_scanner_app/antibiotic_policy/antibiotic_policy_api.dart';
import 'package:qr_scanner_app/antibiotic_policy/reason_popup.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/e_learn/callELearnAPI.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/reasons.dart';
import 'package:qr_scanner_app/notification/API_notification.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CallVersionAPI {
//   final ApiClient apiClient = ApiClient(baseUrl: Strings.baseUrl);
//   List<bool> versionChangedFlags = [false, false, false, false];
//   bool anyVersionChanged = false;

//   CallVersionAPI();
//   CallAntibiogramAPI antibiogramAPI = CallAntibiogramAPI();

//   Future<void> fetchAndStoreVersion({BuildContext? context}) async {
//     bool offline24hours;
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String siteId = prefs.getString('site_id') ?? '';

//     // Fetch notifications
//     NotificationAPI notificationService = NotificationAPI();
//     await notificationService.fetchNotifications();
//     debugPrint('Notifications fetched in version API.');

//     await _checkExistingVersions(prefs);

//     try {
//       // debugPrint('siteId from version: $siteId');
//       final versionResponse = await apiClient.get('version?site_id=$siteId');
//       debugPrint('API Response version: ${versionResponse.body}');
//       debugPrint("versionResponse.statusCode: ${versionResponse.statusCode}");

//       if (versionResponse.statusCode == 200) {
//         final versionData = json.decode(versionResponse.body);
//         if (versionData != null && versionData.containsKey('data')) {
//           final data = versionData['data'];

//           final AntibioticPolicyAPI antibioticPolicy = AntibioticPolicyAPI();
//           antibioticPolicy.getAllBookmarksAPI();
//           antibiogramAPI.fetchAndDownloadAntibiogramPDF();

//           List<Future<void>> downloadTasks = [];

//           // **OPTIMIZED API CALLS: Store condition in a variable and call once**
//           bool isAntibioticChanged = await _handleVersionChange(
//             'antibiotics',
//             data['antibiotics'],
//             prefs,
//             'server_antibiotic_version',
//             () async {},
//             context,
//           );
//           if (isAntibioticChanged) {
//             downloadTasks.add(handleAntibioticData());
//           }

//           bool isAntibiogramChanged = await _handleVersionChange(
//             'antibiograms',
//             data['antibiograms'],
//             prefs,
//             'server_antibiogram_version',
//             () async {},
//             context,
//           );
//           if (isAntibiogramChanged) {
//             downloadTasks.add(callAntibiogramAPI(context));
//           }

//           bool isReasonChanged = await _handleVersionChange(
//             'reasons',
//             data['reasons'],
//             prefs,
//             'server_reasons_version',
//             () async {},
//             context,
//           );
//           if (isReasonChanged) {
//             downloadTasks.add(callReason());
//           }

//           bool isELearnChanged = await _handleVersionChange(
//             'elearns',
//             data['elearns'],
//             prefs,
//             'server_elearns_version',
//             () async {},
//             context,
//           );
//           if (isELearnChanged) {
//             downloadTasks.add(callELearnAPI(context));
//           }

//           // Wait for all download tasks to finish
//           await Future.wait(downloadTasks);

//           // Dismiss the dialog after all downloads are complete
//           if (context != null && anyVersionChanged) {
//             debugPrint('Stopping dialog');
//             Navigator.of(context).pop();
//           }

//           await _storeAuditLog(data);
//           debugPrint(
//               'Version changed flags: ${versionChangedFlags.toString()}');
//         } else {
//           debugPrint(
//               'Version data is missing or does not contain expected keys.');
//         }
//       } else if (versionResponse.statusCode == 401) {
//         Fluttertoast.showToast(
//             msg: 'Account Disabled. Please contact support.');
//         await unregisterDeviceFromPushNotificationServer();
//         if (context != null) {
//           navigateToLoginScreen(context);
//         }
//       } else {
//         debugPrint(
//             'Failed to get version info from API. Status code: ${versionResponse.statusCode}');
//       }
//     } catch (e) {
//       debugPrint('Error fetching version info: $e');
//     } finally {
//       debugPrint('All data stored successfully.');

//       final SharedPreferences prefs = await SharedPreferences.getInstance();
//       offline24hours = prefs.getBool('offline_24hours') ?? false;
//       debugPrint('Offline 24 hours initialized in version: $offline24hours');

//       if (offline24hours) {
//         debugPrint('Initializing: $offline24hours');
//         await prefs.setBool('offline_24hours', false);
//         debugPrint('Offline reset to false');
//       }
//     }
//   }

//   void _showLoadingDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       barrierDismissible: false, // Prevent dismissing by tapping outside
//       builder: (BuildContext context) {
//         return WillPopScope(
//           onWillPop: () async => false, // Disable back button
//           child: const AlertDialog(
//             content: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 CircularProgressIndicator(),
//                 SizedBox(width: 16),
//                 Expanded(
//                   child: Text(
//                     "Downloading data, please wait...",
//                     overflow: TextOverflow.ellipsis,
//                     softWrap: true,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   // Method to handle version changes
//   Future<bool> _handleVersionChange(
//     String key,
//     dynamic newVersion,
//     SharedPreferences prefs,
//     String prefKey,
//     Function onVersionChange,
//     BuildContext? context, // Add context as a parameter
//   ) async {
//     double? existingVersion = prefs.getDouble(prefKey);
//     bool versionChanged = false;

//     if (newVersion != null) {
//       debugPrint('Fetched new $key version: $newVersion');
//       if (existingVersion == null || newVersion != existingVersion) {
//         debugPrint(
//             'Version change detected for $key: $existingVersion -> $newVersion. Calling the required method.');
//         onVersionChange();
//         versionChanged = true; // Mark as version changed

//         // Show the dialog only if context is available and it's the first version change
//         if (context != null && !anyVersionChanged) {
//           anyVersionChanged = true; // Set the flag to true
//           _showLoadingDialog(context);
//         }
//       } else {
//         debugPrint(
//             'No version change for $key. Existing version: $existingVersion');
//       }

//       // Store the new version
//       await prefs.setDouble(prefKey, (newVersion as num).toDouble());
//     } else {
//       debugPrint('No version data available for $key');
//     }

//     return versionChanged;
//   }

//   // Check for existing versions in SharedPreferences
//   Future<void> _checkExistingVersions(SharedPreferences prefs) async {
//     double? antibioticVersion = prefs.getDouble('server_antibiotic_version');
//     double? antibiogramVersion = prefs.getDouble('server_antibiogram_version');
//     double? reasonsVersion = prefs.getDouble('server_reasons_version');
//     double? elearnsVersion = prefs.getDouble('server_elearns_version');

//     if (antibioticVersion != null) {
//       debugPrint('Existing antibiotics version: $antibioticVersion');
//     } else {
//       debugPrint('No existing antibiotics version found in SharedPreferences.');
//     }

//     if (antibiogramVersion != null) {
//       debugPrint('Existing antibiograms version: $antibiogramVersion');
//     } else {
//       debugPrint(
//           'No existing antibiograms version found in SharedPreferences.');
//     }

//     if (reasonsVersion != null) {
//       debugPrint('Existing reasons version: $reasonsVersion');
//     } else {
//       debugPrint('No existing reasons version found in SharedPreferences.');
//     }

//     if (elearnsVersion != null) {
//       debugPrint('Existing elearns version: $elearnsVersion');
//     } else {
//       debugPrint('No existing elearns version found in SharedPreferences.');
//     }
//   }

//   // Store audit log information if needed
//   Future<void> _storeAuditLog(Map<String, dynamic> data) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     if (data.containsKey('audit_log')) {
//       final auditLog = data['audit_log'];
//       if (auditLog.containsKey('created_by')) {
//         await prefs.setString('audit_log_created_by', auditLog['created_by']);
//         debugPrint('Stored audit log created by: ${auditLog['created_by']}');
//       }
//     }
//   }

//   // Placeholder methods to handle version updates
//   Future<bool> handleAntibioticData() async {
//     bool isAntibioticDownloaded = false;
//     debugPrint('isAntibioticDownloaded: $isAntibioticDownloaded');
//     debugPrint('Handling antibiotic data...');
//     final AntibioticPolicyAPI antibioticPolicy = AntibioticPolicyAPI();
//     isAntibioticDownloaded = await antibioticPolicy.fetchInfectionsFromApi();
//     debugPrint('isAntibioticDownloaded: $isAntibioticDownloaded');
//     if (isAntibioticDownloaded) {
//       debugPrint('All antibiotic data downloaded successfully.');
//     } else {
//       debugPrint('Failed to download antibiotic data.');
//     }
//     return isAntibioticDownloaded;
//     // antibioticPolicy.fetchInfectionsFromApi();
//     // antibioticPolicy.getAllBookmarksAPI();
//   }

//   Future<bool> callAntibiogramAPI(BuildContext? context) async {
//     // if (context == null) {
//     //   debugPrint(
//     //       'Context is null, skipping dialog display for Antibiogram API.');
//     //   return false;
//     // }
//     bool isAntibiogramDownloaded = false;
//     debugPrint('isAntibiogramDownloaded: $isAntibiogramDownloaded');

//     CallAntibiogramAPI antibiogramAPI = CallAntibiogramAPI();
//     isAntibiogramDownloaded =
//         await antibiogramAPI.fetchAndStoreAntibiogramData();
//     debugPrint('isAntibiogramDownloaded: $isAntibiogramDownloaded');
//     debugPrint(
//         'Antibiogram data fetched and stored successfully: $isAntibiogramDownloaded');
//     return isAntibiogramDownloaded;
//   }

// // antibiogramAPI.fetchAndDownloadAntibiogramPDF();
//   Future<bool> callReason([
//     ValueNotifier<bool>? isLoading,
//   ]) async {
//     isLoading ??= ValueNotifier<bool>(false);
//     bool isReasonDownloaded = false;
//     debugPrint('Calling reason API...');
//     debugPrint('isReasonDownloaded: $isReasonDownloaded');

//     // Online: Fetch reasons from API
//     List<Reason> reasons = [];

//     try {
//       final result = await ReasonPopup.fetchReasons();
//       reasons = result['reasons'] ?? [];

//       // Check if reasons list is empty
//       if (reasons.isEmpty) {
//         debugPrint('Reasons list is empty. Clearing the database.');
//         await DBHelper.clearReasonsTable(); // Clear the reasons table
//       } else {
//         await DBHelper.clearReasonsTable();
//         // Store reasons in the local database
//         for (var reason in reasons) {
//           await DBHelper.insertReason({
//             'reason_id': reason.reasonId,
//             'reason': reason.reason,
//             'site_id': reason.siteId,
//             'status': reason.status,
//             'audit_log': jsonEncode(reason.auditLog?.toJson()),
//             'category': reason.category, // Convert AuditLog to JSON
//           });
//         }
//         debugPrint('All reasons downloaded successfully');
//         isReasonDownloaded = true;
//       }
//     } catch (error) {
//       debugPrint('Error calling reason API: $error');
//     }
//     debugPrint('isReasonDownloaded: $isReasonDownloaded');
//     return isReasonDownloaded;
//   }

//   // Call the eLearn API using the CallELearnAPI class
//   Future<bool> callELearnAPI(BuildContext? context) async {
//     bool isELearnDownloaded = false;
//     debugPrint('isdataDownloaded: $isELearnDownloaded ');

//     // CallELearnAPI eLearnAPI = CallELearnAPI(context);
//     // isELearnDownloaded = await eLearnAPI.fetchELearnData();

//     debugPrint('isdataDownloaded: $isELearnDownloaded ');
//     debugPrint('ELearn Data fetched successfully: $isELearnDownloaded');
//     return isELearnDownloaded;
//   }
}
