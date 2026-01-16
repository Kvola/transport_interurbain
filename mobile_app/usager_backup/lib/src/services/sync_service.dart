import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'connectivity_service.dart';
import 'local_database.dart';
import 'api_service.dart';

/// Service de synchronisation pour l'application Usager
/// Gère la synchronisation des données en arrière-plan
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

  int _pendingActions = 0;
  int get pendingActions => _pendingActions;

  Timer? _syncTimer;

  /// Initialise le service de synchronisation
  Future<void> initialize() async {
    // Écouter les changements de connexion
    _connectivity.addConnectionListener(_onConnectionChanged);
    
    // Mettre à jour le compteur
    _updatePendingCount();
    
    // Démarrer la synchronisation périodique
    _startPeriodicSync();
  }

  /// Appelé quand la connexion change
  void _onConnectionChanged(ConnectionStatus status) {
    if (status == ConnectionStatus.online) {
      // Connexion rétablie : synchroniser
      syncAll();
    }
  }

  /// Démarre la synchronisation périodique (toutes les 5 minutes si en ligne)
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_connectivity.isOnline && !_isSyncing) {
        syncAll();
      }
    });
  }

  /// Met à jour le compteur d'actions en attente
  void _updatePendingCount() {
    _pendingActions = _database.pendingSyncCount;
    notifyListeners();
  }

  /// Ajoute une réservation à la file de synchronisation
  Future<void> queueBooking(Map<String, dynamic> bookingData) async {
    final action = SyncAction(
      id: _uuid.v4(),
      type: SyncActionType.createBooking,
      data: bookingData,
    );
    
    await _database.addToSyncQueue(action);
    _updatePendingCount();
    
    // Tenter de synchroniser immédiatement si en ligne
    if (_connectivity.isOnline) {
      syncAll();
    }
  }

  /// Ajoute une annulation de réservation à la file
  Future<void> queueCancelBooking(int bookingId) async {
    final action = SyncAction(
      id: _uuid.v4(),
      type: SyncActionType.cancelBooking,
      data: {'booking_id': bookingId},
    );
    
    await _database.addToSyncQueue(action);
    _updatePendingCount();
    
    if (_connectivity.isOnline) {
      syncAll();
    }
  }

  /// Ajoute une mise à jour de profil à la file
  Future<void> queueProfileUpdate(Map<String, dynamic> profileData) async {
    final action = SyncAction(
      id: _uuid.v4(),
      type: SyncActionType.updateProfile,
      data: profileData,
    );
    
    await _database.addToSyncQueue(action);
    _updatePendingCount();
    
    if (_connectivity.isOnline) {
      syncAll();
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
      // 1. Synchroniser les actions en attente
      await _syncPendingActions();
      
      // 2. Rafraîchir les données depuis le serveur
      await _refreshDataFromServer();
      
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

  /// Synchronise les actions en attente
  Future<void> _syncPendingActions() async {
    final actions = _database.getPendingSyncActions();
    
    for (final action in actions) {
      try {
        bool success = false;
        
        switch (action.type) {
          case SyncActionType.createBooking:
            success = await _syncCreateBooking(action.data);
            break;
          case SyncActionType.cancelBooking:
            success = await _syncCancelBooking(action.data);
            break;
          case SyncActionType.updateProfile:
            success = await _syncUpdateProfile(action.data);
            break;
          case SyncActionType.confirmPayment:
            success = await _syncConfirmPayment(action.data);
            break;
        }
        
        if (success) {
          await _database.removeSyncAction(action.id);
        } else {
          // Incrémenter le compteur de tentatives
          action.retryCount++;
          if (action.retryCount >= 5) {
            // Abandonner après 5 tentatives
            await _database.removeSyncAction(action.id);
          }
        }
      } catch (e) {
        debugPrint('Erreur sync action ${action.id}: $e');
      }
    }
    
    _updatePendingCount();
  }

  /// Synchronise une création de réservation
  Future<bool> _syncCreateBooking(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.createBooking(
        tripId: data['trip_id'],
        seatNumbers: List<String>.from(data['seat_numbers']),
        paymentMethod: data['payment_method'],
      );
      
      if (response.success && response.data != null) {
        // Mettre à jour le cache local avec la vraie réservation
        await _database.addBookingToCache(response.data);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Synchronise une annulation de réservation
  Future<bool> _syncCancelBooking(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.cancelBooking(data['booking_id']);
      return response.success;
    } catch (e) {
      return false;
    }
  }

  /// Synchronise une mise à jour de profil
  Future<bool> _syncUpdateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.updateProfile(data);
      return response.success;
    } catch (e) {
      return false;
    }
  }

  /// Synchronise une confirmation de paiement
  Future<bool> _syncConfirmPayment(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.confirmPayment(
        bookingId: data['booking_id'],
        paymentReference: data['payment_reference'],
      );
      return response.success;
    } catch (e) {
      return false;
    }
  }

  /// Rafraîchit les données depuis le serveur
  Future<void> _refreshDataFromServer() async {
    try {
      // Rafraîchir les voyages
      final tripsResponse = await _apiService.searchTrips();
      if (tripsResponse.success && tripsResponse.data != null) {
        final trips = (tripsResponse.data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _database.saveTrips(trips);
      }
      
      // Rafraîchir les réservations de l'utilisateur
      final bookingsResponse = await _apiService.getMyBookings();
      if (bookingsResponse.success && bookingsResponse.data != null) {
        final bookings = (bookingsResponse.data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _database.saveBookings(bookings);
      }
    } catch (e) {
      debugPrint('Erreur rafraîchissement: $e');
    }
  }

  /// Force la synchronisation des voyages
  Future<void> syncTrips() async {
    if (!_connectivity.isOnline) return;
    
    try {
      final response = await _apiService.searchTrips();
      if (response.success && response.data != null) {
        final trips = (response.data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _database.saveTrips(trips);
      }
    } catch (e) {
      debugPrint('Erreur sync voyages: $e');
    }
  }

  /// Force la synchronisation des réservations
  Future<void> syncBookings() async {
    if (!_connectivity.isOnline) return;
    
    try {
      final response = await _apiService.getMyBookings();
      if (response.success && response.data != null) {
        final bookings = (response.data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _database.saveBookings(bookings);
      }
    } catch (e) {
      debugPrint('Erreur sync réservations: $e');
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectivity.removeConnectionListener(_onConnectionChanged);
    super.dispose();
  }
}
