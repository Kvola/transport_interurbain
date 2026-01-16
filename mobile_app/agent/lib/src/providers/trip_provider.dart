import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/trip.dart';

class TripProvider extends ChangeNotifier {
  final ApiService apiService;
  
  bool _isLoading = false;
  String? _error;
  List<Trip> _trips = [];
  Trip? _selectedTrip;
  List<Passenger> _passengers = [];
  
  TripProvider({required this.apiService});
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Trip> get trips => _trips;
  Trip? get selectedTrip => _selectedTrip;
  List<Passenger> get passengers => _passengers;
  
  Future<void> loadTodayTrips() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _trips = await apiService.getTodayTrips();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> selectTrip(Trip trip) async {
    _selectedTrip = trip;
    notifyListeners();
    await loadPassengers(trip.id);
  }
  
  Future<void> loadPassengers(int tripId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _passengers = await apiService.getTripPassengers(tripId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> refreshTrip() async {
    if (_selectedTrip == null) return;
    
    try {
      _selectedTrip = await apiService.getTripDetails(_selectedTrip!.id);
      await loadPassengers(_selectedTrip!.id);
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }
  
  void clearSelection() {
    _selectedTrip = null;
    _passengers = [];
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
