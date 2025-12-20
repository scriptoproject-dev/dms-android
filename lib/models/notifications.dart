class NotificationsResponse {
  final int status;
  final String message;
  final int total;
  final List<NotificationData> data;

  NotificationsResponse({
    required this.status,
    required this.message,
    required this.total,
    required this.data,
  });

  factory NotificationsResponse.fromJson(Map<String, dynamic> json) {
    return NotificationsResponse(
      status: json['status'] ?? 0, // Provide default value in case of null
      message: json['message'] ?? '',
      total: json['total'] ?? 0, // Provide default value in case of null
      data: (json['data'] as List)
          .map((item) => NotificationData.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'total': total,
      'data': data.map((item) => item.toJson()).toList(),
    };
  }
}

class NotificationData {
  String uniqueId;
  String notificationId;
  String userId;
  String title;
  String type;
  DateTime? scheduleTime; // Nullable field for DateTime
  bool viewed;
  bool received;
  String status;
  Content content;
  AuditLog auditLog;

  NotificationData({
    required this.uniqueId,
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.type,
    this.scheduleTime, // Nullable DateTime
    required this.viewed,
    required this.received,
    required this.status,
    required this.content,
    required this.auditLog,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      uniqueId: json['unique_id'] ?? '',
      notificationId: json['notification_id'] ?? '',
      userId: json['user_id'] ?? '',
      title: json['title'] ?? 'No Title', // Provide a default value for title
      type: json['type'] ?? '',
      scheduleTime: json['schedule_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              _parseInt(json['schedule_time'])! * 1000)
          : null,
      viewed: json['viewed'] ?? false, // Default to false if not provided
      received: json['received'] ?? false,
      status: json['status'] ?? 'inactive', // Provide default status
      content: Content.fromJson(json['content'] ?? {}),
      auditLog: AuditLog.fromJson(json['audit_log'] ?? {}),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return 0; // Return 0 if value is null
    }
    if (value is int) {
      return value;
    } else if (value is double) {
      return value.toInt(); // Convert double to int
    }
    return 0; // Default to 0 if the value is not a number
  }

  Map<String, dynamic> toJson() {
    return {
      'unique_id': uniqueId,
      'notification_id': notificationId,
      'user_id': userId,
      'title': title,
      'type': type,
      'schedule_time': scheduleTime?.toIso8601String(),
      'viewed': viewed,
      'received': received,
      'status': status,
      'content': content.toJson(),
      'audit_log': auditLog.toJson(),
    };
  }
}

class Content {
  String contentId;
  String comment;

  Content({required this.contentId, required this.comment});

  factory Content.fromJson(Map<String, dynamic> json) {
    return Content(
      contentId: json['content_id'] ?? '', // Provide default empty string
      comment: json['comment'] ?? '', // Provide default empty string
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content_id': contentId,
      'comment': comment,
    };
  }
}

class AuditLog {
  String createdBy;
  String createdId;
  int? createdOn; // Nullable field for createdOn
  String? modifiedBy; // Nullable field for modifiedBy
  String? modifiedId; // Nullable field for modifiedId
  int? modifiedOn; // Nullable field for modifiedOn

  AuditLog({
    required this.createdBy,
    required this.createdId,
    this.createdOn, // Nullable field
    this.modifiedBy, // Nullable field
    this.modifiedId, // Nullable field
    this.modifiedOn, // Nullable field
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      createdBy: json['created_by'] ?? '', // Provide a default value
      createdId: json['created_id'] ?? '', // Provide a default value
      createdOn: _parseInt(json['created_on']), // Handle both int and double
      modifiedBy: json['modified_by'], // Nullable field
      modifiedId: json['modified_id'], // Nullable field
      modifiedOn: _parseInt(json['modified_on']), // Handle both int and double
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

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return 0; // Return 0 if value is null
    }
    if (value is int) {
      return value;
    } else if (value is double) {
      return value.toInt(); // Convert double to int
    }
    return 0; // Default to 0 if the value is not a number
  }
}
