class Reason {
  final String reasonId;
  final String reason;
  final String siteId;
  final String status;
  final AuditLog? auditLog; // Nullable if not always present
  final String? category;

  Reason({
    required this.reasonId,
    required this.reason,
    required this.siteId,
    required this.status,
    this.auditLog,
    this.category,
  });

  factory Reason.fromJson(Map<String, dynamic> json) {
    return Reason(
      reasonId: json['reason_id'] as String,
      reason: json['reason'] as String,
      siteId: json['site_id'] as String,
      status: json['status'] as String,
      auditLog: json['audit_log'] != null
          ? AuditLog.fromJson(json['audit_log'])
          : null,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reason_id': reasonId,
      'reason': reason,
      'site_id': siteId,
      'status': status,
      if (auditLog != null) 'audit_log': auditLog!.toJson(),
      if (category != null) 'category': category,
    };
  }
}

class AuditLog {
  final String createdBy;
  final String createdId;
  final int createdOn;
  final String? modifiedBy;
  final String? modifiedId;
  final int? modifiedOn;

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
      createdBy: json['created_by'] as String,
      createdId: json['created_id'] as String,
      createdOn: json['created_on'] as int,
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
      if (modifiedBy != null) 'modified_by': modifiedBy,
      if (modifiedId != null) 'modified_id': modifiedId,
      if (modifiedOn != null) 'modified_on': modifiedOn,
    };
  }
}
