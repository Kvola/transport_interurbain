import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../models/agent_models.dart';
import '../config/api_config.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  Agent? _agent;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;

  // Getters
  Agent? get agent => _agent;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;

  // Initialisation
  Future<bool> init() async {
    await _api.init();
    
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(ApiConfig.userKey);
    
    if (userData != null && _api.isAuthenticated) {
      try {
        _agent = Agent.fromJson(jsonDecode(userData));
        _isAuthenticated = true;
        notifyListeners();
        return true;
      } catch (e) {
        // Données corrompues
        await _api.clearToken();
      }
    }
    
    return false;
  }

  // Connexion
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.login(username, password);

      if (response.success && response.data != null) {
        // Sauvegarder le token
        if (response.data['token'] != null) {
          await _api.setToken(response.data['token']);
        }

        // Créer l'agent
        _agent = Agent.fromJson(response.data['user'] ?? response.data);
        
        // Sauvegarder localement
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          ApiConfig.userKey,
          jsonEncode(response.data['user'] ?? response.data),
        );

        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.error ?? 'Identifiants incorrects';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Erreur de connexion: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Déconnexion
  Future<void> logout() async {
    await _api.clearToken();
    _agent = null;
    _isAuthenticated = false;
    _error = null;
    notifyListeners();
  }

  // Rafraîchir le profil
  Future<void> refreshProfile() async {
    if (!_isAuthenticated) return;

    try {
      final response = await _api.getProfile();
      
      if (response.success && response.data != null) {
        _agent = Agent.fromJson(response.data);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ApiConfig.userKey, jsonEncode(response.data));
        
        notifyListeners();
      }
    } catch (e) {
      // Silencieux
    }
  }

  // Vider l'erreur
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
