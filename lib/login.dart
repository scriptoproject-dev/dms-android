import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:qr_scanner_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/routes.dart';
import 'package:qr_scanner_app/styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  bool _obscureText = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  bool _isFormSubmitted = false;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  /// 🔐 If access token exists, skip login and go to home
  Future<void> _checkExistingSession() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token') ?? '';

    debugPrint('Existing access token: $accessToken');

    if (accessToken.isNotEmpty) {
      // Optionally you could validate/refresh token here.

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, Routes.home);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isSubmitting = true;
    });

    http.Client client = IOClient(
      HttpClient()..badCertificateCallback = (cert, host, port) => true,
    );

    try {
      final response = await client.post(
        Uri.parse('${Strings.baseUrl}auth/login'),
        headers: const {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      debugPrint('Login response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonBody =
            jsonDecode(response.body) as Map<String, dynamic>;

        if (!jsonBody.containsKey('data')) {
          showToastMessage(context, 'Invalid response: "data" missing');
          setState(() => _isSubmitting = false);
          return;
        }

        final Map<String, dynamic> data =
            jsonBody['data'] as Map<String, dynamic>;

        final accessToken = data['access_token'] as String? ?? '';
        final refreshToken = data['refresh_token'] as String? ?? '';
        final userId = data['user_id'] as String? ?? '';
        final username = data['username'] as String? ?? '';
        final role = data['role'] as String? ?? '';
        final emailResp = data['email'] as String? ?? '';
        final phone = data['phone_number'] as String? ?? '';
        final status = data['status'] as String? ?? '';

        if (accessToken.isEmpty) {
          showToastMessage(context, 'Login failed: no access token');
          setState(() => _isSubmitting = false);
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        await prefs.setString('refresh_token', refreshToken);
        await prefs.setString('user_id', userId);
        await prefs.setString('user_name', username);
        await prefs.setString('role', role);
        await prefs.setString('email', emailResp);
        await prefs.setString('phone_number', phone);
        await prefs.setString('status', status);

        debugPrint('Stored user: $username');

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, Routes.home);
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> jsonBody = jsonDecode(response.body);
        final message = jsonBody['detail'] ??
            'Authentication failed: Invalid email or password';
        showToastMessage(context, message.toString());
        setState(() => _isSubmitting = false);
      } else {
        debugPrint('Login failed: ${response.statusCode} ${response.body}');
        showToastMessage(
          context,
          'Login failed (${response.statusCode}). Please try again.',
        );
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      debugPrint('Error during login: $e');
      showToastMessage(
        context,
        'Error during login. Please try again later.',
      );
      setState(() => _isSubmitting = false);
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: _isFormSubmitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 100),
                const Center(
                  child: Text(
                    'DMS',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 90, // adjust as needed
                    fit: BoxFit.contain,
                  ),
                ),

                // const SizedBox(height: 120),

                const SizedBox(height: 80),

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: CustomStyles.textFieldDecoration.copyWith(
                    labelText: 'Email',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!v.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  decoration: CustomStyles.textFieldDecoration.copyWith(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility : Icons.visibility_off,
                        color: gray,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureText = !_obscureText;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 4) {
                      return 'Password must be at least 4 characters';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 32),

                // Login button
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _isFormSubmitted = true;
                          });
                          _login();
                        },
                  style: CustomStyles.elevatedButtonStyle,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
