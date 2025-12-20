import 'package:flutter/services.dart';

class EmailInputFormatter extends TextInputFormatter {
  final RegExp emailRegex =
      RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (emailRegex.hasMatch(newValue.text)) {
      return newValue;
    } else {
      return oldValue;
    }
  }
}

String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Please enter a valid email address.';
  }
  final emailRegex =
      RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
  if (!emailRegex.hasMatch(value)) {
    return 'Please enter a valid email address.';
  }
  return null;
}
