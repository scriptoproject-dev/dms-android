class ChatResponse {
  final int status;
  final String message;
  final int total;
  final List<ChatData> data;

  ChatResponse({
    required this.status,
    required this.message,
    required this.total,
    required this.data,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      status: json['status'],
      message: json['message'],
      total: json['total'],
      data: List<ChatData>.from(
        json['data'].map((x) => ChatData.fromJson(x)),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'total': total,
      'data': data.map((x) => x.toJson()).toList(),
    };
  }
}

class ChatData {
  final String? categoryId;
  final String? antibioticId;
  final String name;
  final String? parent;
  final String type;
  final String? data;
  final List<String>? children;
  final List<String>? ancestors;
  final String siteId;
  final String status;
  final bool? bookmarked;
  final AuditLog auditLog;

  ChatData({
    this.categoryId,
    this.antibioticId,
    required this.name,
    this.parent,
    required this.type,
    this.data,
    this.children,
    this.ancestors,
    required this.siteId,
    required this.status,
    this.bookmarked,
    required this.auditLog,
  });

  factory ChatData.fromJson(Map<String, dynamic> json) {
    return ChatData(
      categoryId: json['category_id'],
      antibioticId: json['antibiotic_id'],
      name: json['name'] ?? '', // Default to empty string if null
      parent: json['parent'],
      type: json['type'] ?? '', // Default to empty string if null
      data: json['data'],
      children:
          json['children'] != null ? List<String>.from(json['children']) : [],
      ancestors:
          json['ancestors'] != null ? List<String>.from(json['ancestors']) : [],
      siteId: json['site_id'] ?? '', // Default to empty string if null
      status: json['status'] ?? '', // Default to empty string if null
      bookmarked: json['bookmarked'] ?? false, // Default to false if null
      auditLog: json['audit_log'] != null
          ? AuditLog.fromJson(json['audit_log'])
          : AuditLog(
              createdBy: 'Unknown', // Default value
              createdId: 'Unknown', // Default value
              createdOn: 0, // Default value
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'antibiotic_id': antibioticId,
      'name': name,
      'parent': parent,
      'type': type,
      'data': data,
      'children': children,
      'ancestors': ancestors,
      'site_id': siteId,
      'status': status,
      'bookmarked': bookmarked,
      'audit_log': auditLog.toJson(),
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
      createdBy: json['created_by'] ?? 'Unknown', // Default value if null
      createdId: json['created_id'] ?? 'Unknown', // Default value if null
      createdOn: json['created_on'] ?? 0, // Default value if null
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
