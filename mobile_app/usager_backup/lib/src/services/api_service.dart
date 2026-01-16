import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';

/// Service pour les appels API
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  final _storage = const FlutterSecureStorage();
  
  String? _authToken;
  
  /// Obtenir le token stocké
  Future<String?> getToken() async {
    _authToken ??= await _storage.read(key: 'auth_token');
    return _authToken;
  }
  
  /// Sauvegarder le token
  Future<void> saveToken(String token) async {
    _authToken = token;
    await _storage.write(key: 'auth_token', value: token);
  }
  
  /// Supprimer le token
  Future<void> clearToken() async {
    _authToken = null;
    await _storage.delete(key: 'auth_token');
  }
  
  /// Headers avec authentification
  Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = Map<String, String>.from(ApiConfig.defaultHeaders);
    
    if (requireAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return headers;
  }
  
  /// Effectuer une requête POST JSON-RPC
  Future<ApiResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _getHeaders(requireAuth: requireAuth);
      
      // Odoo attend un format JSON-RPC
      final jsonRpcBody = {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': body ?? {},
        'id': DateTime.now().millisecondsSinceEpoch,
      };
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(jsonRpcBody),
      ).timeout(
        Duration(seconds: ApiConfig.connectionTimeout),
      );
      
      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('Pas de connexion internet');
    } on HttpException {
      return ApiResponse.error('Erreur de connexion au serveur');
    } catch (e) {
      return ApiResponse.error('Erreur: $e');
    }
  }
  
  /// Effectuer une requête GET
  Future<ApiResponse> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requireAuth = true,
  }) async {
    try {
      var url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      if (queryParams != null) {
        url = url.replace(queryParameters: queryParams);
      }
      
      final headers = await _getHeaders(requireAuth: requireAuth);
      
      // Pour GET, on utilise POST avec le format JSON-RPC
      final jsonRpcBody = {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': queryParams ?? {},
        'id': DateTime.now().millisecondsSinceEpoch,
      };
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(jsonRpcBody),
      ).timeout(
        Duration(seconds: ApiConfig.connectionTimeout),
      );
      
      return _handleResponse(response);
    } on SocketException {
      return ApiResponse.error('Pas de connexion internet');
    } on HttpException {
      return ApiResponse.error('Erreur de connexion au serveur');
    } catch (e) {
      return ApiResponse.error('Erreur: $e');
    }
  }
  
  /// Traiter la réponse HTTP
  ApiResponse _handleResponse(http.Response response) {
    try {
      final jsonResponse = jsonDecode(response.body);
      
      // Format JSON-RPC
      if (jsonResponse.containsKey('result')) {
        final result = jsonResponse['result'];
        
        if (result is Map) {
          return ApiResponse.fromJson(result as Map<String, dynamic>);
        }
        
        return ApiResponse(
          success: true,
          data: result,
          message: 'Success',
        );
      }
      
      if (jsonResponse.containsKey('error')) {
        final error = jsonResponse['error'];
        return ApiResponse.error(
          error['message'] ?? 'Erreur inconnue',
        );
      }
      
      // Réponse directe (pas JSON-RPC)
      return ApiResponse.fromJson(jsonResponse);
    } catch (e) {
      return ApiResponse.error('Erreur de parsing: $e');
    }
  }
}
