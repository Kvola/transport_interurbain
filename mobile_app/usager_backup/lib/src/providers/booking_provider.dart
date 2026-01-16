import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/share_service.dart';
import '../config/api_config.dart';
import '../models/booking.dart';
import '../models/ticket.dart';

/// Provider pour les réservations
class BookingProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Booking> _bookings = [];
  Booking? _currentBooking;
  Ticket? _currentTicket;
  Receipt? _currentReceipt;
  bool _isLoading = false;
  String? _error;
  int _totalBookings = 0;
  int? _lastBookingId;
  
  List<Booking> get bookings => _bookings;
  Booking? get currentBooking => _currentBooking;
  Ticket? get currentTicket => _currentTicket;
  Receipt? get currentReceipt => _currentReceipt;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalBookings => _totalBookings;
  int? get lastBookingId => _lastBookingId;
  
  /// Réservations à venir (non annulées, non terminées)
  List<Booking> get upcomingBookings => _bookings.where((b) => 
    ['draft', 'reserved', 'confirmed'].contains(b.state)
  ).toList();
  
  /// Réservations passées (terminées, embarquées)
  List<Booking> get pastBookings => _bookings.where((b) => 
    ['checked_in', 'completed'].contains(b.state)
  ).toList();
  
  /// Réservations annulées
  List<Booking> get cancelledBookings => _bookings.where((b) => 
    ['cancelled', 'refunded'].contains(b.state)
  ).toList();
  
  /// Charger les réservations
  Future<void> loadBookings({String? state, int limit = 50, int offset = 0}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
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
        } else {
          _bookings.addAll(bookingsJson.map((b) => Booking.fromJson(b)));
        }
        
        _totalBookings = response.data['total'] ?? _bookings.length;
      } else {
        _error = response.message;
      }
    } catch (e) {
      _error = 'Erreur chargement des réservations: $e';
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  /// Créer une réservation
  /// 
  /// [tripId] - ID du voyage
  /// [seatIds] - Liste des IDs des sièges sélectionnés
  /// [passengers] - Liste des informations passagers
  /// [paymentMethod] - Méthode de paiement
  /// [forOther] - Si true, l'achat est pour un tiers
  /// [otherPassenger] - Informations du passager tiers
  Future<bool> createBooking({
    required int tripId,
    List<int>? seatIds,
    List<Map<String, String>>? passengers,
    String? paymentMethod,
    int? seatId,
    String ticketType = 'adult',
    double? luggageWeight,
    String bookingType = 'reservation',
    bool forOther = false,
    OtherPassenger? otherPassenger,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final body = <String, dynamic>{
        'trip_id': tripId,
        'ticket_type': ticketType,
        'booking_type': bookingType,
      };
      
      // Support ancien format (single seat)
      if (seatId != null) {
        body['seat_id'] = seatId;
      }
      
      // Support nouveau format (multiple seats)
      if (seatIds != null && seatIds.isNotEmpty) {
        body['seat_ids'] = seatIds;
      }
      
      if (passengers != null && passengers.isNotEmpty) {
        body['passengers'] = passengers;
      }
      
      if (paymentMethod != null) {
        body['payment_method'] = paymentMethod;
      }
      
      if (luggageWeight != null) {
        body['luggage_weight'] = luggageWeight;
      }
      
      // Support achat pour un tiers
      if (forOther && otherPassenger != null) {
        body['for_other'] = true;
        body['other_passenger'] = otherPassenger.toJson();
      }
      
      final response = await _apiService.post(
        ApiConfig.bookingsEndpoint,
        body: body,
      );
      
      if (response.isSuccess && response.data != null) {
        _currentBooking = Booking.fromJson(response.data['booking']);
        _lastBookingId = _currentBooking!.id;
        _bookings.insert(0, _currentBooking!);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.message;
    } catch (e) {
      _error = 'Erreur création réservation: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }
  
  /// Obtenir les détails d'une réservation
  Future<Booking?> getBookingDetails(int bookingId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get(
        ApiConfig.bookingDetailEndpoint(bookingId),
      );
      
      if (response.isSuccess && response.data != null) {
        _currentBooking = Booking.fromJson(response.data['booking']);
        _isLoading = false;
        notifyListeners();
        return _currentBooking;
      }
      
      _error = response.message;
    } catch (e) {
      _error = 'Erreur: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return null;
  }
  
  /// Payer une réservation
  Future<Map<String, dynamic>?> payBooking({
    required int bookingId,
    required String paymentMethod,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final body = {
        'payment_method': paymentMethod,
        if (phone != null) 'phone': phone,
      };
      
      final response = await _apiService.post(
        ApiConfig.payBookingEndpoint(bookingId),
        body: body,
      );
      
      if (response.isSuccess && response.data != null) {
        // Mettre à jour la réservation si retournée
        if (response.data['booking'] != null) {
          _currentBooking = Booking.fromJson(response.data['booking']);
          
          // Mettre à jour dans la liste
          final index = _bookings.indexWhere((b) => b.id == bookingId);
          if (index >= 0) {
            _bookings[index] = _currentBooking!;
          }
        }
        
        _isLoading = false;
        notifyListeners();
        return response.data as Map<String, dynamic>;
      }
      
      _error = response.message;
    } catch (e) {
      _error = 'Erreur paiement: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return null;
  }
  
  /// Obtenir le ticket (alias pour getBookingTicket)
  Future<Ticket?> getTicket(int bookingId) => getBookingTicket(bookingId);
  
  /// Obtenir le ticket de la réservation
  Future<Ticket?> getBookingTicket(int bookingId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get(
        ApiConfig.ticketEndpoint(bookingId),
      );
      
      if (response.isSuccess && response.data != null) {
        _currentTicket = Ticket.fromJson(response.data['ticket']);
        _isLoading = false;
        notifyListeners();
        return _currentTicket;
      }
      
      _error = response.message;
    } catch (e) {
      _error = 'Erreur: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return null;
  }
  
  /// Obtenir le reçu
  Future<Receipt?> getReceipt(int bookingId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get(
        ApiConfig.receiptEndpoint(bookingId),
      );
      
      if (response.isSuccess && response.data != null) {
        _currentReceipt = Receipt.fromJson(response.data['receipt']);
        _isLoading = false;
        notifyListeners();
        return _currentReceipt;
      }
      
      _error = response.message;
    } catch (e) {
      _error = 'Erreur: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return null;
  }
  
  /// Annuler une réservation
  Future<bool> cancelBooking(int bookingId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post(
        ApiConfig.cancelBookingEndpoint(bookingId),
      );
      
      if (response.isSuccess) {
        // Mettre à jour la réservation
        if (response.data != null && response.data['booking'] != null) {
          final updatedBooking = Booking.fromJson(response.data['booking']);
          
          final index = _bookings.indexWhere((b) => b.id == bookingId);
          if (index >= 0) {
            _bookings[index] = updatedBooking;
          }
          
          if (_currentBooking?.id == bookingId) {
            _currentBooking = updatedBooking;
          }
        }
        
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
  
  /// Générer un lien de partage pour le billet
  /// Retourne les données de partage ou null en cas d'erreur
  Future<TicketShareData?> generateShareLink(int bookingId) async {
    _error = null;
    
    try {
      final response = await _apiService.post(
        ApiConfig.shareBookingEndpoint(bookingId),
      );
      
      if (response.isSuccess && response.data != null) {
        return TicketShareData.fromJson(response.data as Map<String, dynamic>);
      }
      
      _error = response.message;
    } catch (e) {
      _error = 'Erreur génération lien de partage: $e';
    }
    
    return null;
  }
  
  /// Effacer les données
  void clear() {
    _bookings = [];
    _currentBooking = null;
    _currentTicket = null;
    _currentReceipt = null;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
