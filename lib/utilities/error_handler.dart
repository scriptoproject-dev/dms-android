import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/models/error_response.dart';

class ErrorHandler {
  static void handleErrorResponse(dynamic response) {
    try {
      if (response is Map<String, dynamic>) {
        final errorResponse = ErrorResponse.fromJson(response);
        _showToast(errorResponse.errorMessage);
      } else {
        _showToast('Unknown error occurred.');
      }
    } catch (e) {
      _showToast('An error occurred while processing the response.');
    }
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
}
