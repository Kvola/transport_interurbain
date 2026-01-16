import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/local_database.dart';
import '../services/connectivity_service.dart';
import '../config/api_config.dart';
import '../models/passenger.dart';

/// Provider pour l'authentification avec support offline
class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocalDatabase _database = LocalDatabase();
  final ConnectivityService _connectivity = ConnectivityService();
  
  Passenger? _passenger;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;
  bool _isOfflineMode = false;
  
  Passenger? get passenger => _passenger;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;
  bool get isOfflineMode => _isOfflineMode;
  
  /// Initialise le provider et la base de données locale
  Future<void> initialize() async {
    await _database.initialize();
    await _connectivity.initialize();
    
    // Écouter les changements de connexion
    _connectivity.addConnectionListener(_onConnectionChanged);
  }

  /// Appelé quand la connexion change
  void _onConnectionChanged(ConnectionStatus status) {
    _isOfflineMode = status != ConnectionStatus.online;
    notifyListeners();
    
    // Si on revient en ligne et qu'on a des données locales, vérifier le token
    if (status == ConnectionStatus.online && _passenger != null) {
      _refreshProfileFromServer();
    }
  }

  /// Rafraîchit le profil depuis le serveur
  Future<void> _refreshProfileFromServer() async {
    try {
      final response = await _apiService.get(ApiConfig.profileEndpoint);
      if (response.isSuccess && response.data != null) {
        _passenger = Passenger.fromJson(response.data['passenger']);
        await _database.saveUserData(response.data['passenger']);
        notifyListeners();
      }
    } catch (e) {
      // Ignorer les erreurs, on garde les données locales
    }
  }
  
  /// Vérifier si l'utilisateur est connecté (avec fallback offline)
  Future<bool> checkAuth() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Vérifier d'abord le token local
      String? token = await _apiService.getToken();
      if (token == null) {
        token = _database.getAuthToken();
      }
      
      if (token == null) {
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Si en ligne, vérifier le token avec le serveur
      if (_connectivity.isOnline) {
        final response = await _apiService.get(ApiConfig.profileEndpoint);
        
        if (response.isSuccess && response.data != null) {
          _passenger = Passenger.fromJson(response.data['passenger']);
          _isAuthenticated = true;
          
          // Sauvegarder localement
          await _database.saveUserData(response.data['passenger']);
          await _database.saveAuthToken(token);
          
          _isLoading = false;
          notifyListeners();
          return true;
        }
        
        // Token invalide
        await _apiService.clearToken();
        await _database.clearUserData();
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Mode offline : utiliser les données locales
      final userData = _database.getUserData();
      if (userData != null) {
        _passenger = Passenger.fromJson(userData);
        _isAuthenticated = true;
        _isOfflineMode = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      // En cas d'erreur réseau, essayer le mode offline
      final userData = _database.getUserData();
      if (userData != null) {
        _passenger = Passenger.fromJson(userData);
        _isAuthenticated = true;
        _isOfflineMode = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Inscription (nécessite une connexion)
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
    if (!_connectivity.isOnline) {
      _error = 'Connexion internet requise pour l\'inscription';
      notifyListeners();
      return false;
    }
    
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
        
        // Sauvegarder localement
        await _database.saveAuthToken(response.data['token']);
        await _database.saveUserData(response.data['passenger']);
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.message ?? 'Erreur lors de l\'inscription';
    } catch (e) {
      _error = 'Erreur: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }
  
  /// Connexion
  Future<bool> login({
    required String phone,
    required String pinCode,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    // Mode offline : vérifier si les données locales correspondent
    if (!_connectivity.isOnline) {
      final userData = _database.getUserData();
      if (userData != null && userData['phone'] == phone) {
        // Note: En production, vous devriez stocker le hash du PIN de manière sécurisée
        _passenger = Passenger.fromJson(userData);
        _isAuthenticated = true;
        _isOfflineMode = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = 'Connexion internet requise pour la première connexion';
      _isLoading = false;
      notifyListeners();
      return false;
    }
    
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
        _isOfflineMode = false;
        
        // Sauvegarder localement pour le mode offline
        await _database.saveAuthToken(response.data['token']);
        await _database.saveUserData(response.data['passenger']);
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.message ?? 'Erreur de connexion';
    } catch (e) {
      // Si erreur réseau et données locales disponibles
      final userData = _database.getUserData();
      if (userData != null && userData['phone'] == phone) {
        _passenger = Passenger.fromJson(userData);
        _isAuthenticated = true;
        _isOfflineMode = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = 'Erreur: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }
  
  /// Déconnexion
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    await _apiService.clearToken();
    await _database.clearUserData();
    
    _passenger = null;
    _isAuthenticated = false;
    _isOfflineMode = false;
    _isLoading = false;
    
    notifyListeners();
  }
  
  /// Mettre à jour le profil
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (!_connectivity.isOnline) {
      _error = 'Connexion internet requise pour modifier le profil';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.put(
        ApiConfig.profileEndpoint,
        body: data,
      );
      
      if (response.isSuccess && response.data != null) {
        _passenger = Passenger.fromJson(response.data['passenger']);
        await _database.saveUserData(response.data['passenger']);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.message;
    } catch (e) {
      _error = 'Erreur: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }
  
  /// Vérifier le code PIN
  Future<bool> verifyPin(String pinCode) async {
    if (!_connectivity.isOnline) {
      // En mode offline, on ne peut pas vérifier le PIN de manière sécurisée
      return true; // À adapter selon les besoins de sécurité
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _apiService.post(
        '${ApiConfig.profileEndpoint}/verify_pin',
        body: {'pin_code': pinCode},
      );
      
      _isLoading = false;
      notifyListeners();
      return response.isSuccess;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Changer le code PIN
  Future<bool> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    if (!_connectivity.isOnline) {
      _error = 'Connexion internet requise pour changer le code PIN';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post(
        '${ApiConfig.profileEndpoint}/change_pin',
        body: {
          'old_pin': oldPin,
          'new_pin': newPin,
        },
      );
      
      if (response.isSuccess) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.message ?? 'Erreur lors du changement de PIN';
    } catch (e) {
      _error = 'Erreur: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }
  
  /// Effacer l'erreur
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _connectivity.removeConnectionListener(_onConnectionChanged);
    super.dispose();
  }
}
