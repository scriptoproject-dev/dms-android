import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/routes.dart';

class SignUpConfirmationScreen extends StatelessWidget {
  const SignUpConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Redirect to login when back button is pressed
        Navigator.pushNamedAndRemoveUntil(
            context, Routes.login, (route) => false);
        return false; // Prevent default back action
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1st Row: Image
                    Image.asset(
                      'assets/images/Subtract.png', // Update this path as needed
                      height: 120, // Adjust height as needed
                      width: 120, // Adjust width as needed
                    ),
                    const SizedBox(height: 40), // Spacing

                    // 2nd Row: Confirmation Message
                    const Text(
                      Strings.confirmationMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24), // Spacing

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40.0),
                      child: Text(
                        Strings.emailUpdateMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: fontLight,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Close Button at bottom
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56, // Makes the button full-width
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                          context, Routes.login); // Go to login screen
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).primaryColor, // Primary color text
                      backgroundColor: Colors.white, // White background
                      side: const BorderSide(
                          color: primaryColor), // Primary color border
                      padding: const EdgeInsets.symmetric(
                          vertical: 14.0), // Vertical padding for button
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(28), // Set border radius
                      ),
                    ),
                    child: const Text(
                      Strings.closeButton,
                      style: TextStyle(fontSize: 16, color: primaryColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
