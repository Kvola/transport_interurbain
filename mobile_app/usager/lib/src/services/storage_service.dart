import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  SharedPreferences? _prefs;
  
  static const String keyToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserName = 'user_name';
  static const String keyUserPhone = 'user_phone';
  static const String keyApiUrl = 'api_url';
  
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  // Token
  Future<void> setToken(String token) async {
    await _prefs?.setString(keyToken, token);
  }
  
  String? getToken() => _prefs?.getString(keyToken);
  
  Future<void> clearToken() async {
    await _prefs?.remove(keyToken);
  }
  
  // User ID
  Future<void> setUserId(int id) async {
    await _prefs?.setInt(keyUserId, id);
  }
  
  int? getUserId() => _prefs?.getInt(keyUserId);
  
  // User Name
  Future<void> setUserName(String name) async {
    await _prefs?.setString(keyUserName, name);
  }
  
  String? getUserName() => _prefs?.getString(keyUserName);
  
  // User Phone
  Future<void> setUserPhone(String phone) async {
    await _prefs?.setString(keyUserPhone, phone);
  }
  
  String? getUserPhone() => _prefs?.getString(keyUserPhone);
  
  // API URL
  Future<void> setApiUrl(String url) async {
    await _prefs?.setString(keyApiUrl, url);
  }
  
  String getApiUrl() => _prefs?.getString(keyApiUrl) ?? 'http://localhost:8069';
  
  // Clear all
  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
