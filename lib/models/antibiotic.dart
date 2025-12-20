class Antibiotic {
  final String antibioticId;
  final String name;
  final String parent;
  final String? type;
  final String? data;
  final String? awareClassification;
  final String? causativeOrganism;
  final int? index;
  final List<String>? children;
  final List<String> ancestors;
  final String siteId;
  final String status;
  final AuditLog? auditLog;
  // final bool bookmarked; // New field
  // final String connection; // New field

  Antibiotic({
    required this.antibioticId,
    required this.name,
    required this.parent,
    this.type,
    this.data,
    this.awareClassification,
    this.causativeOrganism,
    this.index,
    this.children,
    required this.ancestors,
    required this.siteId,
    required this.status,
    this.auditLog,
    // this.bookmarked = false, // Default to false
    // this.connection = 'offline', // Default to offline
  });

  factory Antibiotic.fromJson(Map<String, dynamic> json) {
    return Antibiotic(
      antibioticId:
          json['antibiotic_id'] ?? '', // Fallback to empty string if null
      name: json['name'] ?? '',
      parent: json['parent'] ?? '',
      type: json['type'] as String?,
      data: json['data'] as String?,
      awareClassification: json['aware_classification'] as String?,
      causativeOrganism: json['causative_organism'] as String?,
      index: json['index'] as int?,
      children:
          json['children'] != null ? List<String>.from(json['children']) : null,
      ancestors: (json['ancestors'] as List<dynamic>?)
              ?.map((ancestor) => ancestor as String)
              .toList() ??
          [],
      siteId: json['site_id'] ?? '',
      status: json['status'] ?? '',
      auditLog: json['audit_log'] != null
          ? AuditLog.fromJson(json['audit_log'] as Map<String, dynamic>)
          : null,
      // bookmarked: false, // Set default value
      // connection: 'offline', // Set default value
    );
  }

  Map<String, dynamic> toJson() {
    final jsonMap = {
      'antibiotic_id': antibioticId,
      'name': name,
      'parent': parent,
      'type': type,
      'data': data,
      'aware_classification': awareClassification,
      'causative_organism': causativeOrganism,
      'index': index,
      'children': children,
      'ancestors': ancestors,
      'site_id': siteId,
      'status': status,
      'audit_log': auditLog?.toJson()
    };

    return jsonMap;
  }

  Antibiotic copyWith({
    String? antibioticId,
    String? name,
    String? parent,
    String? type,
    String? data,
    String? awareClassification,
    String? causativeOrganism,
    int? index,
    List<String>? children, // Change this to List<String>?
    List<String>? ancestors, // Change this to List<String>?
    String? siteId,
    String? status,
    AuditLog? auditLog, // Change this to AuditLog?
    bool? bookmarked,
    String? connection,
  }) {
    return Antibiotic(
      antibioticId: antibioticId ?? this.antibioticId,
      name: name ?? this.name,
      parent: parent ?? this.parent,
      type: type ?? this.type,
      data: data ?? this.data,
      awareClassification: awareClassification ?? this.awareClassification,
      causativeOrganism: causativeOrganism ?? this.causativeOrganism,
      index: index ?? this.index,
      children: children ?? this.children, // Correctly assign List<String>?
      ancestors: ancestors ?? this.ancestors, // Correctly assign List<String>?
      siteId: siteId ?? this.siteId,
      status: status ?? this.status,
      auditLog: auditLog ?? this.auditLog, // Correctly assign AuditLog?
      // bookmarked: bookmarked ?? this.bookmarked,
      // connection: connection ?? this.connection,
    );
  }

  @override
  String toString() {
    return 'Antibiotic(antibioticId: $antibioticId, name: $name, parent: $parent, '
        'type: $type, data: $data, awareClassification: $awareClassification, '
        'causativeOrganism: $causativeOrganism, index: $index, children: $children, ancestors: $ancestors, '
        'siteId: $siteId, status: $status, auditLog: ${auditLog?.toString()})';
  }
}

class AuditLog {
  final String createdBy;
  final String createdId;
  final int createdOn;
  final String? modifiedBy; // Can be null
  final String? modifiedId; // Can be null
  final int? modifiedOn; // Can be null

  AuditLog({
    required this.createdBy,
    required this.createdId,
    required this.createdOn,
    this.modifiedBy,
    this.modifiedId,
    this.modifiedOn,
  });

  // Convert from JSON
  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      createdBy: json['created_by'] ?? '',
      createdId: json['created_id'] ?? '',
      createdOn: json['created_on'] ?? 0,
      modifiedBy: json['modified_by'] as String?,
      modifiedId: json['modified_id'] as String?,
      modifiedOn:
          json['modified_on'] != null ? json['modified_on'] as int : null,
    );
  }

  // Convert to JSON
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

  @override
  String toString() {
    return 'AuditLog(createdBy: $createdBy, createdId: $createdId, '
        'createdOn: $createdOn, modifiedBy: $modifiedBy, modifiedId: $modifiedId, '
        'modifiedOn: $modifiedOn)';
  }
}
