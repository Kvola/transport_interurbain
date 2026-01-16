import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../models/agent_models.dart';

class TripProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Trip> _trips = [];
  Trip? _currentTrip;
  List<Passenger> _passengers = [];
  bool _isLoading = false;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  // Getters
  List<Trip> get trips => _trips;
  Trip? get currentTrip => _currentTrip;
  List<Passenger> get passengers => _passengers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;

  // Statistiques des passagers
  List<Passenger> get paidPassengers => _passengers.where((p) => p.isPaid).toList();
  List<Passenger> get unpaidPassengers => _passengers.where((p) => !p.isPaid).toList();
  List<Passenger> get boardedPassengers => _passengers.where((p) => p.isBoarded).toList();
  List<Passenger> get notBoardedPassengers => _passengers.where((p) => !p.isBoarded).toList();

  // Charger les voyages
  Future<void> loadTrips({DateTime? date}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (date != null) {
        _selectedDate = date;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response = await _api.getTrips(date: dateStr);

      if (response.success && response.data != null) {
        _trips = (response.data as List)
            .map((t) => Trip.fromJson(t))
            .toList();
      } else {
        _error = response.error ?? 'Erreur lors du chargement';
        _trips = [];
      }
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      _trips = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Charger les détails d'un voyage
  Future<void> loadTripDetails(int tripId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getTripDetails(tripId);

      if (response.success && response.data != null) {
        _currentTrip = Trip.fromJson(response.data);
      } else {
        _error = response.error ?? 'Voyage non trouvé';
        _currentTrip = null;
      }
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      _currentTrip = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  // Charger les passagers d'un voyage
  Future<void> loadPassengers(int tripId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getTripPassengers(tripId);

      if (response.success && response.data != null) {
        _passengers = (response.data as List)
            .map((p) => Passenger.fromJson(p))
            .toList();
      } else {
        _error = response.error ?? 'Erreur lors du chargement des passagers';
        _passengers = [];
      }
    } catch (e) {
      _error = 'Erreur: ${e.toString()}';
      _passengers = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // Mettre à jour un passager après embarquement
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
          meetingPoint: _currentTrip!.meetingPoint,
        );
      }
      
      notifyListeners();
    }
  }

  // Sélectionner un voyage
  void selectTrip(Trip trip) {
    _currentTrip = trip;
    notifyListeners();
  }

  // Changer la date sélectionnée
  void selectDate(DateTime date) {
    _selectedDate = date;
    loadTrips(date: date);
  }

  // Vider l'erreur
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Réinitialiser
  void reset() {
    _trips = [];
    _currentTrip = null;
    _passengers = [];
    _isLoading = false;
    _error = null;
    _selectedDate = DateTime.now();
    notifyListeners();
  }
}
