class ApiResponse {
  final bool success;
  final dynamic data;
  final String? error;
  final String? code;

  ApiResponse({
    required this.success,
    this.data,
    this.error,
    this.code,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] ?? false,
      data: json['data'],
      error: json['error']?['message'],
      code: json['error']?['code'],
    );
  }
}
