import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../services/api_service.dart';
import '../services/local_database.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../config/api_config.dart';
import '../models/booking.dart';
import '../models/ticket.dart';

/// Provider pour les réservations avec support offline
class BookingProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocalDatabase _database = LocalDatabase();
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncService _syncService = SyncService();
  final Uuid _uuid = const Uuid();
  
  List<Booking> _bookings = [];
  Booking? _currentBooking;
  Ticket? _currentTicket;
  Receipt? _currentReceipt;
  bool _isLoading = false;
  String? _error;
  int _totalBookings = 0;
  bool _isFromCache = false;
  int _pendingBookings = 0;
  
  List<Booking> get bookings => _bookings;
  Booking? get currentBooking => _currentBooking;
  Ticket? get currentTicket => _currentTicket;
  Receipt? get currentReceipt => _currentReceipt;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalBookings => _totalBookings;
  bool get isFromCache => _isFromCache;
  int get pendingBookings => _pendingBookings;
  
  /// Charger les réservations (avec cache)
  Future<void> loadBookings({String? state, int limit = 50, int offset = 0}) async {
    _isLoading = true;
    _error = null;
    _isFromCache = false;
    notifyListeners();
    
    // Si hors ligne ou erreur réseau, utiliser le cache
    if (!_connectivity.isOnline) {
      _loadBookingsFromCache(state);
      return;
    }
    
    try {
      final params = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (state != null) {
        params['state'] = state;
      }
      
      final response = await _apiService.get(
        ApiConfig.bookingsEndpoint,
        queryParams: params,
      );
      
      if (response.isSuccess && response.data != null) {
        final List bookingsJson = response.data['bookings'] ?? [];
        
        if (offset == 0) {
          _bookings = bookingsJson.map((b) => Booking.fromJson(b)).toList();
          
          // Sauvegarder en cache
          await _database.saveBookings(
            bookingsJson.map((e) => Map<String, dynamic>.from(e)).toList()
          );
        } else {
          _bookings.addAll(bookingsJson.map((b) => Booking.fromJson(b)));
        }
        
        _totalBookings = response.data['total'] ?? _bookings.length;
      } else {
        _error = response.message;
        _loadBookingsFromCache(state);
      }
    } catch (e) {
      _error = 'Erreur chargement des réservations';
      _loadBookingsFromCache(state);
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  /// Charge les réservations depuis le cache
  void _loadBookingsFromCache(String? state) {
    final cachedBookings = _database.getCachedBookings();
    
    _bookings = cachedBookings
        .where((b) => state == null || b['state'] == state)
        .map((b) => Booking.fromJson(b))
        .toList();
    
    _totalBookings = _bookings.length;
    _isFromCache = true;
    _isLoading = false;
    notifyListeners();
  }
  
  /// Créer une réservation (avec support offline)
  Future<Booking?> createBooking({
    required int tripId,
    int? seatId,
    String ticketType = 'adult',
    double? luggageWeight,
    String bookingType = 'reservation',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    final bookingData = {
      'trip_id': tripId,
      'ticket_type': ticketType,
      'booking_type': bookingType,
      if (seatId != null) 'seat_id': seatId,
      if (luggageWeight != null) 'luggage_weight': luggageWeight,
    };
    
    // Si hors ligne, créer une réservation locale
    if (!_connectivity.isOnline) {
      return _createOfflineBooking(bookingData);
    }
    
    try {
      final response = await _apiService.post(
        ApiConfig.bookingsEndpoint,
        body: bookingData,
      );
      
      if (response.isSuccess && response.data != null) {
        _currentBooking = Booking.fromJson(response.data['booking']);
        _bookings.insert(0, _currentBooking!);
        
        // Sauvegarder en cache
        await _database.addBookingToCache(response.data['booking']);
        
        _isLoading = false;
        notifyListeners();
        return _currentBooking;
      }
      
      _error = response.message;
    } catch (e) {
      // Fallback vers réservation offline
      return _createOfflineBooking(bookingData);
    }
    
    _isLoading = false;
    notifyListeners();
    return null;
  }
  
  /// Crée une réservation en mode offline
  Future<Booking?> _createOfflineBooking(Map<String, dynamic> bookingData) async {
    // Générer une réservation temporaire
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempReference = 'TEMP-${_uuid.v4().substring(0, 8).toUpperCase()}';
    
    final offlineBooking = {
      'id': tempId,
      'reference': tempReference,
      'state': 'pending_sync',
      'is_offline': true,
      ...bookingData,
      'created_at': DateTime.now().toIso8601String(),
    };
    
    // Sauvegarder localement
    await _database.addBookingToCache(offlineBooking);
    
    // Ajouter à la file de synchronisation
    await _syncService.queueBooking(bookingData);
    
    _currentBooking = Booking.fromJson(offlineBooking);
    _bookings.insert(0, _currentBooking!);
    _pendingBookings++;
    
    _error = 'Réservation enregistrée hors ligne. Elle sera synchronisée automatiquement.';
    _isLoading = false;
    notifyListeners();
    
    return _currentBooking;
  }
  
  /// Obtenir les détails d'une réservation
  Future<Booking?> getBookingDetails(int bookingId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    // Chercher d'abord en cache
    final cachedBookings = _database.getCachedBookings();
    final cached = cachedBookings.firstWhere(
      (b) => b['id'] == bookingId,
      orElse: () => {},
    );
    
    if (cached.isNotEmpty) {
      _currentBooking = Booking.fromJson(cached);
      _isFromCache = true;
    }
    
    // Si en ligne, rafraîchir
    if (_connectivity.isOnline) {
      try {
        final response = await _apiService.get(
          ApiConfig.bookingDetailEndpoint(bookingId),
        );
        
        if (response.isSuccess && response.data != null) {
          _currentBooking = Booking.fromJson(response.data['booking']);
          _isFromCache = false;
        }
      } catch (e) {
        if (_currentBooking == null) {
          _error = 'Erreur: $e';
        }
      }
    }
    
    _isLoading = false;
    notifyListeners();
    return _currentBooking;
  }
  
  /// Payer une réservation (nécessite une connexion)
  Future<Map<String, dynamic>?> payBooking({
    required int bookingId,
    required String paymentMethod,
    String? phone,
  }) async {
    if (!_connectivity.isOnline) {
      _error = 'Connexion internet requise pour le paiement';
      notifyListeners();
      return null;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final body = {
        'booking_id': bookingId,
        'payment_method': paymentMethod,
        if (phone != null) 'phone': phone,
      };
      
      final response = await _apiService.post(
        ApiConfig.paymentEndpoint,
        body: body,
      );
      
      if (response.isSuccess && response.data != null) {
        // Mettre à jour la réservation
        if (response.data['booking'] != null) {
          _currentBooking = Booking.fromJson(response.data['booking']);
          await _database.addBookingToCache(response.data['booking']);
        }
        
        _isLoading = false;
        notifyListeners();
        return response.data;
      }
      
      _error = response.message;
    } catch (e) {
      _error = 'Erreur paiement: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return null;
  }
  
  /// Annuler une réservation (avec support offline)
  Future<bool> cancelBooking(int bookingId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    // Si hors ligne, ajouter à la file de sync
    if (!_connectivity.isOnline) {
      await _syncService.queueCancelBooking(bookingId);
      
      // Marquer comme annulée localement
      final index = _bookings.indexWhere((b) => b.id == bookingId);
      if (index != -1) {
        // Créer une copie avec état annulé
        final booking = _bookings[index];
        _bookings[index] = Booking(
          id: booking.id,
          reference: booking.reference,
          state: 'cancelled',
          tripId: booking.tripId,
          tripDate: booking.tripDate,
          departureCity: booking.departureCity,
          arrivalCity: booking.arrivalCity,
          price: booking.price,
          ticketType: booking.ticketType,
        );
      }
      
      _error = 'Annulation enregistrée hors ligne';
      _isLoading = false;
      notifyListeners();
      return true;
    }
    
    try {
      final response = await _apiService.post(
        '${ApiConfig.bookingsEndpoint}/$bookingId/cancel',
        body: {},
      );
      
      if (response.isSuccess) {
        // Supprimer ou mettre à jour localement
        _bookings.removeWhere((b) => b.id == bookingId);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.message;
    } catch (e) {
      _error = 'Erreur annulation: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }
  
  /// Obtenir le billet d'une réservation
  Future<Ticket?> getTicket(int bookingId) async {
    _isLoading = true;
    notifyListeners();
    
    // Chercher en cache
    final cachedTicket = _database.getTicketById(bookingId);
    if (cachedTicket != null) {
      _currentTicket = Ticket.fromJson(cachedTicket);
      _isFromCache = true;
    }
    
    // Si en ligne, rafraîchir
    if (_connectivity.isOnline) {
      try {
        final response = await _apiService.get(
          '${ApiConfig.bookingsEndpoint}/$bookingId/ticket',
        );
        
        if (response.isSuccess && response.data != null) {
          _currentTicket = Ticket.fromJson(response.data['ticket']);
          _isFromCache = false;
        }
      } catch (e) {
        // Garder le ticket en cache
      }
    }
    
    _isLoading = false;
    notifyListeners();
    return _currentTicket;
  }
  
  /// Rafraîchir les données depuis le serveur
  Future<void> refresh() async {
    if (_connectivity.isOnline) {
      await loadBookings();
    }
  }
  
  /// Effacer l'erreur
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// Effacer la réservation courante
  void clearCurrentBooking() {
    _currentBooking = null;
    _currentTicket = null;
    notifyListeners();
  }
}
