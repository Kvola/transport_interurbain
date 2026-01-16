import 'dart:convert';
import 'package:http/http.dart' as http;

import 'storage_service.dart';
import '../models/trip.dart';
import '../models/scan_result.dart';

class ApiService {
  final StorageService storageService;
  
  ApiService({required this.storageService});
  
  String get baseUrl => storageService.getApiUrl();
  
  Map<String, String> get headers {
    final token = storageService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  // ========== AUTH ==========
  
  Future<Map<String, dynamic>> login(String login, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/transport/agent/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login': login, 'password': password}),
    );
    return _handleResponse(response);
  }
  
  // ========== TRIPS ==========
  
  Future<List<Trip>> getTodayTrips() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/transport/agent/trips/today'),
      headers: headers,
    );
    final data = _handleResponse(response);
    final trips = data['trips'] as List? ?? [];
    return trips.map((t) => Trip.fromJson(t)).toList();
  }
  
  Future<Trip> getTripDetails(int tripId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/transport/agent/trips/$tripId'),
      headers: headers,
    );
    final data = _handleResponse(response);
    return Trip.fromJson(data['trip']);
  }
  
  Future<List<Passenger>> getTripPassengers(int tripId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/transport/agent/trips/$tripId/passengers'),
      headers: headers,
    );
    final data = _handleResponse(response);
    final passengers = data['passengers'] as List? ?? [];
    return passengers.map((p) => Passenger.fromJson(p)).toList();
  }
  
  // ========== SCANNING ==========
  
  Future<ScanResult> validateTicket(String qrCode, int tripId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/transport/agent/validate'),
      headers: headers,
      body: jsonEncode({
        'qr_code': qrCode,
        'trip_id': tripId,
      }),
    );
    final data = _handleResponse(response);
    return ScanResult.fromJson(data);
  }
  
  Future<ScanResult> checkInPassenger(int bookingId, int tripId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/transport/agent/checkin'),
      headers: headers,
      body: jsonEncode({
        'booking_id': bookingId,
        'trip_id': tripId,
      }),
    );
    final data = _handleResponse(response);
    return ScanResult.fromJson(data);
  }
  
  // ========== HELPERS ==========
  
  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['success'] == true || body['result'] != null) {
        return body['result'] ?? body;
      }
      throw ApiException(body['error']?['message'] ?? 'Erreur inconnue');
    }
    throw ApiException(
      body['error']?['message'] ?? 'Erreur serveur (${response.statusCode})',
    );
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  
  @override
  String toString() => message;
}
