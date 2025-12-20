class BookmarkData {
  final String antibioticId;
  final String name;
  final String? parent;
  final String type;
  final String data;
  final List<dynamic>? children; // Nullable
  final List<String> ancestors;
  final String siteId;
  final String status;
  final bool bookmarked; // New field for bookmark status
  final AuditLog auditLog; // Reference to the AuditLog class

  BookmarkData({
    required this.antibioticId,
    required this.name,
    this.parent,
    required this.type,
    required this.data,
    this.children, // Nullable
    required this.ancestors,
    required this.siteId,
    required this.status,
    required this.bookmarked, // Initialize bookmarked
    required this.auditLog, // Initialize auditLog
  });

  factory BookmarkData.fromJson(Map<String, dynamic> json) {
    return BookmarkData(
      antibioticId: json['antibiotic_id'] as String,
      name: json['name'] as String,
      parent: json['parent'] as String?,
      type: json['type'] as String,
      data: json['data'] ?? '', // Handle potential null value for 'data'
      children: json['children'] as List<dynamic>?, // Handle nullable children
      ancestors: List<String>.from(json['ancestors']),
      siteId: json['site_id'] as String,
      status: json['status'] as String,
      bookmarked: json['bookmarked'] as bool? ?? true, // Map 'bookmarked' field
      auditLog: AuditLog.fromJson(json['audit_log']), // Map 'audit_log' field
    );
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
      modifiedBy: json['modified_by'] as String?,
      modifiedId: json['modified_id'] as String?,
      modifiedOn: json['modified_on'] as int?,
    );
  }
}
