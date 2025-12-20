import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String userId; // you passed username from ProfileScreen
  final VoidCallback? onPasswordUpdated;

  const ChangePasswordScreen({
    super.key,
    required this.userId,
    this.onPasswordUpdated,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    // final currentPassword = _currentCtrl.text.trim();
    final newPassword = _newCtrl.text.trim();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final baseUrl = Strings.baseUrl;

      // ⚠️ Adjust endpoint + body keys to match your backend
      final body = {
        'user_id': widget.userId,
        // 'old_password': currentPassword,
        'new_password': newPassword,
      };

      final response = await ApiClient(baseUrl: baseUrl)
          .put('users/change_password', body: body);

      if (response.statusCode == 200) {
        String msg = 'Password changed successfully.';
        try {
          final jsonBody = json.decode(response.body);
          msg = jsonBody['message'] ?? msg;
        } catch (_) {}

        _showSnack(msg);
        widget.onPasswordUpdated?.call();

        if (mounted) Navigator.pop(context);
      } else {
        String msg = 'Failed to change password (${response.statusCode})';
        try {
          final jsonBody = json.decode(response.body);
          msg = jsonBody['detail'] ?? jsonBody['message'] ?? msg;
        } catch (_) {}
        _showSnack(msg);
      }
    } catch (e) {
      _showSnack('Error changing password: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          Strings.changePasswordTitle,
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF4F5F7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildPasswordField(
                label: 'Current password',
                controller: _currentCtrl,
                obscure: _obscureCurrent,
                onToggle: () {
                  setState(() => _obscureCurrent = !_obscureCurrent);
                },
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                label: 'New password',
                controller: _newCtrl,
                obscure: _obscureNew,
                onToggle: () {
                  setState(() => _obscureNew = !_obscureNew);
                },
                extraValidator: (v) {
                  if (v != null && v.length < 6) {
                    return 'New password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                label: 'Confirm new password',
                controller: _confirmCtrl,
                obscure: _obscureConfirm,
                onToggle: () {
                  setState(() => _obscureConfirm = !_obscureConfirm);
                },
                extraValidator: (v) {
                  if (v != _newCtrl.text.trim()) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleChangePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Update password',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? extraValidator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) {
          return 'Please enter $label';
        }
        if (extraValidator != null) {
          return extraValidator(v);
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }
}
