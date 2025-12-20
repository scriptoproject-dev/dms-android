import 'package:flutter/material.dart';
import 'package:qr_scanner_app/Qr_Scanner/qr_scanner_first_screen.dart';
import 'package:qr_scanner_app/antibiogram/antibiogram.dart';
import 'package:qr_scanner_app/antibiogram/category_antibiogram.dart';
import 'package:qr_scanner_app/antibiotic_policy/infection_list_screen.dart';
import 'package:qr_scanner_app/bookmark_screen.dart';
import 'package:qr_scanner_app/chat/chat_initial_screen.dart';
import 'package:qr_scanner_app/create_account.dart';
import 'package:qr_scanner_app/e_learn/e_learn.dart';
import 'package:qr_scanner_app/e_learn/e_learn_content.dart';
import 'package:qr_scanner_app/feedback_screen.dart';
import 'package:qr_scanner_app/home/home_screen.dart';
import 'package:qr_scanner_app/login.dart';
import 'package:qr_scanner_app/models/antibiotic_with_status.dart';
import 'package:qr_scanner_app/notification/notification_screen.dart';
import 'package:qr_scanner_app/profile.dart';
import 'package:qr_scanner_app/signup_confirmation.dart';
import 'package:qr_scanner_app/splash_screen.dart';
import 'package:qr_scanner_app/treatment_guidelines/web_view.dart';

// Import the LoginScreen

class Routes {
  static const String splash = '/splash';
  static const String login = '/login'; // Login route
  static const String home = '/home';
  static const String bookmarks = '/bookmarks';
  static const String chat = '/chat';
  static const String notifications = '/notifications';
  static const String feedback = '/feedback';
  static const String createAccount = '/createAccount';
  static const String signupConfirmation = '/signupConfirmation';
  static const String profile = '/profile';
  static const String changePassword = '/changePassword';
  static const String infectionList = '/infectionList';
  static const String antibiogram = '/antibiogram';
  static const String treatmentGuidelines = '/treatmentGuidelines';
  static const String elearn = '/elearn';
  static const String categoryAntibiogram = '/categoryAntibiogram';
  static const String eLearnContent = '/eLearnContent';

  static const String qrScannerFirstScreen = '/qrScannerFirstScreen ';
  static const String qrScannerSecondScreen = '/qrScannerSecondScreen';

  // This method retrieves the route based on the index
  static Widget getScreenByIndex(int index,
      {List<AntibioticWithStatus>? bookmarkedAntibiotics,
      Function? onRefreshBookmarks}) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return BookmarkScreen(
          // bookmarkedAntibiotics: bookmarkedAntibiotics ?? [],
          onRefreshBookmarks: onRefreshBookmarks,
        );
      case 2:
        return const ChatInitialScreen();
      case 3:
        return const NotificationScreen();
      case 4:
        return const FeedbackScreen();
      default:
        return const HomeScreen();
    }
  }

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
            settings: const RouteSettings(name: splash),
            builder: (_) => const SplashScreen()); // Add this line
      case login:
        return MaterialPageRoute(
          settings: const RouteSettings(name: login),
          builder: (_) => const LoginScreen(),
        );
      case createAccount:
        return MaterialPageRoute(builder: (_) => const CreateAccountScreen());
      case home:
        return MaterialPageRoute(
          settings: const RouteSettings(name: home),
          builder: (_) => const HomeScreen(),
        );
      case bookmarks:
        final args = settings.arguments as Map<String, dynamic>?;
        final bookmarkedAntibiotics =
            args?['bookmarkedAntibiotics'] as List<AntibioticWithStatus>? ?? [];

        debugPrint("bookmarkedAntibiotics routes --$bookmarkedAntibiotics");
        final Function onRefreshBookmarks = args?['onRefreshBookmarks'];
        return MaterialPageRoute(
          builder: (_) => BookmarkScreen(
            // bookmarkedAntibiotics: bookmarkedAntibiotics,
            onRefreshBookmarks: onRefreshBookmarks,
          ),
        );
      // return MaterialPageRoute(builder: (_) => BookmarkScreen(antibiotics: antibiotics));
      case chat:
        return MaterialPageRoute(builder: (_) => const ChatInitialScreen());
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationScreen());
      case feedback:
        return MaterialPageRoute(builder: (_) => const FeedbackScreen());
      case signupConfirmation:
        return MaterialPageRoute(
            builder: (_) => const SignUpConfirmationScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      // case changePassword:
      //   return MaterialPageRoute(builder: (_) => ChangePasswordScreen());
      // case infectionList:
      //   return MaterialPageRoute(builder: (_) => InfectionListScreen());
      case infectionList:
        final args = settings.arguments
            as Map<String, dynamic>?; // Use arguments to pass data
        // final infections = args?['infections'] as List<Antibiotic>? ?? [];
        // final antibiotics =
        //     args?['antibiotics'] as List<AntibioticWithStatus>? ?? [];
        final Function? onRefreshBookmarks =
            args?['onRefreshBookmarks']; // Retrieve the refresh function
        return MaterialPageRoute(
          builder: (_) => InfectionListScreen(
            // infections: infections,
            // antibiotics: antibiotics,
            onRefreshBookmarks: onRefreshBookmarks,
          ),
        );
      case antibiogram:
        return MaterialPageRoute(
          builder: (_) => const AntibiogramScreen(),
        );
      case treatmentGuidelines:
        return MaterialPageRoute(
          builder: (_) => const WebViewPage(),
        );
      case elearn:
        return MaterialPageRoute(
          builder: (_) => const ELearnPage(),
        );
      case categoryAntibiogram:
        final args = settings.arguments as Map<String, dynamic>?;
        final title = args?['title'] ?? '';
        final sampleTypeId = args != null && args['sampleTypeId'] != null
            ? args['sampleTypeId']
            : "";
        final subCategory = args != null && args['subCategory'] != null
            ? args['subCategory'].toString()
            : "";
        final categoryId = args != null && args['categoryId'] != null
            ? args['categoryId'].toString()
            : "";
        final categoriesList = args != null && args['categoriesList'] != null
            ? args['categoriesList']
            : [];
        return MaterialPageRoute(
          builder: (_) => CategoryAntibiogram(
            title: title,
            sampleTypeId: sampleTypeId,
            subCategory: subCategory,
            categoryId: categoryId,
            categoriesList: categoriesList,
          ),
        );
      case eLearnContent:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ELearnContentScreen(
            title: args?['title'] ?? '',
            description: args?['description'] ?? '',
            eLearnId: args?['eLearnId'],
            thumbnailId: args?['thumbnailId'],
            modifiedOn: args?['modifiedOn'],
            liked: args?['liked'],
            disliked: args?['disliked'],
          ),
        );

      case qrScannerFirstScreen:
        return MaterialPageRoute(
          builder: (_) => const QRScannerScreen(),
        );

      // case qrScannerFirstScreen:
      //   return MaterialPageRoute(
      //     builder: (_) => const QRScannerSecondScreen(),
      //   );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            // appBar: AppBar(
            //   title: const Text('404'),
            //   automaticallyImplyLeading: false,
            // ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Page not found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.home),
                    label: const Text('Go to Home'),
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        _,
                        Routes.home, // 👈 your home route
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }
}
