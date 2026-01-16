import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../services/api_service.dart';
import '../services/local_database.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../models/agent_models.dart';

enum ScanState {
  idle,
  scanning,
  success,
  warning,
  error,
}

/// Provider pour le scan avec support offline complet
class ScanProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final LocalDatabase _database = LocalDatabase();
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncService _syncService = SyncService();
  final Uuid _uuid = const Uuid();

  ScanState _state = ScanState.idle;
  ScanResult? _lastResult;
  int? _currentTripId;
  String? _error;
  bool _isProcessing = false;
  List<int> _boardedBookings = []; // Bookings embarqués dans cette session
  bool _wasOfflineScan = false;
  int _pendingSyncCount = 0;

  // Getters
  ScanState get state => _state;
  ScanResult? get lastResult => _lastResult;
  int? get currentTripId => _currentTripId;
  String? get error => _error;
  bool get isProcessing => _isProcessing;
  List<int> get boardedBookings => _boardedBookings;
  bool get wasOfflineScan => _wasOfflineScan;
  int get pendingSyncCount => _pendingSyncCount;

  /// Définir le voyage actuel
  void setCurrentTrip(int tripId) {
    _currentTripId = tripId;
    _boardedBookings = [];
    _pendingSyncCount = _database.pendingBoardingsCount;
    reset();
  }

  /// Scanner un QR code (avec support offline)
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
    _wasOfflineScan = false;
    notifyListeners();

    // Mode offline : utiliser le cache local
    if (!_connectivity.isOnline) {
      return _processQrCodeOffline(qrCode);
    }

    try {
      // Essayer d'abord comme QR passager (UUID)
      var response = await _api.scanPassenger(_currentTripId!, qrCode);
      
      if (!response.success) {
        // Si échec, essayer comme ticket
        response = await _api.scanTicket(_currentTripId!, qrCode);
      }

      if (response.success && response.data != null) {
        _lastResult = ScanResult.fromJson(response.data);
        _determineState(_lastResult!);
      } else {
        _state = ScanState.error;
        _error = response.error ?? 'QR code non reconnu';
        _lastResult = null;
      }
    } catch (e) {
      // En cas d'erreur réseau, tenter le mode offline
      return _processQrCodeOffline(qrCode);
    }

    _isProcessing = false;
    notifyListeners();
    
    return _lastResult;
  }

  /// Traitement du QR code en mode offline
  Future<ScanResult?> _processQrCodeOffline(String qrCode) async {
    _wasOfflineScan = true;
    
    // Chercher le passager dans le cache
    final passengerData = _syncService.getPassengerFromCache(_currentTripId!, qrCode);
    
    if (passengerData == null || passengerData.isEmpty) {
      _state = ScanState.error;
      _error = 'Passager non trouvé (mode hors ligne)';
      _lastResult = null;
      _isProcessing = false;
      notifyListeners();
      return null;
    }

    // Créer un résultat de scan à partir des données en cache
    final passenger = Passenger.fromJson(passengerData);
    
    _lastResult = ScanResult(
      success: true,
      type: 'passenger',
      message: passenger.isBoarded 
          ? 'Passager déjà embarqué'
          : passenger.isPaid 
              ? 'Passager payé - Prêt pour embarquement' 
              : 'Paiement à percevoir',
      passenger: passenger,
      passengers: [passenger],
    );
    
    _determineState(_lastResult!);
    _isProcessing = false;
    notifyListeners();
    
    return _lastResult;
  }

  /// Détermine l'état visuel basé sur le résultat
  void _determineState(ScanResult result) {
    if (result.success) {
      if (result.type == 'passenger' && result.passengers != null) {
        final allPaid = result.passengers!.every((p) => p.isPaid);
        final anyBoarded = result.passengers!.any((p) => p.isBoarded);
        
        if (anyBoarded) {
          _state = ScanState.warning;
        } else if (allPaid) {
          _state = ScanState.success;
        } else {
          _state = ScanState.warning;
        }
      } else if (result.passenger != null) {
        if (result.passenger!.isBoarded) {
          _state = ScanState.warning;
        } else if (result.passenger!.isPaid) {
          _state = ScanState.success;
        } else {
          _state = ScanState.warning;
        }
      } else {
        _state = ScanState.success;
      }
    } else {
      _state = ScanState.error;
      _error = result.message ?? 'QR code invalide';
    }
  }

  /// Embarquer un passager (avec support offline)
  Future<bool> boardPassenger(int bookingId, {double? amountCollected}) async {
    _isProcessing = true;
    notifyListeners();

    // Mode offline : enregistrer localement
    if (!_connectivity.isOnline) {
      return _boardPassengerOffline(bookingId, amountCollected: amountCollected);
    }

    try {
      final response = await _api.boardPassenger(bookingId, amountCollected: amountCollected);

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
      // En cas d'erreur réseau, fallback vers offline
      return _boardPassengerOffline(bookingId, amountCollected: amountCollected);
    }
  }

  /// Embarquement en mode offline
  Future<bool> _boardPassengerOffline(int bookingId, {double? amountCollected}) async {
    try {
      // Trouver le passager dans le résultat du scan
      String passengerName = 'Inconnu';
      if (_lastResult?.passenger != null && _lastResult!.passenger!.bookingId == bookingId) {
        passengerName = _lastResult!.passenger!.name;
      } else if (_lastResult?.passengers != null) {
        final passenger = _lastResult!.passengers!.firstWhere(
          (p) => p.bookingId == bookingId,
          orElse: () => _lastResult!.passengers!.first,
        );
        passengerName = passenger.name;
      }

      // Enregistrer l'embarquement offline
      await _syncService.queueBoarding(
        tripId: _currentTripId!,
        bookingId: bookingId,
        passengerName: passengerName,
        boardingTime: DateTime.now(),
        amountCollected: amountCollected,
      );

      _boardedBookings.add(bookingId);
      _pendingSyncCount = _database.pendingBoardingsCount;
      _error = 'Embarquement enregistré hors ligne';
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  /// Embarquer plusieurs passagers (avec support offline)
  Future<bool> boardPassengersBatch(List<int> bookingIds, {List<double?>? amountsCollected}) async {
    _isProcessing = true;
    notifyListeners();

    // Mode offline
    if (!_connectivity.isOnline) {
      return _boardPassengersBatchOffline(bookingIds, amountsCollected: amountsCollected);
    }

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
      return _boardPassengersBatchOffline(bookingIds, amountsCollected: amountsCollected);
    }
  }

  /// Embarquement batch en mode offline
  Future<bool> _boardPassengersBatchOffline(List<int> bookingIds, {List<double?>? amountsCollected}) async {
    try {
      final passengers = <Map<String, dynamic>>[];
      
      for (int i = 0; i < bookingIds.length; i++) {
        final bookingId = bookingIds[i];
        String passengerName = 'Inconnu';
        
        if (_lastResult?.passengers != null) {
          final passenger = _lastResult!.passengers!.firstWhere(
            (p) => p.bookingId == bookingId,
            orElse: () => _lastResult!.passengers!.first,
          );
          passengerName = passenger.name;
        }
        
        passengers.add({
          'booking_id': bookingId,
          'name': passengerName,
          'amount_collected': amountsCollected != null && i < amountsCollected.length 
              ? amountsCollected[i] 
              : null,
        });
      }

      await _syncService.queueMultipleBoardings(
        tripId: _currentTripId!,
        passengers: passengers,
      );

      _boardedBookings.addAll(bookingIds);
      _pendingSyncCount = _database.pendingBoardingsCount;
      _error = '${bookingIds.length} embarquements enregistrés hors ligne';
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  /// Synchroniser les embarquements en attente
  Future<void> syncPendingBoardings() async {
    if (!_connectivity.isOnline) return;
    
    await _syncService.syncAll();
    _pendingSyncCount = _database.pendingBoardingsCount;
    notifyListeners();
  }

  /// Réinitialiser l'état
  void reset() {
    _state = ScanState.idle;
    _lastResult = null;
    _error = null;
    _wasOfflineScan = false;
    notifyListeners();
  }

  /// Vider l'erreur
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
