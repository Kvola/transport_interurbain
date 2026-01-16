import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/local_database.dart';
import '../services/connectivity_service.dart';
import '../models/agent_models.dart';
import '../config/api_config.dart';

/// Provider pour l'authentification agent avec support offline
class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final LocalDatabase _database = LocalDatabase();
  final ConnectivityService _connectivity = ConnectivityService();
  
  Agent? _agent;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _error;
  bool _isOfflineMode = false;

  // Getters
  Agent? get agent => _agent;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;
  bool get isOfflineMode => _isOfflineMode;

  /// Initialisation avec base locale
  Future<bool> init() async {
    await _database.initialize();
    await _connectivity.initialize();
    await _api.init();
    
    // Écouter les changements de connexion
    _connectivity.addConnectionListener(_onConnectionChanged);
    
    // Charger depuis les données locales
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(ApiConfig.userKey);
    
    // Vérifier aussi le token local
    final localToken = _database.getAuthToken();
    
    if (userData != null && (_api.isAuthenticated || localToken != null)) {
      try {
        _agent = Agent.fromJson(jsonDecode(userData));
        _isAuthenticated = true;
        _isOfflineMode = !_connectivity.isOnline;
        notifyListeners();
        return true;
      } catch (e) {
        await _api.clearToken();
        await _database.clearAgentData();
      }
    }
    
    return false;
  }

  /// Appelé quand la connexion change
  void _onConnectionChanged(ConnectionStatus status) {
    final wasOffline = _isOfflineMode;
    _isOfflineMode = status != ConnectionStatus.online;
    
    // Si on revient en ligne, vérifier/rafraîchir le profil
    if (wasOffline && !_isOfflineMode && _isAuthenticated) {
      refreshProfile();
    }
    
    notifyListeners();
  }

  /// Connexion (avec fallback offline)
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Mode offline : vérifier les credentials locaux
    if (!_connectivity.isOnline) {
      final agentData = _database.getAgentData();
      if (agentData != null && agentData['username'] == username) {
        _agent = Agent.fromJson(agentData);
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
      final response = await _api.login(username, password);

      if (response.success && response.data != null) {
        // Sauvegarder le token
        if (response.data['token'] != null) {
          await _api.setToken(response.data['token']);
          await _database.saveAuthToken(response.data['token']);
        }

        // Créer l'agent
        final agentJson = response.data['user'] ?? response.data;
        agentJson['username'] = username; // Garder le username pour l'offline
        _agent = Agent.fromJson(agentJson);
        
        // Sauvegarder localement pour le mode offline
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ApiConfig.userKey, jsonEncode(agentJson));
        await _database.saveAgentData(agentJson);

        _isAuthenticated = true;
        _isOfflineMode = false;
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
      // Si erreur réseau et données locales disponibles
      final agentData = _database.getAgentData();
      if (agentData != null && agentData['username'] == username) {
        _agent = Agent.fromJson(agentData);
        _isAuthenticated = true;
        _isOfflineMode = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = 'Erreur de connexion: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    await _api.clearToken();
    await _database.clearAgentData();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConfig.userKey);
    
    _agent = null;
    _isAuthenticated = false;
    _isOfflineMode = false;
    _error = null;
    notifyListeners();
  }

  /// Rafraîchir le profil depuis le serveur
  Future<void> refreshProfile() async {
    if (!_isAuthenticated || !_connectivity.isOnline) return;

    try {
      final response = await _api.getProfile();
      
      if (response.success && response.data != null) {
        final agentJson = response.data;
        if (_agent != null) {
          agentJson['username'] = _database.getAgentData()?['username'];
        }
        _agent = Agent.fromJson(agentJson);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(ApiConfig.userKey, jsonEncode(agentJson));
        await _database.saveAgentData(agentJson);
        
        notifyListeners();
      }
    } catch (e) {
      // Silencieux - garder les données locales
    }
  }

  /// Vider l'erreur
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
