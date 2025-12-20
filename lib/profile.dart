import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/user_profile.dart';
import 'package:qr_scanner_app/change_password.dart';
import 'package:qr_scanner_app/routes.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const ProfileScreen({super.key, this.onProfileUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserData? userData;
  bool isLoading = true;
  String? errorMessage;

  // Edit mode
  bool _isEditing = false;
  bool _isSaving = false;

  // Form
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _fetchUser();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchUser() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await ApiClient(baseUrl: Strings.baseUrl).get('users');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'] as Map<String, dynamic>;
        final user = UserData.fromJson(data);

        setState(() {
          userData = user;
          _usernameController.text = user.username;
          _emailController.text = user.email;
          _phoneController.text = user.phoneNumber ?? '';
          isLoading = false;
        });

        // notify parent if provided
        widget.onProfileUpdated?.call();
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load profile (${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading profile: $e';
      });
    }
  }

  String _roleLabel(String? code) {
    switch (code) {
      case 'ADM':
        return 'Admin';
      case 'EX':
        return 'Executive';
      case 'SC':
        return 'Scanner';
      default:
        return code ?? 'User';
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (userData == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final body = {
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'user_id': userData!.userId
      };

      final response =
          await ApiClient(baseUrl: Strings.baseUrl).put('users/', body: body);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final data = jsonResponse['data'] as Map<String, dynamic>;
        final updated = UserData.fromJson(data);

        setState(() {
          userData = updated;
          _isEditing = false;
          _isSaving = false;
          _usernameController.text = updated.username;
          _emailController.text = updated.email;
          _phoneController.text = updated.phoneNumber ?? '';
        });

        // update stored name (if you use it elsewhere)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_names', updated.username);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green),
        );

        widget.onProfileUpdated?.call();
      } else {
        String msg = 'Failed to update profile (${response.statusCode})';
        try {
          final m = json.decode(response.body);
          msg = m['message'] ?? m['detail'] ?? msg;
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red));
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red),
      );
      setState(() => _isSaving = false);
    }
  }

  void _openChangePassword() {
    if (userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User data not available')));
      return;
    }

    // Navigate to change password screen. Adjust param name if your ChangePasswordScreen expects different key.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangePasswordScreen(
          userId: userData!.userId,
          onPasswordUpdated: () {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Password updated successfully'),
                  backgroundColor: Colors.green),
            );
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_id');

      if (!mounted) return;
      // Replace route name with your login route constant
      Navigator.pushNamedAndRemoveUntil(
          context, Routes.login, (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  Widget _buildHeader() {
    final name = userData?.username ?? 'User';
    final role = _roleLabel(userData?.role);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.95),
            primaryColor.withOpacity(0.75)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
              color: primaryColor.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withOpacity(0.18),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Text(name,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999)),
            child: Text(role,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Account details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // USER ID (readonly)
          Row(children: [
            const Icon(Icons.fingerprint_outlined,
                size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('USER ID',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  Text(userData?.userId ?? 'N/A',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ]))
          ]),

          const SizedBox(height: 12),
          const Divider(),

          // Editable fields form rows
          _infoEditable(
              label: 'Username',
              icon: Icons.person_outline,
              controller: _usernameController,
              enabled: _isEditing,
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Please enter username';
                return null;
              }),
          const Divider(),
          _infoEditable(
              label: 'Email',
              icon: Icons.email_outlined,
              controller: _emailController,
              enabled: _isEditing,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) return 'Please enter email';
                if (!val.contains('@')) return 'Enter a valid email';
                return null;
              }),
          const Divider(),
          _infoEditable(
              label: 'Phone number',
              icon: Icons.phone_outlined,
              controller: _phoneController,
              enabled: _isEditing,
              keyboardType: TextInputType.phone,
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) return 'Please enter phone';
                if (val.length < 6) return 'Enter valid phone';
                return null;
              }),
          const Divider(),
          Row(children: [
            const Icon(Icons.work_outline, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('ROLE',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  Text(_roleLabel(userData?.role),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ]))
          ]),
        ],
      ),
    );
  }

  Widget _infoEditable({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool enabled,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 6),
            TextFormField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              validator: validator,
              decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            )
          ]),
        )
      ]),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Security',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openChangePassword,
            icon: const Icon(Icons.lock_reset_outlined, color: Colors.white),
            label: const Text(
              'Change password',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, userData);
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: primaryColor,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context, userData)),
          title: const Text('Profile', style: TextStyle(color: Colors.white)),
          actions: [
            // Edit / Cancel toggle
            if (userData != null)
              TextButton(
                onPressed: _isSaving
                    ? null
                    : () {
                        setState(() {
                          if (_isEditing) {
                            // Cancel — reset fields
                            _usernameController.text = userData!.username;
                            _emailController.text = userData!.email;
                            _phoneController.text = userData!.phoneNumber ?? '';
                            _isEditing = false;
                          } else {
                            _isEditing = true;
                          }
                        });
                      },
                child: Text(_isEditing ? 'Cancel' : 'Edit',
                    style: const TextStyle(color: Colors.white)),
              ),

            // Logout
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Logout',
            )
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(errorMessage!,
                            style: const TextStyle(color: Colors.red))))
                : userData == null
                    ? const Center(child: Text('No user data available'))
                    : SafeArea(
                        child: Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildHeader(),
                                  const SizedBox(height: 16),
                                  _buildAccountCard(),
                                  const SizedBox(height: 16),
                                  _buildSecurityCard(),
                                  const SizedBox(height: 28),
                                ]),
                          ),
                        ),
                      ),
        // Save button appears when editing
        bottomNavigationBar: _isEditing
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999))),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save changes',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
