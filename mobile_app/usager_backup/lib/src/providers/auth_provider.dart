import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/passenger.dart';

/// Provider pour l'authentification
class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  Passenger? _passenger;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  
  Passenger? get passenger => _passenger;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  
  /// Vérifier si l'utilisateur est connecté
  Future<bool> checkAuth() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final token = await _apiService.getToken();
      
      if (token == null) {
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Vérifier le token en récupérant le profil
      final response = await _apiService.get(ApiConfig.profileEndpoint);
      
      if (response.isSuccess && response.data != null) {
        _passenger = Passenger.fromJson(response.data['passenger']);
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      // Token invalide, le supprimer
      await _apiService.clearToken();
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Inscription
  Future<bool> register({
    required String name,
    required String phone,
    required String pinCode,
    String? email,
    String? idType,
    String? idNumber,
    String? dateOfBirth,
    String? gender,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post(
        ApiConfig.registerEndpoint,
        body: {
          'name': name,
          'phone': phone,
          'pin_code': pinCode,
          if (email != null) 'email': email,
          if (idType != null) 'id_type': idType,
          if (idNumber != null) 'id_number': idNumber,
          if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
          if (gender != null) 'gender': gender,
        },
        requireAuth: false,
      );
      
      if (response.isSuccess && response.data != null) {
        await _apiService.saveToken(response.data['token']);
        _passenger = Passenger.fromJson(response.data['passenger']);
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erreur lors de l\'inscription: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Connexion
  Future<bool> login(String phone, String pinCode) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post(
        ApiConfig.loginEndpoint,
        body: {
          'phone': phone,
          'pin_code': pinCode,
        },
        requireAuth: false,
      );
      
      if (response.isSuccess && response.data != null) {
        await _apiService.saveToken(response.data['token']);
        _passenger = Passenger.fromJson(response.data['passenger']);
        _isAuthenticated = true;
        
        // Sauvegarder le téléphone pour la prochaine connexion
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_phone', phone);
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erreur de connexion: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Déconnexion
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _apiService.post(ApiConfig.logoutEndpoint);
    } catch (e) {
      // Ignorer les erreurs de déconnexion
    }
    
    await _apiService.clearToken();
    _passenger = null;
    _isAuthenticated = false;
    _isLoading = false;
    notifyListeners();
  }
  
  /// Rafraîchir le profil
  Future<void> refreshProfile() async {
    try {
      final response = await _apiService.get(ApiConfig.profileEndpoint);
      
      if (response.isSuccess && response.data != null) {
        _passenger = Passenger.fromJson(response.data['passenger']);
        notifyListeners();
      }
    } catch (e) {
      // Ignorer
    }
  }
  
  /// Mettre à jour le profil
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post(
        ApiConfig.profileEndpoint,
        body: updates,
      );
      
      if (response.isSuccess && response.data != null) {
        _passenger = Passenger.fromJson(response.data['passenger']);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erreur de mise à jour: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Changer le code PIN
  Future<bool> changePin(String currentPin, String newPin) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post(
        ApiConfig.changePinEndpoint,
        body: {
          'current_pin': currentPin,
          'new_pin': newPin,
        },
      );
      
      _isLoading = false;
      
      if (response.isSuccess) {
        notifyListeners();
        return true;
      }
      
      _error = response.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erreur: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Obtenir le QR code unique
  Future<Map<String, dynamic>?> getQrCode() async {
    try {
      final response = await _apiService.get(ApiConfig.qrCodeEndpoint);
      
      if (response.isSuccess && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Effacer l'erreur
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
