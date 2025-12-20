class Category {
  final String categoryId;
  final String name;
  final String siteId;
  final String status;
  final AuditLog? auditLog; // Allow auditLog to be nullable
  final List<Antibiogram> antibiogramsData;

  Category({
    required this.categoryId,
    required this.name,
    required this.siteId,
    required this.status,
    this.auditLog, // Make this optional
    required this.antibiogramsData,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      categoryId:
          json['category_id'] as String? ?? '', // Default to empty string
      name: json['name'] as String? ?? '', // Default to empty string
      siteId: json['site_id'] as String? ?? '', // Default to empty string
      status: json['status'] as String? ?? '', // Default to empty string
      auditLog: json['audit_log'] != null
          ? AuditLog.fromJson(json['audit_log'])
          : null, // If null, allow auditLog to be null
      antibiogramsData: json['antibiograms_data'] != null
          ? (json['antibiograms_data'] as List)
              .map((data) => Antibiogram.fromJson(data))
              .toList()
          : [], // Default to empty list if null
    );
  }
}

class Antibiogram {
  final String antibiogramId;
  final String type;
  final String categoryId;
  final String categoryName;
  final String siteId;
  final String subCategory;
  final String xAxisId;
  final String xAxisName;
  final String yAxisId;
  final String yAxisName;
  final String newValue;
  final String oldValue;
  final String status;
  final AuditLog? auditLog; // Allow auditLog to be nullable

  Antibiogram({
    required this.antibiogramId,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.siteId,
    required this.subCategory,
    required this.xAxisId,
    required this.xAxisName,
    required this.yAxisId,
    required this.yAxisName,
    required this.newValue,
    required this.oldValue,
    required this.status,
    this.auditLog, // Make this optional
  });

  factory Antibiogram.fromJson(Map<String, dynamic> json) {
    return Antibiogram(
      antibiogramId:
          json['antibiogram_id'] as String? ?? '', // Default to empty string
      type: json['type'] as String? ?? '', // Default to empty string
      categoryId:
          json['category_id'] as String? ?? '', // Default to empty string
      categoryName:
          json['category_name'] as String? ?? '', // Default to empty string
      siteId: json['site_id'] as String? ?? '', // Default to empty string
      subCategory:
          json['sub_category'] as String? ?? '', // Default to empty string
      xAxisId: json['x_axis_id'] as String? ?? '', // Default to empty string
      xAxisName:
          json['x_axis_name'] as String? ?? '', // Default to empty string
      yAxisId: json['y_axis_id'] as String? ?? '', // Default to empty string
      yAxisName:
          json['y_axis_name'] as String? ?? '', // Default to empty string
      newValue: json['new_value'] as String? ?? '', // Default to empty string
      oldValue: json['old_value'] as String? ?? '', // Default to empty string
      status: json['status'] as String? ?? '', // Default to empty string
      auditLog: json['audit_log'] != null
          ? AuditLog.fromJson(json['audit_log'])
          : null, // If null, allow auditLog to be null
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'antibiogram_id': antibiogramId,
      'type': type,
      'category_id': categoryId,
      'category_name': categoryName,
      'site_id': siteId,
      'sub_category': subCategory,
      'x_axis_id': xAxisId,
      'x_axis_name': xAxisName,
      'y_axis_id': yAxisId,
      'y_axis_name': yAxisName,
      'new_value': newValue,
      'old_value': oldValue,
      'status': status,
      'audit_log':
          auditLog?.toJson(), // If auditLog is null, it won't be included
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
      createdBy: json['created_by'] as String? ?? '', // Default to empty string
      createdId: json['created_id'] as String? ?? '', // Default to empty string
      createdOn: json['created_on'] as int? ?? 0, // Default to 0 if null
      modifiedBy:
          json['modified_by'] as String? ?? '', // Default to empty string
      modifiedId:
          json['modified_id'] as String? ?? '', // Default to empty string
      modifiedOn: json['modified_on'] as int? ?? 0, // Default to 0 if null
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

  // Static method to return an empty AuditLog
  static AuditLog empty() {
    return AuditLog(
      createdBy: '',
      createdId: '',
      createdOn: 0,
      modifiedBy: '',
      modifiedId: '',
      modifiedOn: 0,
    );
  }
}
