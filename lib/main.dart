import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_scanner_app/background_services/foreground_services.dart';
import 'package:qr_scanner_app/background_services/push_notification_service.dart';
import 'package:qr_scanner_app/constants/strings.dart';

import 'routes.dart';

final PushNotificationService pushNotificationService =
    PushNotificationService();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ensureTaskHandlerRegistered();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const MyApp());
  });
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void ensureTaskHandlerRegistered() {
  FlutterForegroundTask.setTaskHandler(NetworkTaskHandler(navigatorKey));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  late final ForegroundServices foregroundServices;
  // late final BackgroundService24Hours backgroundService24Hours;

  @override
  void initState() {
    super.initState();

    pushNotificationService.configure(Strings.oneSignalId);

    // Initialize DataPushingService with the navigatorKey

    // Initialize Foreground Services
    foregroundServices = ForegroundServices(navigatorKey);
    foregroundServices.initializeForegroundService().then((_) {
      foregroundServices.startForegroundService();
    }).catchError((error) {
      debugPrint("Error initializing foreground service: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DMS',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        textTheme: GoogleFonts.latoTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      initialRoute: Routes.splash,
      onGenerateRoute: Routes.generateRoute,
      navigatorObservers: [
        AppRouteObserver(
          onRouteChange: (currentRoute) {
            debugPrint('Current route: $currentRoute');
          },
        ),
      ],
    );
  }
}

class AppRouteObserver extends NavigatorObserver {
  final Function(String) onRouteChange;

  AppRouteObserver({required this.onRouteChange});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRouteChange(route);
    debugPrint('didPush: ${route.settings.name}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRouteChange(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _logRouteChange(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logRouteChange(newRoute);
  }

  void _logRouteChange(Route<dynamic>? route) {
    if (route?.settings.name != null) {
      onRouteChange(route!.settings.name!);
    }
  }
}

void showToastMessage(BuildContext context, String title) {
  Fluttertoast.showToast(
    msg: title,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.BOTTOM,
    timeInSecForIosWeb: 2,
    backgroundColor: Colors.white,
    textColor: Colors.black,
    fontSize: 16.0,
    webPosition: "center",
  );
}
