// lib/models/user_profile.dart

class UserData {
  final String userId;
  final String username;
  final String email;
  final String role;
  final String status;
  final String phoneNumber;
  final String? sid; // optional, if you ever need it

  // If you used age or other fields earlier, keep them nullable:
  final int? age; // optional, safe numeric

  UserData({
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    required this.status,
    required this.phoneNumber,
    this.sid,
    this.age,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      sid: json['sid']?.toString(),
      // if backend ever sends age, this is safe even when null/not num
      age: json['age'] is num ? (json['age'] as num).toInt() : null,
    );
  }
}
