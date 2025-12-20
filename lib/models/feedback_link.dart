// Create a new file: lib/models/feedback_link.dart

class FeedbackLink {
  final String uniqueId;
  final String link;
  final bool active;
  final int createdOn;
  final AuditLog? auditLog;

  FeedbackLink({
    required this.uniqueId,
    required this.link,
    required this.active,
    required this.createdOn,
    this.auditLog,
  });

  factory FeedbackLink.fromJson(Map<String, dynamic> json) {
    return FeedbackLink(
      uniqueId: json['unique_id'] ?? '',
      link: json['link'] ?? '',
      active: json['active'] ?? false,
      createdOn: json['created_on'] ?? 0,
      auditLog: json['audit_log'] != null
          ? AuditLog.fromJson(json['audit_log'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unique_id': uniqueId,
      'link': link,
      'active': active,
      'created_on': createdOn,
      'audit_log': auditLog?.toJson(),
    };
  }
}

class AuditLog {
  final String? createdBy;
  final String? createdId;
  final int? createdOn;
  final String? modifiedBy;
  final String? modifiedId;
  final int? modifiedOn;

  AuditLog({
    this.createdBy,
    this.createdId,
    this.createdOn,
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
