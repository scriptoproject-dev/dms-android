import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/jwt_token.dart';
import 'package:qr_scanner_app/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

JwtToken decodeJwt(String token) {
  Map<String, dynamic> decodedToken = Jwt.parseJwt(token);
  return JwtToken.fromMap(decodedToken);
}

void navigateToLoginScreen(BuildContext context) {
  Navigator.pushNamedAndRemoveUntil(
    context,
    Routes.login, // Use the named route for the login screen
    (Route<dynamic> route) => false, // Remove all previous routes
  );
}

Future<void> unregisterDeviceFromPushNotificationServer() async {
  try {
    // 1) Try to get the current OneSignal subscription id (replacement for old playerId)
    final String? subscriptionId = OneSignal.User.pushSubscription.id;
    debugPrint('OneSignal subscriptionId: $subscriptionId');

    // 2) Inform your server to remove this subscription mapping (so server won't send)
    if (subscriptionId != null && subscriptionId.isNotEmpty) {
      try {
        final baseUrl = Strings.baseUrl;
        final body = {
          'subscription_id': subscriptionId
        }; // match your backend param name
        await ApiClient(baseUrl: baseUrl)
            .post('mobile/user/unregister_device', body: body);
        debugPrint('Notified backend to unregister subscription.');
      } catch (e) {
        debugPrint('Failed to notify backend to unregister subscription: $e');
        // proceed to local cleanup anyway
      }
    } else {
      debugPrint('No OneSignal subscriptionId available (null/empty).');
    }

    // 3) If you used OneSignal.login(externalId) earlier, call logout to disassociate
    try {
      await OneSignal.logout();
      debugPrint('OneSignal.logout() called.');
    } catch (e) {
      debugPrint('OneSignal.logout() failed: $e');
    }

    // 4) Opt the SDK / subscription out of receiving pushes
    // Newer SDKs expose optIn/optOut on User.pushSubscription:
    try {
      await OneSignal.User.pushSubscription.optOut();
      debugPrint('OneSignal.User.pushSubscription.optOut() called.');
    } catch (e) {
      debugPrint('pushSubscription.optOut failed: $e');
      // Older versions used setSubscription(false) or disablePush(true). If you are on
      // an older/newer variant, you may need to call whichever method exists.
    }

    // 5) Optionally clear OS notification shade (wrap in try/catch)
    try {
      await OneSignal.Notifications.clearAll();
      debugPrint('OneSignal notifications cleared.');
    } catch (e) {
      debugPrint('clearAll notifications failed: $e');
    }

    // 6) Clear local user-related prefs so login screen is clean
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('photo_url');
      // optionally clear more keys or prefs.clear()
      debugPrint('Local prefs cleared.');
    } catch (e) {
      debugPrint('Clearing prefs failed: $e');
    }

    debugPrint('Unregistered device from push & cleaned local data.');
  } catch (e) {
    debugPrint('Unexpected error in unregisterDeviceFromPushAndServer: $e');
  }
}

///This below class added by Nayan to resolve the disabled issue in the data pushing with Navigator Key

class AuthHelper {
  /// Try to logout, clear local state and navigate to login.
  /// Uses navigatorKey supplied by your app (from main.dart).
  static Future<void> logoutAndNavigateToLogin(
      GlobalKey<NavigatorState> navigatorKey,
      {String? toastMsg}) async {
    // Optional user feedback
    if (toastMsg != null) {
      Fluttertoast.showToast(msg: toastMsg, toastLength: Toast.LENGTH_LONG);
    }

    // 1. Unregister push and clear local prefs (best-effort)
    try {
      await unregisterDeviceFromPushNotificationServer();
    } catch (e) {
      // ignore errors but log
      debugPrint('Error unregistering device: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // or clear only the auth related keys you need
      debugPrint('Local prefs cleared.');
    } catch (e) {
      debugPrint('Error clearing prefs: $e');
    }

    // 2. Attempt to navigate on UI thread. Use postFrame to avoid mid-frame errors.
    // Retry for a short time if navigator isn't ready yet (e.g. call came from background).
    const int maxAttempts = 6;
    int tries = 0;
    while (tries < maxAttempts) {
      tries++;
      final navState = navigatorKey.currentState;
      if (navState != null) {
        // Dismiss any dialogs but keep at least the first route
        try {
          // pop until only the first route is left (safe)
          navState.popUntil((route) => route.isFirst);
        } catch (e) {
          debugPrint('safe popUntil failed: $e');
        }

        // run navigation in post frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            navigatorKey.currentState
                ?.pushNamedAndRemoveUntil(Routes.login, (route) => false);
          } catch (e) {
            debugPrint('Navigation exception: $e');
          }
        });
        return;
      }

      // Navigator not ready — wait a bit and retry (gives UI isolate time to initialize)
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // If still not navigated, set a flag in prefs so the app can navigate on resume
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('force_logout_on_resume', true);
      debugPrint(
          'Set force_logout_on_resume flag; navigation will happen when UI resumes.');
    } catch (e) {
      debugPrint('Failed to set force_logout_on_resume: $e');
    }
  }
}

class UnauthorizedException implements Exception {
  final String? message;
  UnauthorizedException([this.message]);
  @override
  String toString() => 'UnauthorizedException: ${message ?? ''}';
}
