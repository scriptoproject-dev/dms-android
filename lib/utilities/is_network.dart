import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

Future<bool> isNetworkOffline() async {
  var connectivityResult = await Connectivity().checkConnectivity();

  if (connectivityResult.first == ConnectivityResult.none) {
    return true; // No network at all
  }

  // Mobile Data is considered always online (no need to check internet access)
  if (connectivityResult.first == ConnectivityResult.mobile) {
    return false;
  }

  // WiFi or Hotspot (Other) → Check if internet is really accessible
  return await checkInternetAccess();
}

// **Helper Function: Checks Real Internet Access**
Future<bool> checkInternetAccess() async {
  try {
    final response = await http
        .get(Uri.parse('https://clients3.google.com/generate_204'))
        .timeout(const Duration(seconds: 3));
    debugPrint("reason profile networkss ${response.statusCode}");
    return response.statusCode != 204;
  } catch (e) {
    return true; // No actual internet access
  }
}
