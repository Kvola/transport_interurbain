import 'dart:convert';
import 'package:http/http.dart' as http;

import 'storage_service.dart';
import '../models/trip.dart';
import '../models/booking.dart';

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
  
  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/transport/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );
    return _handleResponse(response);
  }
  
  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
    String? email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/transport/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'password': password,
        if (email != null) 'email': email,
      }),
    );
    return _handleResponse(response);
  }
  
  Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/transport/profile'),
      headers: headers,
    );
    return _handleResponse(response);
  }
  
  // ========== TRIPS ==========
  
  Future<List<Trip>> searchTrips({
    required int departureId,
    required int arrivalId,
    required String date,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/transport/trips/search'),
      headers: headers,
      body: jsonEncode({
        'departure_city_id': departureId,
        'arrival_city_id': arrivalId,
        'date': date,
      }),
    );
    final data = _handleResponse(response);
    final trips = data['trips'] as List? ?? [];
    return trips.map((t) => Trip.fromJson(t)).toList();
  }
  
  Future<List<Map<String, dynamic>>> getCities() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/transport/cities'),
      headers: headers,
    );
    final data = _handleResponse(response);
    return List<Map<String, dynamic>>.from(data['cities'] ?? []);
  }
  
  Future<Trip> getTripDetails(int tripId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/transport/trips/$tripId'),
      headers: headers,
    );
    final data = _handleResponse(response);
    return Trip.fromJson(data['trip']);
  }
  
  // ========== BOOKINGS ==========
  
  Future<Booking> createBooking({
    required int tripId,
    required List<String> seats,
    String ticketType = 'adult',
    bool isForOther = false,
    Map<String, dynamic>? passenger,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/transport/bookings/create'),
      headers: headers,
      body: jsonEncode({
        'trip_id': tripId,
        'seats': seats,
        'ticket_type': ticketType,
        'is_for_other': isForOther,
        if (passenger != null) 'passenger': passenger,
      }),
    );
    final data = _handleResponse(response);
    return Booking.fromJson(data['booking']);
  }
  
  Future<List<Booking>> getMyBookings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/transport/bookings'),
      headers: headers,
    );
    final data = _handleResponse(response);
    final bookings = data['bookings'] as List? ?? [];
    return bookings.map((b) => Booking.fromJson(b)).toList();
  }
  
  Future<Booking> getBookingDetails(int bookingId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/transport/bookings/$bookingId'),
      headers: headers,
    );
    final data = _handleResponse(response);
    return Booking.fromJson(data['booking']);
  }
  
  Future<Map<String, dynamic>> cancelBooking(int bookingId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/transport/bookings/$bookingId/cancel'),
      headers: headers,
    );
    return _handleResponse(response);
  }
  
  Future<Map<String, dynamic>> initiatePayment({
    required int bookingId,
    required String paymentMethod,
    required String phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/transport/payments/initiate'),
      headers: headers,
      body: jsonEncode({
        'booking_id': bookingId,
        'payment_method': paymentMethod,
        'phone': phone,
      }),
    );
    return _handleResponse(response);
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
