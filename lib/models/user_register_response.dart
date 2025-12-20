class UserRegisterResponse {
  final String userId;
  final String name;
  final String siteId;
  final String? siteName;
  final String? photoId;
  final String email;
  final String phoneNumber;
  final String designation;
  final String departmentId;
  final String? departmentName;
  final String? age;
  final String? gender;
  final String status;
  final String passcode;
  final String role;
  final dynamic keycloakId;
  final double receivedOn;
  final dynamic processedOn;
  final dynamic bookmarkedIds;
  final AuditLog auditLog;

  UserRegisterResponse({
    required this.userId,
    required this.name,
    required this.siteId,
    this.siteName,
    this.photoId,
    required this.email,
    required this.phoneNumber,
    required this.designation,
    required this.departmentId,
    this.departmentName,
    this.age,
    this.gender,
    required this.status,
    required this.passcode,
    required this.role,
    this.keycloakId,
    required this.receivedOn,
    this.processedOn,
    this.bookmarkedIds,
    required this.auditLog,
  });

  factory UserRegisterResponse.fromJson(Map<String, dynamic> json) {
    return UserRegisterResponse(
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      siteId: json['site_id'] ?? '',
      siteName: json['site_name'], // Nullable
      photoId: json['photo_id'], // Nullable
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      designation: json['designation'] ?? '',
      departmentId: json['department_id'] ?? '',
      departmentName: json['department_name'], // Nullable
      age: json['age'], // Nullable
      gender: json['gender'], // Nullable
      status: json['status'] ?? '',
      passcode: json['passcode'] ?? '',
      role: json['role'] ?? '',
      keycloakId: json['keycloak_id'],
      receivedOn: (json['recieved_on'] is num)
          ? (json['recieved_on'] as num).toDouble()
          : 0.0,
      processedOn: json['processed_on'],
      bookmarkedIds: json['bookmarked_ids'],
      auditLog: AuditLog.fromJson(json['audit_log']),
    );
  }
}

class AuditLog {
  final String createdBy;
  final String createdId;
  final double createdOn;
  final String? modifiedBy;
  final String? modifiedId;
  final double? modifiedOn;

  AuditLog({
    required this.createdBy,
    required this.createdId,
    required this.createdOn,
    this.modifiedBy,
    this.modifiedId,
    this.modifiedOn,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      createdBy: json['created_by'] ?? '',
      createdId: json['created_id'] ?? '',
      createdOn: (json['created_on'] is num)
          ? (json['created_on'] as num).toDouble()
          : 0.0,
      modifiedBy: json['modified_by'],
      modifiedId: json['modified_id'],
      modifiedOn: (json['modified_on'] != null && json['modified_on'] is num)
          ? (json['modified_on'] as num).toDouble()
          : null,
    );
  }
}
