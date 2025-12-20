class SiteData {
  String siteId;
  String name;
  String address;
  List<String>? departments;
  String status;
  AuditLog auditLog;

  SiteData({
    required this.siteId,
    required this.name,
    required this.address,
    this.departments,
    required this.status,
    required this.auditLog,
  });

  factory SiteData.fromJson(Map<String, dynamic> json) {
    return SiteData(
      siteId: json['site_id'],
      name: json['name'],
      address: json['address'],
      departments: json['department_ids'] != null // Check if it's not null
          ? List<String>.from(json['department_ids'])
          : null, // Correct the key here
      status: json['status'],
      auditLog: AuditLog.fromJson(json['audit_log']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'site_id': siteId,
      'name': name,
      'address': address,
      'department_ids':
          departments, // If it's null, it will be null in the JSON
      'status': status,
      'audit_log': auditLog.toJson(),
    };
  }
}

class AuditLog {
  String createdBy;
  String createdId;
  int createdOn;
  String? modifiedBy;
  String? modifiedId;
  int? modifiedOn;

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
      createdBy: json['created_by'],
      createdId: json['created_id'],
      createdOn: json['created_on'],
      modifiedBy: json['modified_by'],
      modifiedId: json['modified_id'],
      modifiedOn: json['modified_on'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'created_by': createdBy,
      'created_id': createdId,
      'created_on': createdOn,
      'modified_by': modifiedBy,
      'modified_id': modifiedId,
      'modified_on': modifiedOn,
    };
  }
}
