class Department {
  final String departmentId;
  final String name;
  final String status;
  final AuditLog auditLog;

  Department({
    required this.departmentId,
    required this.name,
    required this.status,
    required this.auditLog,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      departmentId: json['department_id'],
      name: json['name'],
      status: json['status'],
      auditLog: AuditLog.fromJson(json['audit_log']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'department_id': departmentId,
      'name': name,
      'status': status,
      'audit_log': auditLog.toJson(),
    };
  }
}

class AuditLog {
  final String createdBy;
  final String createdId;
  final int createdOn;

  AuditLog({
    required this.createdBy,
    required this.createdId,
    required this.createdOn,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      createdBy: json['created_by'],
      createdId: json['created_id'],
      createdOn: json['created_on'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'created_by': createdBy,
      'created_id': createdId,
      'created_on': createdOn,
    };
  }
}
