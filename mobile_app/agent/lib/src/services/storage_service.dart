import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  SharedPreferences? _prefs;
  
  static const String keyToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserName = 'user_name';
  static const String keyApiUrl = 'api_url';
  static const String keySelectedTripId = 'selected_trip_id';
  
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  Future<void> setToken(String token) async {
    await _prefs?.setString(keyToken, token);
  }
  
  String? getToken() => _prefs?.getString(keyToken);
  
  Future<void> clearToken() async {
    await _prefs?.remove(keyToken);
  }
  
  Future<void> setUserId(int id) async {
    await _prefs?.setInt(keyUserId, id);
  }
  
  int? getUserId() => _prefs?.getInt(keyUserId);
  
  Future<void> setUserName(String name) async {
    await _prefs?.setString(keyUserName, name);
  }
  
  String? getUserName() => _prefs?.getString(keyUserName);
  
  Future<void> setApiUrl(String url) async {
    await _prefs?.setString(keyApiUrl, url);
  }
  
  String getApiUrl() => _prefs?.getString(keyApiUrl) ?? 'http://localhost:8069';
  
  Future<void> setSelectedTripId(int tripId) async {
    await _prefs?.setInt(keySelectedTripId, tripId);
  }
  
  int? getSelectedTripId() => _prefs?.getInt(keySelectedTripId);
  
  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
