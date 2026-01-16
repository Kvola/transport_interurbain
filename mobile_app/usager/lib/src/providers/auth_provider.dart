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
  String? _userPhone;
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
  String? get userPhone => _userPhone;
  int? get userId => _userId;
  
  Future<void> _checkAuth() async {
    _isLoading = true;
    notifyListeners();
    
    final token = storageService.getToken();
    if (token != null) {
      _isAuthenticated = true;
      _userName = storageService.getUserName();
      _userPhone = storageService.getUserPhone();
      _userId = storageService.getUserId();
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await apiService.login(phone, password);
      
      await storageService.setToken(result['token']);
      await storageService.setUserId(result['user_id']);
      await storageService.setUserName(result['name'] ?? '');
      await storageService.setUserPhone(phone);
      
      _isAuthenticated = true;
      _userName = result['name'];
      _userPhone = phone;
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
  
  Future<bool> register({
    required String name,
    required String phone,
    required String password,
    String? email,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await apiService.register(
        name: name,
        phone: phone,
        password: password,
        email: email,
      );
      
      await storageService.setToken(result['token']);
      await storageService.setUserId(result['user_id']);
      await storageService.setUserName(name);
      await storageService.setUserPhone(phone);
      
      _isAuthenticated = true;
      _userName = name;
      _userPhone = phone;
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
    _userPhone = null;
    _userId = null;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
