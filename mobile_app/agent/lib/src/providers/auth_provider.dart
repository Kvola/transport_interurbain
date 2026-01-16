import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService apiService;
  final StorageService storageService;
  
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _error;
  String? _userName;
  int? _userId;
  
  AuthProvider({
    required this.apiService,
    required this.storageService,
  }) {
    _checkAuth();
  }
  
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get error => _error;
  String? get userName => _userName;
  int? get userId => _userId;
  
  Future<void> _checkAuth() async {
    _isLoading = true;
    notifyListeners();
    
    final token = storageService.getToken();
    if (token != null) {
      _isAuthenticated = true;
      _userName = storageService.getUserName();
      _userId = storageService.getUserId();
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<bool> login(String login, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await apiService.login(login, password);
      
      await storageService.setToken(result['token']);
      await storageService.setUserId(result['user_id']);
      await storageService.setUserName(result['name'] ?? '');
      
      _isAuthenticated = true;
      _userName = result['name'];
      _userId = result['user_id'];
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<void> logout() async {
    await storageService.clearAll();
    _isAuthenticated = false;
    _userName = null;
    _userId = null;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
