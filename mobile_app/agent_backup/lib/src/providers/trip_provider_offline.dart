import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/local_database.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../models/agent_models.dart';

/// Provider pour les voyages agent avec support offline
class TripProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final LocalDatabase _database = LocalDatabase();
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncService _syncService = SyncService();

  List<Trip> _trips = [];
  Trip? _currentTrip;
  List<Passenger> _passengers = [];
  bool _isLoading = false;
  String? _error;
  DateTime _selectedDate = DateTime.now();
  bool _isFromCache = false;

  // Getters
  List<Trip> get trips => _trips;
  Trip? get currentTrip => _currentTrip;
  List<Passenger> get passengers => _passengers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;
  bool get isFromCache => _isFromCache;

  // Statistiques des passagers
  List<Passenger> get paidPassengers => _passengers.where((p) => p.isPaid).toList();
  List<Passenger> get unpaidPassengers => _passengers.where((p) => !p.isPaid).toList();
  List<Passenger> get boardedPassengers => _passengers.where((p) => p.isBoarded).toList();
  List<Passenger> get notBoardedPassengers => _passengers.where((p) => !p.isBoarded).toList();

  /// Charger les voyages (avec cache)
  Future<void> loadTrips({DateTime? date}) async {
    _isLoading = true;
    _error = null;
    _isFromCache = false;
    notifyListeners();

    try {
      if (date != null) {
        _selectedDate = date;
      }

      // Si hors ligne, utiliser le cache
      if (!_connectivity.isOnline) {
        _loadTripsFromCache();
        return;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response = await _api.getTrips(date: dateStr);

      if (response.success && response.data != null) {
        _trips = (response.data as List)
            .map((t) => Trip.fromJson(t))
            .toList();
        
        // Sauvegarder en cache
        await _database.saveTrips(
          (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList()
        );
      } else {
        _error = response.error ?? 'Erreur lors du chargement';
        _loadTripsFromCache();
      }
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      _loadTripsFromCache();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Charge les voyages depuis le cache
  void _loadTripsFromCache() {
    final cachedTrips = _database.getCachedTrips();
    
    // Filtrer par date si possible
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _trips = cachedTrips
        .where((t) => (t['departure_date'] as String?)?.startsWith(dateStr) ?? false)
        .map((t) => Trip.fromJson(t))
        .toList();
    
    // Si pas de résultat pour la date, afficher tous les voyages en cache
    if (_trips.isEmpty && cachedTrips.isNotEmpty) {
      _trips = cachedTrips.map((t) => Trip.fromJson(t)).toList();
    }
    
    _isFromCache = true;
    _isLoading = false;
    notifyListeners();
  }

  /// Charger les détails d'un voyage
  Future<void> loadTripDetails(int tripId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // D'abord chercher en cache
    final cachedTrip = _database.getTripById(tripId);
    if (cachedTrip != null) {
      _currentTrip = Trip.fromJson(cachedTrip);
      _isFromCache = true;
    }

    // Si en ligne, rafraîchir
    if (_connectivity.isOnline) {
      try {
        final response = await _api.getTripDetails(tripId);

        if (response.success && response.data != null) {
          _currentTrip = Trip.fromJson(response.data);
          _isFromCache = false;
        } else if (_currentTrip == null) {
          _error = response.error ?? 'Voyage non trouvé';
        }
      } catch (e) {
        if (_currentTrip == null) {
          _error = 'Erreur: ${e.toString()}';
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Charger les passagers d'un voyage (avec cache)
  Future<void> loadPassengers(int tripId) async {
    _isLoading = true;
    _error = null;
    _isFromCache = false;
    notifyListeners();

    // D'abord charger depuis le cache
    final cachedPassengers = _database.getCachedPassengers(tripId);
    if (cachedPassengers.isNotEmpty) {
      _passengers = cachedPassengers.map((p) => Passenger.fromJson(p)).toList();
      _isFromCache = true;
    }

    // Si hors ligne, s'arrêter là
    if (!_connectivity.isOnline) {
      _isLoading = false;
      if (_passengers.isEmpty) {
        _error = 'Aucun passager en cache pour ce voyage';
      }
      notifyListeners();
      return;
    }

    try {
      final response = await _api.getTripPassengers(tripId);

      if (response.success && response.data != null) {
        _passengers = (response.data as List)
            .map((p) => Passenger.fromJson(p))
            .toList();
        
        // Sauvegarder en cache
        await _database.savePassengers(
          tripId,
          (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList()
        );
        
        _isFromCache = false;
      } else if (_passengers.isEmpty) {
        _error = response.error ?? 'Erreur lors du chargement des passagers';
      }
    } catch (e) {
      if (_passengers.isEmpty) {
        _error = 'Erreur: ${e.toString()}';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Mettre à jour un passager après embarquement (local)
  void updatePassengerBoarded(int bookingId) {
    final index = _passengers.indexWhere((p) => p.bookingId == bookingId);
    if (index != -1) {
      final passenger = _passengers[index];
      _passengers[index] = Passenger(
        id: passenger.id,
        bookingId: passenger.bookingId,
        name: passenger.name,
        phone: passenger.phone,
        seatNumber: passenger.seatNumber,
        isPaid: passenger.isPaid,
        isBoarded: true,
        amountPaid: passenger.amountPaid,
        amountDue: passenger.amountDue,
        paymentMethod: passenger.paymentMethod,
        boardingTime: DateTime.now(),
        bookingReference: passenger.bookingReference,
      );
      
      // Mettre à jour le cache local
      if (_currentTrip != null) {
        _database.updatePassengerBoarded(
          _currentTrip!.id,
          bookingId,
          true,
          DateTime.now(),
        );
      }
      
      // Mettre à jour les stats du voyage courant
      if (_currentTrip != null) {
        _currentTrip = Trip(
          id: _currentTrip!.id,
          reference: _currentTrip!.reference,
          departureCity: _currentTrip!.departureCity,
          arrivalCity: _currentTrip!.arrivalCity,
          departureDate: _currentTrip!.departureDate,
          departureTime: _currentTrip!.departureTime,
          arrivalTime: _currentTrip!.arrivalTime,
          companyName: _currentTrip!.companyName,
          busNumber: _currentTrip!.busNumber,
          totalSeats: _currentTrip!.totalSeats,
          bookedSeats: _currentTrip!.bookedSeats,
          boardedCount: _currentTrip!.boardedCount + 1,
          paidCount: _currentTrip!.paidCount,
          unpaidCount: _currentTrip!.unpaidCount,
          status: _currentTrip!.status,
          driverName: _currentTrip!.driverName,
        );
      }
      
      notifyListeners();
    }
  }

  /// Mettre à jour plusieurs passagers après embarquement batch
  void updateMultiplePassengersBoarded(List<int> bookingIds) {
    for (final bookingId in bookingIds) {
      updatePassengerBoarded(bookingId);
    }
  }

  /// Pré-charger les passagers pour le mode offline
  Future<void> preloadPassengersForOffline() async {
    if (!_connectivity.isOnline) return;
    
    for (final trip in _trips) {
      if (!_database.isPassengersCacheValid(trip.id)) {
        await _syncService.syncPassengers(trip.id);
      }
    }
  }

  /// Changer la date sélectionnée
  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    loadTrips(date: date);
  }

  /// Vider l'erreur
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Réinitialiser le voyage courant
  void clearCurrentTrip() {
    _currentTrip = null;
    _passengers = [];
    notifyListeners();
  }
}
