import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/antibiotic_policy/antibiotic_db_helper.dart';
import 'package:qr_scanner_app/antibiotic_policy/celebration_popup.dart';
import 'package:qr_scanner_app/main.dart';
import 'package:qr_scanner_app/routes.dart';
import 'package:qr_scanner_app/utilities/is_network.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';

class ComplianceService {
  static Map<String, dynamic> buildPayload({
    required String antibioticId,
    List<String>? lineItemIds,
    bool? complied,
    String? lineType,
    String? reasonId,
    String? message,
    String? otherDrugs,
    String? otherDrugsReasonId,
    String? otherDrugsMessage,
    bool? helpful,
    String? helpfulMessage,
    String? category,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final Map<String, dynamic> payload = {
      "date": now,
      "antibiotic_id": antibioticId,
      "complied": complied ?? false,
      "line_items_ids": lineItemIds ?? [],
      "line_types": lineType,
      "reason_id": reasonId,
      "message": message,
      "other_durgs": otherDrugs,
      "other_durgs_reason_id": otherDrugsReasonId,
      "other_durgs_message": otherDrugsMessage,
      "helpful": helpful,
      "helpful_message": helpfulMessage,
    };

    if (lineType != null) {
      payload["line_types"] = lineType;
    }

    if (reasonId != null) payload["reason_id"] = reasonId;
    if (message != null) payload["message"] = message;

    if (lineType == "line_2" || lineType == "line_3") {
      payload["reason_id"] = reasonId;
      if (reasonId == "Others") {
        payload["message"] = message;
      }
    }

    if (helpful == true) {
      payload["source"] = "helpful_yes";
    } else if (message != null || otherDrugsMessage != null) {
      payload["source"] = "specify_submit";
    } else {
      payload["source"] = "other";
    }

    if (otherDrugs != null) payload["other_durgs"] = otherDrugs;
    if (otherDrugsReasonId != null) {
      payload["other_durgs_reason_id"] = otherDrugsReasonId;
    }
    if (otherDrugsMessage != null) {
      payload["other_durgs_message"] = otherDrugsMessage;
    }

    if (helpful != null) {
      payload["helpful"] = helpful;
      if (helpful == false && helpfulMessage != null) {
        payload["helpful_message"] = helpfulMessage;
      }
    }

    return payload;
  }

  static Future<void> submitCompliance(
    Map<String, dynamic> payload,
    Function submitForm, {
    bool? redirectHome,
    BuildContext? context,
  }) async {
    debugPrint("🔥".padRight(50, "🔥"));
    debugPrint("🔥 submitCompliance CALLED");
    debugPrint("🔥 submitForm type: ${submitForm.runtimeType}");
    debugPrint("🔥 Payload: $payload");
    debugPrint("🔥".padRight(50, "🔥"));

    String source;
    if (payload["helpful"] == true) {
      source = "helpful_yes";
    } else if (payload.containsKey("specify_message")) {
      source = "specify_submit";
    } else {
      source = "other";
    }

    debugPrint("📝 Compliance Request Body: $payload");
    debugPrint("📌 Source detected: $source");

    bool isOffline = await isNetworkOffline();

    if (!isOffline) {
      bool isAuthError = false;
      bool isSuccess = false;

      try {
        debugPrint("🔄 Calling submitForm...");
        await submitForm([payload]);
        debugPrint("✅ submitForm completed without exception");
        isSuccess = true;
      } on UnauthorizedException catch (e) {
        debugPrint("🚨🚨🚨 UnauthorizedException CAUGHT: $e");
        isAuthError = true;
      } catch (e) {
        debugPrint("❌ Other exception caught: $e");
        debugPrint("❌ Error type: ${e.runtimeType}");

        final errorString = e.toString().toLowerCase();
        if (errorString.contains('401') ||
            errorString.contains('403') ||
            errorString.contains('unauthorized') ||
            errorString.contains('account disabled') ||
            errorString.contains('user is disabled') ||
            errorString.contains('invalid_grant')) {
          debugPrint("🚨🚨🚨 Auth error detected in exception message");
          isAuthError = true;
        } else {
          Fluttertoast.showToast(msg: "API error: $e");
        }
      }

      debugPrint(
          "🔍 After try-catch: isAuthError=$isAuthError, isSuccess=$isSuccess");

      // ✅ CRITICAL: Handle auth error FIRST
      if (isAuthError) {
        debugPrint("🚨🚨🚨 AUTHENTICATION ERROR - HANDLING NOW");

        // ✅ Show toast immediately
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.',
            toastLength: Toast.LENGTH_LONG);

        // ✅ Get context
        final navContext = context ?? navigatorKey.currentContext;

        // ✅ Close ALL open dialogs/sheets
        if (navContext != null) {
          try {
            debugPrint("🚨 Closing all dialogs...");
            // Pop until we reach a route (not a dialog)
            Navigator.of(navContext, rootNavigator: true).popUntil((route) {
              debugPrint(
                  "🔍 Checking route: ${route.settings.name}, isFirst: ${route.isFirst}");
              return route.isFirst || route.settings.name != null;
            });
          } catch (e) {
            debugPrint("⚠️ Error closing dialogs: $e");
          }
        }

        // ✅ Wait for UI to update
        await Future.delayed(const Duration(milliseconds: 200));

        // ✅ Unregister device
        try {
          debugPrint("🚨 Unregistering device...");
          await unregisterDeviceFromPushNotificationServer();
        } catch (e) {
          debugPrint("⚠️ Error unregistering: $e");
        }

        // ✅ Wait again
        await Future.delayed(const Duration(milliseconds: 200));

        // ✅ Navigate to login
        if (navContext != null) {
          debugPrint("🚨 Navigating to login screen NOW");
          navigateToLoginScreen(navContext);
        }

        // ✅ EXIT IMMEDIATELY
        debugPrint("🚨 EXITING submitCompliance - NO CELEBRATION");
        return; // ⚠️⚠️⚠️ CRITICAL - STOP HERE
      }

      // ✅ Only reach here if NOT an auth error
      if (isSuccess) {
        debugPrint("🎉🎉🎉 SUCCESS - SHOWING CELEBRATION");
        // _showAppropriateMessage(payload);

        if (redirectHome ?? false) {
          Navigator.pushNamed(navigatorKey.currentContext!, Routes.home);
          await Future.delayed(const Duration(milliseconds: 400));
          _showAppropriateMessage(payload);
        } else {
          // Show celebration immediately if not redirecting
          _showAppropriateMessage(payload);
        }
      } else {
        debugPrint("❌ Not successful, no celebration");
      }
    } else {
      // Offline mode
      try {
        payload.addAll({"connection": "offline", "compile_status": "yes"});
        await DBHelper.insertCompliance(payload);
        debugPrint(
            "💾 Saved offline [${payload["source"] ?? "unknown"}]: $payload");
        // Fluttertoast.showToast(msg: "Saved offline. Will sync later.");
        // 🎉 Show celebration popup even for offline save
        // CelebrationPopup.show(navigatorKey.currentContext!);
        _showAppropriateMessage(payload);
      } catch (e) {
        debugPrint("❌ DB error [${payload["source"] ?? "unknown"}]: $e");
        Fluttertoast.showToast(msg: "DB error: $e");
      }
    }

    debugPrint("🔥 submitCompliance ENDED");
  }

  static void _showAppropriateMessage(Map<String, dynamic> payload) {
    debugPrint("🎯 _showAppropriateMessage called");

    if (navigatorKey.currentContext == null) {
      debugPrint(
          "⚠️ navigatorKey.currentContext is null, cannot show celebration");
      return;
    }

    final bool isFirstLine = payload["line_types"] == "line_1";
    final bool isHelpfulYes = payload["helpful"] == true;

    debugPrint(
        "🎯 Celebration check: isFirstLine=$isFirstLine, isHelpfulYes=$isHelpfulYes");

    if (isFirstLine && isHelpfulYes) {
      debugPrint("🎉 Showing Well Done message");
      CelebrationPopup.showWellDone(navigatorKey.currentContext!);
    } else {
      debugPrint("👍 Showing Thank You message");
      CelebrationPopup.showThankYou(navigatorKey.currentContext!);
    }
  }
}
