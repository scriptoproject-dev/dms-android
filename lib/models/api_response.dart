class ApiResponse<T> {
  final int status;
  final String message;
  final T data;
  final int? total; // Optional
  final double? version; // Optional

  ApiResponse({
    required this.status,
    required this.message,
    required this.data,
    this.total,
    this.version,
  });

  factory ApiResponse.fromJson(
      Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
    return ApiResponse(
      status: json['status'],
      message: json['message'],
      data: fromJsonT(json['data']),
      total: json['total'], // Null if not present
      version: (json['version'] != null)
          ? (json['version'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) {
    return {
      'status': status,
      'message': message,
      'data': toJsonT(data),
      if (total != null) 'total': total, // Only include if not null
      if (version != null) 'version': version, // Only include if not null
    };
  }
}
