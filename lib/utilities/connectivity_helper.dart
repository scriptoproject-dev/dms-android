import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityHelper {
  /// Checks the current connectivity status.
  static Future<bool> isOffline() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.first == ConnectivityResult.none;
  }
}
