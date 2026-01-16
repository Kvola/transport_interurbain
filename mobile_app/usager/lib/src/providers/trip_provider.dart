import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/trip.dart';

class TripProvider extends ChangeNotifier {
  final ApiService apiService;
  
  bool _isLoading = false;
  String? _error;
  List<Trip> _trips = [];
  List<City> _cities = [];
  Trip? _selectedTrip;
  
  TripProvider({required this.apiService});
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Trip> get trips => _trips;
  List<City> get cities => _cities;
  Trip? get selectedTrip => _selectedTrip;
  
  Future<void> loadCities() async {
    if (_cities.isNotEmpty) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final citiesData = await apiService.getCities();
      _cities = citiesData.map((c) => City.fromJson(c)).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> searchTrips({
    required int departureId,
    required int arrivalId,
    required String date,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _trips = await apiService.searchTrips(
        departureId: departureId,
        arrivalId: arrivalId,
        date: date,
      );
    } catch (e) {
      _error = e.toString();
      _trips = [];
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> loadTripDetails(int tripId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _selectedTrip = await apiService.getTripDetails(tripId);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  void selectTrip(Trip trip) {
    _selectedTrip = trip;
    notifyListeners();
  }
  
  void clearTrips() {
    _trips = [];
    _selectedTrip = null;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
