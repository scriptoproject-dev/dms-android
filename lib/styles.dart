import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/colors.dart';
// import 'package:google_fonts/google_fonts.dart';
// Ensure you have your color constants defined here

class CustomStyles {
  static final InputDecoration textFieldDecoration = InputDecoration(
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    contentPadding:
        const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4.0),
      borderSide: const BorderSide(),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4.0),
      borderSide: const BorderSide(color: gray),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4.0),
      borderSide: const BorderSide(color: gray),
    ),
    labelStyle: const TextStyle(color: gray, fontSize: 14),
    hintStyle: const TextStyle(color: gray, fontSize: 14),
  );

  static final ButtonStyle elevatedButtonStyle = ElevatedButton.styleFrom(
    foregroundColor: primaryColor,
    backgroundColor: primaryColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
    ),
    textStyle: const TextStyle(fontSize: 16),
    padding: const EdgeInsets.symmetric(vertical: 17.0),
  );

  // static TextStyle textStyle = GoogleFonts.ubuntuTextTheme().copyWith();
}
