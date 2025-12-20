import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io'; // For pinging an external server

Future<bool> isTrulyOffline() async {
  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult.first == ConnectivityResult.none) {
    return true; // No network at all
  }

  // Check if actual internet is available
  try {
    final result = await InternetAddress.lookup('8.8.8.8');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return false; // Internet is working
    }
  } catch (e) {
    return true; // No actual internet access
  }
  return true; // Default to offline if unknown
}

// import 'package:http/http.dart' as http;

// Future<bool> isTrulyOffline() async {
//   var connectivityResult = await Connectivity().checkConnectivity();
//   if (connectivityResult == ConnectivityResult.none) {
//     return true; // No network at all
//   }

//   // Check if actual internet is available by making an HTTP request
//   try {
//     final response = await http
//         .get(Uri.parse('https://www.google.com'))
//         .timeout(Duration(seconds: 5));
//     if (response.statusCode == 200) {
//       return false; // Internet is working
//     }
//   } catch (e) {
//     return true; // No actual internet access
//   }

//   return true; // Default to offline if unknown
// }
