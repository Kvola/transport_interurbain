import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../config/api_config.dart';
import '../models/transport.dart';
import '../models/trip.dart';

/// Provider pour les voyages
class TripProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<City> _cities = [];
  List<TransportCompany> _companies = [];
  List<Trip> _searchResults = [];
  List<Trip> _returnTrips = [];
  Trip? _selectedTrip;
  bool _isLoading = false;
  String? _error;
  
  List<City> get cities => _cities;
  List<TransportCompany> get companies => _companies;
  List<Trip> get searchResults => _searchResults;
  List<Trip> get returnTrips => _returnTrips;
  Trip? get selectedTrip => _selectedTrip;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  /// Charger les villes
  Future<void> loadCities() async {
    if (_cities.isNotEmpty) return; // Déjà chargées
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _apiService.get(
        ApiConfig.citiesEndpoint,
        requireAuth: false,
      );
      
      if (response.isSuccess && response.data != null) {
        final List citiesJson = response.data['cities'] ?? [];
        _cities = citiesJson.map((c) => City.fromJson(c)).toList();
      }
    } catch (e) {
      _error = 'Erreur chargement des villes: $e';
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  /// Charger les compagnies
  Future<void> loadCompanies() async {
    if (_companies.isNotEmpty) return;
    
    try {
      final response = await _apiService.get(
        ApiConfig.companiesEndpoint,
        requireAuth: false,
      );
      
      if (response.isSuccess && response.data != null) {
        final List companiesJson = response.data['companies'] ?? [];
        _companies = companiesJson.map((c) => TransportCompany.fromJson(c)).toList();
        notifyListeners();
      }
    } catch (e) {
      // Ignorer
    }
  }
  
  /// Rechercher des voyages
  Future<void> searchTrips({
    required int departureCityId,
    required int arrivalCityId,
    required String departureDate,
    String? returnDate,
    int passengers = 1,
    int? companyId,
  }) async {
    _isLoading = true;
    _error = null;
    _searchResults = [];
    _returnTrips = [];
    notifyListeners();
    
    try {
      final body = {
        'departure_city_id': departureCityId,
        'arrival_city_id': arrivalCityId,
        'departure_date': departureDate,
        'passengers': passengers,
        if (returnDate != null) 'return_date': returnDate,
        if (companyId != null) 'company_id': companyId,
      };
      
      final response = await _apiService.post(
        ApiConfig.searchTripsEndpoint,
        body: body,
        requireAuth: false,
      );
      
      if (response.isSuccess && response.data != null) {
        final List tripsJson = response.data['trips'] ?? [];
        _searchResults = tripsJson.map((t) => Trip.fromJson(t)).toList();
        
        final List returnTripsJson = response.data['return_trips'] ?? [];
        _returnTrips = returnTripsJson.map((t) => Trip.fromJson(t)).toList();
      } else {
        _error = response.message;
      }
    } catch (e) {
      _error = 'Erreur de recherche: $e';
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  /// Obtenir les détails d'un voyage
  Future<Trip?> getTripDetails(int tripId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get(
        ApiConfig.tripDetailEndpoint(tripId),
        requireAuth: false,
      );
      
      if (response.isSuccess && response.data != null) {
        _selectedTrip = Trip.fromJson(response.data['trip']);
        _isLoading = false;
        notifyListeners();
        return _selectedTrip;
      }
      
      _error = response.message;
    } catch (e) {
      _error = 'Erreur: $e';
    }
    
    _isLoading = false;
    notifyListeners();
    return null;
  }
  
  /// Effacer les résultats de recherche
  void clearSearch() {
    _searchResults = [];
    _returnTrips = [];
    _selectedTrip = null;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
