class ErrorResponse {
  final String errorMessage;

  ErrorResponse({required this.errorMessage});

  // Factory method to create an ErrorResponse from the JSON response
  factory ErrorResponse.fromJson(Map<String, dynamic> json) {
    if (json['detail'] is List && json['detail'].isNotEmpty) {
      var error = json['detail'][0];
      // Extract the error message from the 'msg' field
      return ErrorResponse(errorMessage: error['msg'] ?? 'Unknown error');
    } else if (json['detail'] is String) {
      // If 'detail' is a string, return it directly as the error message
      return ErrorResponse(errorMessage: json['detail'] ?? 'Unknown error');
    }
    return ErrorResponse(errorMessage: 'An unknown error occurred.');
  }
}
