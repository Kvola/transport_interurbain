import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/scan_result.dart';

class ScanProvider extends ChangeNotifier {
  final ApiService apiService;
  
  bool _isProcessing = false;
  ScanResult? _lastResult;
  List<ScanResult> _scanHistory = [];
  int _successCount = 0;
  int _failCount = 0;
  
  ScanProvider({required this.apiService});
  
  bool get isProcessing => _isProcessing;
  ScanResult? get lastResult => _lastResult;
  List<ScanResult> get scanHistory => _scanHistory;
  int get successCount => _successCount;
  int get failCount => _failCount;
  int get totalScans => _successCount + _failCount;
  
  Future<ScanResult> validateTicket(String qrCode, int tripId) async {
    _isProcessing = true;
    notifyListeners();
    
    try {
      final result = await apiService.validateTicket(qrCode, tripId);
      _lastResult = result;
      _scanHistory.insert(0, result);
      
      if (result.success) {
        _successCount++;
      } else {
        _failCount++;
      }
      
      _isProcessing = false;
      notifyListeners();
      return result;
    } catch (e) {
      final result = ScanResult(
        success: false,
        message: e.toString(),
        errorCode: 'error',
      );
      _lastResult = result;
      _scanHistory.insert(0, result);
      _failCount++;
      
      _isProcessing = false;
      notifyListeners();
      return result;
    }
  }
  
  Future<ScanResult> checkInManually(int bookingId, int tripId) async {
    _isProcessing = true;
    notifyListeners();
    
    try {
      final result = await apiService.checkInPassenger(bookingId, tripId);
      _lastResult = result;
      
      if (result.success) {
        _successCount++;
      }
      
      _isProcessing = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isProcessing = false;
      notifyListeners();
      rethrow;
    }
  }
  
  void clearHistory() {
    _scanHistory = [];
    _successCount = 0;
    _failCount = 0;
    _lastResult = null;
    notifyListeners();
  }
  
  void clearLastResult() {
    _lastResult = null;
    notifyListeners();
  }
}
