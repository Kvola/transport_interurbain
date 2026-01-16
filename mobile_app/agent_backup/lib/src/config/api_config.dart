class ApiConfig {
  // Configuration de l'API
  static const String baseUrl = 'http://localhost:8069';
  static const String apiVersion = 'v1';
  static const String apiBasePath = '/api/$apiVersion/transport/agent';
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Endpoints
  static const String authLogin = '$apiBasePath/auth/login';
  static const String authLogout = '$apiBasePath/auth/logout';
  static const String profile = '$apiBasePath/profile';
  static const String trips = '$apiBasePath/trips';
  static String tripDetail(int id) => '$apiBasePath/trips/$id';
  static String tripPassengers(int id) => '$apiBasePath/trips/$id/passengers';
  static const String scanPassenger = '$apiBasePath/scan/passenger';
  static const String scanTicket = '$apiBasePath/scan/ticket';
  static String boarding(int bookingId) => '$apiBasePath/boarding/$bookingId';
  static const String boardingBatch = '$apiBasePath/boarding/batch';
  
  // Paramètres de l'app
  static const String appName = 'Transport Agent';
  static const String appVersion = '1.0.0';
  
  // Stockage local
  static const String tokenKey = 'agent_token';
  static const String userKey = 'agent_user';
}
