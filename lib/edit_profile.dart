import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/input_validators/email_validator.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/user_profile.dart';
import 'package:qr_scanner_app/styles.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  final UserData userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  bool _isFormSubmitted = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userData.name;
    _emailController.text = widget.userData.email;
    _ageController.text =
        widget.userData.age?.toString() ?? ''; // Ensure age is a string
  }

  Future<void> _updateProfile(
      BuildContext context, String name, String email, String age) async {
    final baseUrl = Strings.baseUrl;
    final prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('user_id') ?? '';
    Map<String, dynamic> requestBody = {
      'name': name,
      'email': email,
      'age': age
    };

    try {
      final response = await ApiClient(baseUrl: baseUrl)
          .put('users/$userId', body: requestBody);
      debugPrint('API Response update profile: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint("Decoded user data: ${data['data']}");
        if (data['status'] == 200) {
          _showToast(data['message']);

          prefs.setString('editedName', name);
          Navigator.pop(context, UserData.fromJson(data['data']));
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      debugPrint('Error in _updateProfile: $e');
      _showToast('Error: ${e.toString()}');
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          Strings.editProfileButton,
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: _isFormSubmitted
              ? AutovalidateMode
                  .onUserInteraction // Only show errors after submission : AutovalidateMode.disabled,
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: CustomStyles.textFieldDecoration.copyWith(
                  labelText: Strings.nameHint,
                ),
                // inputFormatters: [
                //   AlphanumericInputFormatter(), // Add the Alphanumeric Input Formatter
                // ],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp('[a-zA-Z ]')), // Allow alphabets and spaces
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
                onChanged: (value) {
                  // No need to call setState here
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: CustomStyles.textFieldDecoration.copyWith(
                  labelText: Strings.emailHint,
                ),
                validator: (value) {
                  return validateEmail(value);
                },
                onChanged: (value) {
                  // No need to call setState here
                },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _ageController,
                decoration: CustomStyles.textFieldDecoration.copyWith(
                  labelText: Strings.ageHint,
                ),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(10), // Limit to 10 digits
                  FilteringTextInputFormatter.digitsOnly, // Allow only digits
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Age is required';
                  }
                  final int? age = int.tryParse(value);
                  if (age == null) {
                    return 'Please enter a valid number';
                  }
                  if (age < 0 || age > 120) {
                    return 'Please enter a valid age between 0 and 120';
                  }
                  return null;
                },
                onChanged: (value) {
                  // No need to call setState here
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _isFormSubmitted =
                          true; // Trigger validation on button press
                    });
                    // Validate the form
                    if (!_formKey.currentState!.validate()) {
                      return; // If validation fails, do not proceed
                    }

                    final name = _nameController.text.trim();
                    final email = _emailController.text.trim();
                    final age = _ageController.text.trim();

                    await _updateProfile(context, name, email, age);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    Strings.updateProfile,
                    style: TextStyle(color: Colors.white, fontSize: 16),
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
