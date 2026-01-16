import 'package:flutter/foundation.dart';

import '../services/api_service.dart';
import '../models/agent_models.dart';

enum ScanState {
  idle,
  scanning,
  success,
  warning,
  error,
}

class ScanProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  ScanState _state = ScanState.idle;
  ScanResult? _lastResult;
  int? _currentTripId;
  String? _error;
  bool _isProcessing = false;
  List<int> _boardedBookings = []; // Bookings embarqués dans cette session

  // Getters
  ScanState get state => _state;
  ScanResult? get lastResult => _lastResult;
  int? get currentTripId => _currentTripId;
  String? get error => _error;
  bool get isProcessing => _isProcessing;
  List<int> get boardedBookings => _boardedBookings;

  // Définir le voyage actuel
  void setCurrentTrip(int tripId) {
    _currentTripId = tripId;
    _boardedBookings = [];
    reset();
  }

  // Scanner un QR code (passager ou ticket)
  Future<ScanResult?> processQrCode(String qrCode) async {
    if (_currentTripId == null) {
      _error = 'Aucun voyage sélectionné';
      _state = ScanState.error;
      notifyListeners();
      return null;
    }

    if (_isProcessing) return null;

    _isProcessing = true;
    _state = ScanState.scanning;
    _error = null;
    notifyListeners();

    try {
      // Essayer d'abord comme QR passager (UUID)
      var response = await _api.scanPassenger(_currentTripId!, qrCode);
      
      if (!response.success) {
        // Si échec, essayer comme ticket
        response = await _api.scanTicket(_currentTripId!, qrCode);
      }

      if (response.success && response.data != null) {
        _lastResult = ScanResult.fromJson(response.data);
        
        // Déterminer l'état basé sur le résultat
        if (_lastResult!.success) {
          // Vérifier si tous payés
          if (_lastResult!.type == 'passenger' && _lastResult!.passengers != null) {
            final allPaid = _lastResult!.passengers!.every((p) => p.isPaid);
            final anyBoarded = _lastResult!.passengers!.any((p) => p.isBoarded);
            
            if (anyBoarded) {
              _state = ScanState.warning;
            } else if (allPaid) {
              _state = ScanState.success;
            } else {
              _state = ScanState.warning;
            }
          } else if (_lastResult!.passenger != null) {
            if (_lastResult!.passenger!.isBoarded) {
              _state = ScanState.warning;
            } else if (_lastResult!.passenger!.isPaid) {
              _state = ScanState.success;
            } else {
              _state = ScanState.warning;
            }
          } else {
            _state = ScanState.success;
          }
        } else {
          _state = ScanState.error;
          _error = _lastResult!.message ?? 'QR code invalide';
        }
      } else {
        _state = ScanState.error;
        _error = response.error ?? 'QR code non reconnu';
        _lastResult = null;
      }
    } catch (e) {
      _state = ScanState.error;
      _error = 'Erreur de scan: ${e.toString()}';
      _lastResult = null;
    }

    _isProcessing = false;
    notifyListeners();
    
    return _lastResult;
  }

  // Embarquer un passager
  Future<bool> boardPassenger(int bookingId) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final response = await _api.boardPassenger(bookingId);

      if (response.success) {
        _boardedBookings.add(bookingId);
        _isProcessing = false;
        notifyListeners();
        return true;
      } else {
        _error = response.error ?? 'Erreur lors de l\'embarquement';
        _isProcessing = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  // Embarquer plusieurs passagers
  Future<bool> boardPassengersBatch(List<int> bookingIds) async {
    _isProcessing = true;
    notifyListeners();

    try {
      final response = await _api.boardPassengersBatch(bookingIds);

      if (response.success) {
        _boardedBookings.addAll(bookingIds);
        _isProcessing = false;
        notifyListeners();
        return true;
      } else {
        _error = response.error ?? 'Erreur lors de l\'embarquement';
        _isProcessing = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  // Réinitialiser pour un nouveau scan
  void reset() {
    _state = ScanState.idle;
    _lastResult = null;
    _error = null;
    _isProcessing = false;
    notifyListeners();
  }

  // Vérifier si un booking est déjà embarqué
  bool isBoarded(int bookingId) {
    return _boardedBookings.contains(bookingId);
  }

  // Obtenir le nombre d'embarquements de la session
  int get sessionBoardedCount => _boardedBookings.length;
}
