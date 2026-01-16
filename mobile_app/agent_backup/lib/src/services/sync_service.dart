import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'connectivity_service.dart';
import 'local_database.dart';
import 'api_service.dart';

/// Service de synchronisation pour l'application Agent
/// Gère la synchronisation des embarquements effectués hors ligne
class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final ConnectivityService _connectivity = ConnectivityService();
  final LocalDatabase _database = LocalDatabase();
  final ApiService _apiService = ApiService();
  final Uuid _uuid = const Uuid();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _lastError;
  String? get lastError => _lastError;

  int _pendingBoardings = 0;
  int get pendingBoardings => _pendingBoardings;

  Timer? _syncTimer;

  /// Initialise le service de synchronisation
  Future<void> initialize() async {
    // Écouter les changements de connexion
    _connectivity.addConnectionListener(_onConnectionChanged);
    
    // Mettre à jour le compteur
    _updatePendingCount();
    
    // Démarrer la synchronisation périodique (plus fréquente pour l'agent)
    _startPeriodicSync();
  }

  /// Appelé quand la connexion change
  void _onConnectionChanged(ConnectionStatus status) {
    if (status == ConnectionStatus.online) {
      // Connexion rétablie : synchroniser immédiatement
      syncAll();
    }
  }

  /// Démarre la synchronisation périodique (toutes les 2 minutes pour l'agent)
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_connectivity.isOnline && !_isSyncing) {
        syncAll();
      }
    });
  }

  /// Met à jour le compteur d'embarquements en attente
  void _updatePendingCount() {
    _pendingBoardings = _database.pendingBoardingsCount;
    notifyListeners();
  }

  /// Enregistre un embarquement hors ligne
  Future<void> queueBoarding({
    required int tripId,
    required int bookingId,
    required String passengerName,
    required DateTime boardingTime,
    double? amountCollected,
  }) async {
    // Sauvegarder l'embarquement localement
    final boarding = {
      'id': _uuid.v4(),
      'trip_id': tripId,
      'booking_id': bookingId,
      'passenger_name': passengerName,
      'boarding_time': boardingTime.toIso8601String(),
      'amount_collected': amountCollected,
      'synced': false,
    };
    
    await _database.saveOfflineBoarding(boarding);
    
    // Mettre à jour le cache local des passagers
    await _database.updatePassengerBoarded(tripId, bookingId, true, boardingTime);
    
    _updatePendingCount();
    
    // Tenter de synchroniser immédiatement si en ligne
    if (_connectivity.isOnline) {
      syncAll();
    }
  }

  /// Enregistre plusieurs embarquements hors ligne
  Future<void> queueMultipleBoardings({
    required int tripId,
    required List<Map<String, dynamic>> passengers,
  }) async {
    final now = DateTime.now();
    
    for (final passenger in passengers) {
      await queueBoarding(
        tripId: tripId,
        bookingId: passenger['booking_id'],
        passengerName: passenger['name'],
        boardingTime: now,
        amountCollected: passenger['amount_collected'],
      );
    }
  }

  /// Synchronise toutes les données en attente
  Future<bool> syncAll() async {
    if (_isSyncing || !_connectivity.isOnline) {
      return false;
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      // 1. Synchroniser les embarquements en attente
      await _syncPendingBoardings();
      
      // 2. Rafraîchir la liste des voyages
      await _refreshTripsFromServer();
      
      // 3. Mettre à jour l'heure de synchronisation
      await _database.setLastSyncTime(DateTime.now());
      
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Synchronise les embarquements en attente
  Future<void> _syncPendingBoardings() async {
    final boardings = _database.getOfflineBoardings();
    
    for (final boarding in boardings) {
      try {
        final response = await _apiService.boardPassenger(
          bookingId: boarding['booking_id'],
          amountCollected: boarding['amount_collected'],
        );
        
        if (response.success) {
          // Supprimer l'embarquement de la file
          await _database.removeOfflineBoarding(boarding['booking_id']);
        }
      } catch (e) {
        debugPrint('Erreur sync embarquement ${boarding['booking_id']}: $e');
      }
    }
    
    _updatePendingCount();
  }

  /// Rafraîchit les voyages depuis le serveur
  Future<void> _refreshTripsFromServer() async {
    try {
      final response = await _apiService.getTodayTrips();
      if (response.success && response.data != null) {
        final trips = (response.data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _database.saveTrips(trips);
      }
    } catch (e) {
      debugPrint('Erreur rafraîchissement voyages: $e');
    }
  }

  /// Synchronise les passagers d'un voyage spécifique
  Future<void> syncPassengers(int tripId) async {
    if (!_connectivity.isOnline) return;
    
    try {
      final response = await _apiService.getTripPassengers(tripId);
      if (response.success && response.data != null) {
        final passengers = (response.data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _database.savePassengers(tripId, passengers);
      }
    } catch (e) {
      debugPrint('Erreur sync passagers: $e');
    }
  }

  /// Vérifie si un passager peut être embarqué hors ligne
  /// (basé sur les données en cache)
  bool canBoardOffline(int tripId, int bookingId) {
    final passengers = _database.getCachedPassengers(tripId);
    final passenger = passengers.firstWhere(
      (p) => p['booking_id'] == bookingId,
      orElse: () => {},
    );
    
    if (passenger.isEmpty) return false;
    
    // Vérifier s'il n'est pas déjà embarqué
    return !(passenger['is_boarded'] ?? false);
  }

  /// Récupère un passager depuis le cache pour le scan hors ligne
  Map<String, dynamic>? getPassengerFromCache(int tripId, String qrCode) {
    final passengers = _database.getCachedPassengers(tripId);
    
    // Chercher par token unique ou par référence de réservation
    return passengers.firstWhere(
      (p) => p['unique_token'] == qrCode || p['booking_reference'] == qrCode,
      orElse: () => {},
    );
  }

  /// Récupère les passagers en cache pour un voyage
  List<Map<String, dynamic>> getCachedPassengers(int tripId) {
    return _database.getCachedPassengers(tripId);
  }

  /// Vérifie si les passagers d'un voyage sont en cache et valides
  bool hasValidPassengersCache(int tripId) {
    return _database.isPassengersCacheValid(tripId);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectivity.removeConnectionListener(_onConnectionChanged);
    super.dispose();
  }
}
