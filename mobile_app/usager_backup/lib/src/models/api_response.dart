/// Réponse standardisée de l'API
class ApiResponse {
  final bool success;
  final int? code;
  final String message;
  final dynamic data;
  final Map<String, dynamic>? details;
  
  ApiResponse({
    required this.success,
    this.code,
    required this.message,
    this.data,
    this.details,
  });
  
  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] ?? false,
      code: json['code'],
      message: json['message'] ?? '',
      data: json['data'],
      details: json['details'],
    );
  }
  
  factory ApiResponse.error(String message, {int? code, Map<String, dynamic>? details}) {
    return ApiResponse(
      success: false,
      code: code,
      message: message,
      details: details,
    );
  }
  
  bool get isSuccess => success;
  bool get isError => !success;
  
  T? getData<T>() {
    if (data == null) return null;
    return data as T;
  }
}
