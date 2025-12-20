import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/home/home_screen.dart';
import 'package:qr_scanner_app/image_row_widget.dart';
import 'package:qr_scanner_app/keycloak/auth_service.dart';
import 'package:qr_scanner_app/login.dart';
import 'package:qr_scanner_app/utilities/connectivity_helper.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool offline24hours = false;
  @override
  void initState() {
    super.initState();

    _checkTokenAndNavigate();
  }

  Future<void> _initializeOfflineStatus() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    offline24hours = prefs.getBool('offline_24hours') ?? false;
    debugPrint('Offline 24 hours initialized: $offline24hours');
  }

  Future<bool> _checkAndHandleVersionChange() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();

    String currentVersion = packageInfo.version;
    String? storedVersion = prefs.getString('app_version');

    debugPrint('Current Version: $currentVersion');
    debugPrint('Stored Version: $storedVersion');

    if (storedVersion == null) {
      // First time launch, just store the version
      await prefs.setString('app_version', currentVersion);
      debugPrint('First launch: Version stored');
      return false;
    } else if (storedVersion != currentVersion) {
      // Version has changed, clear tokens and update stored version
      debugPrint('Version changed from $storedVersion to $currentVersion');
      debugPrint('Trying to refresh tokens for new version...');

      debugPrint(
          'Attempting to refresh tokens using existing refresh token...');

      // ✅ Use the same function from AuthService
      // bool refreshed = await AuthService().isKeycloakRefreshTokenNotExpired();

      // if (refreshed) {
      //   debugPrint('✅ Token successfully refreshed after version change');
      // } else {
      //   debugPrint('⚠️ Token refresh failed, clearing old tokens...');
      // }
      if (mounted) {
        navigateToLoginScreen(context);
      }
      // navigateToLoginScreen(context);

      await prefs.setString('app_version', currentVersion);
      debugPrint('Tokens cleared and version updated');
      return true;
    } else {
      debugPrint('Version unchanged');
      return false;
    }
  }

  Future<void> _checkTokenAndNavigate() async {
    // Simulate a delay for the splash screen
    await Future.delayed(const Duration(seconds: 3));

    // Check if the widget is still mounted before navigating
    if (!mounted) return;

    bool navigatedToLogin = await _checkAndHandleVersionChange();

    if (navigatedToLogin) {
      debugPrint(
          'Already navigated to login due to version change, stopping here');
      return;
    }

    await _initializeOfflineStatus();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_key');
    debugPrint('Access Token splash: $accessToken');

    debugPrint('Offline 24 hours Splash: $offline24hours');

    if (accessToken != null) {
      bool isOffline = await ConnectivityHelper.isOffline();
      if (isOffline) {
        // If offline, navigate to HomeScreen without checking token expiration
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        // bool tokenNotExpired =
        //     await AuthService().isKeycloakRefreshTokenNotExpired();
        if (!offline24hours) {
          // Navigate to LoginScreen if the refresh token is expired
          // Navigator.of(context).pushReplacementNamed(Routes.home);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          // If the refresh token is valid, navigate to HomeScreen
          // Navigator.of(context).pushReplacementNamed(Routes.login);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } else {
      // Navigator.of(context).pushReplacementNamed(Routes.login);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: const Scaffold(
        backgroundColor: Colors.white, // Use any color you want
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Title (Optional)
              Text(
                "ABX Mithra",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),

              SizedBox(height: 20),

              // Simple Loader
              CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),

              SizedBox(height: 10),

              // Subtitle (optional)
              Text(
                "Loading...",
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
