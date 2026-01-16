import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  // Initialisation avec le token stocké
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(ApiConfig.tokenKey);
  }

  // Définir le token
  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConfig.tokenKey, token);
  }

  // Effacer le token
  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConfig.tokenKey);
    await prefs.remove(ApiConfig.userKey);
  }

  // Headers de la requête
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Requête POST générique
  Future<ApiResponse> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': body,
        }),
      ).timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        error: 'Erreur de connexion: ${e.toString()}',
      );
    }
  }

  // Requête GET générique
  Future<ApiResponse> get(String endpoint, [Map<String, String>? queryParams]) async {
    try {
      var uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http.get(
        uri,
        headers: _headers,
      ).timeout(ApiConfig.connectionTimeout);

      return _handleResponse(response);
    } catch (e) {
      return ApiResponse(
        success: false,
        error: 'Erreur de connexion: ${e.toString()}',
      );
    }
  }

  // Traitement de la réponse
  ApiResponse _handleResponse(http.Response response) {
    try {
      final jsonData = jsonDecode(response.body);
      
      // Format JSON-RPC
      if (jsonData['result'] != null) {
        final result = jsonData['result'];
        return ApiResponse(
          success: result['success'] ?? false,
          data: result['data'],
          error: result['error']?['message'],
          code: result['error']?['code'],
        );
      }
      
      // Erreur JSON-RPC
      if (jsonData['error'] != null) {
        return ApiResponse(
          success: false,
          error: jsonData['error']['data']?['message'] ?? 
                 jsonData['error']['message'] ?? 
                 'Erreur inconnue',
          code: jsonData['error']['code']?.toString(),
        );
      }

      return ApiResponse(
        success: false,
        error: 'Format de réponse invalide',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        error: 'Erreur de traitement: ${e.toString()}',
      );
    }
  }

  // Vérifier si authentifié
  bool get isAuthenticated => _token != null;

  // ============== MÉTHODES SPÉCIFIQUES ==============

  // Authentification
  Future<ApiResponse> login(String username, String password) async {
    return post(ApiConfig.authLogin, {
      'username': username,
      'password': password,
    });
  }

  // Profil
  Future<ApiResponse> getProfile() async {
    return post(ApiConfig.profile, {});
  }

  // Voyages du jour
  Future<ApiResponse> getTrips({String? date}) async {
    return post(ApiConfig.trips, {
      if (date != null) 'date': date,
    });
  }

  // Détails d'un voyage
  Future<ApiResponse> getTripDetails(int tripId) async {
    return post(ApiConfig.tripDetail(tripId), {});
  }

  // Liste des passagers d'un voyage
  Future<ApiResponse> getTripPassengers(int tripId) async {
    return post(ApiConfig.tripPassengers(tripId), {});
  }

  // Scanner un passager (via QR code unique)
  Future<ApiResponse> scanPassenger(int tripId, String qrCode) async {
    return post(ApiConfig.scanPassenger, {
      'trip_id': tripId,
      'qr_code': qrCode,
    });
  }

  // Scanner un ticket
  Future<ApiResponse> scanTicket(int tripId, String ticketQrCode) async {
    return post(ApiConfig.scanTicket, {
      'trip_id': tripId,
      'ticket_qr_code': ticketQrCode,
    });
  }

  // Embarquer un passager
  Future<ApiResponse> boardPassenger(int bookingId) async {
    return post(ApiConfig.boarding(bookingId), {});
  }

  // Embarquer plusieurs passagers
  Future<ApiResponse> boardPassengersBatch(List<int> bookingIds) async {
    return post(ApiConfig.boardingBatch, {
      'booking_ids': bookingIds,
    });
  }
}
