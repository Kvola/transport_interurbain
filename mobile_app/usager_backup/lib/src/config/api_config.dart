/// Configuration de l'API
class ApiConfig {
  // URL de base de l'API - À modifier selon l'environnement
  static const String baseUrl = 'http://localhost:8069';
  
  // Version de l'API
  static const String apiVersion = 'v1';
  
  // Préfixe des endpoints
  static const String apiPrefix = '/api/$apiVersion/transport/usager';
  
  // Timeout des requêtes (en secondes)
  static const int connectionTimeout = 30;
  static const int receiveTimeout = 30;
  
  // Headers par défaut
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // Endpoints d'authentification
  static const String loginEndpoint = '$apiPrefix/auth/login';
  static const String registerEndpoint = '$apiPrefix/auth/register';
  static const String logoutEndpoint = '$apiPrefix/auth/logout';
  static const String refreshTokenEndpoint = '$apiPrefix/auth/refresh';
  
  // Endpoints de profil
  static const String profileEndpoint = '$apiPrefix/profile';
  static const String changePinEndpoint = '$apiPrefix/profile/change-pin';
  static const String qrCodeEndpoint = '$apiPrefix/qrcode';
  
  // Endpoints de données
  static const String citiesEndpoint = '$apiPrefix/cities';
  static const String companiesEndpoint = '$apiPrefix/companies';
  
  // Endpoints de voyages
  static const String searchTripsEndpoint = '$apiPrefix/trips/search';
  static String tripDetailEndpoint(int tripId) => '$apiPrefix/trips/$tripId';
  
  // Endpoints de réservations
  static const String bookingsEndpoint = '$apiPrefix/bookings';
  static String bookingDetailEndpoint(int bookingId) => '$apiPrefix/bookings/$bookingId';
  static String payBookingEndpoint(int bookingId) => '$apiPrefix/bookings/$bookingId/pay';
  static String ticketEndpoint(int bookingId) => '$apiPrefix/bookings/$bookingId/ticket';
  static String receiptEndpoint(int bookingId) => '$apiPrefix/bookings/$bookingId/receipt';
  static String cancelBookingEndpoint(int bookingId) => '$apiPrefix/bookings/$bookingId/cancel';
  static String shareBookingEndpoint(int bookingId) => '$apiPrefix/bookings/$bookingId/share';
  
  // Endpoint de connectivité
  static const String pingEndpoint = '/api/$apiVersion/transport/ping';
}
