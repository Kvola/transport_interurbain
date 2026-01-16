import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/local_database.dart';
import '../services/connectivity_service.dart';
import '../config/api_config.dart';
import '../models/transport.dart';
import '../models/trip.dart';

/// Provider pour les voyages avec support offline
class TripProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocalDatabase _database = LocalDatabase();
  final ConnectivityService _connectivity = ConnectivityService();
  
  List<City> _cities = [];
  List<TransportCompany> _companies = [];
  List<Trip> _searchResults = [];
  List<Trip> _returnTrips = [];
  Trip? _selectedTrip;
  bool _isLoading = false;
  String? _error;
  bool _isFromCache = false;
  
  List<City> get cities => _cities;
  List<TransportCompany> get companies => _companies;
  List<Trip> get searchResults => _searchResults;
  List<Trip> get returnTrips => _returnTrips;
  Trip? get selectedTrip => _selectedTrip;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isFromCache => _isFromCache;
  
  /// Charger les villes (avec cache)
  Future<void> loadCities() async {
    if (_cities.isNotEmpty) return;
    
    _isLoading = true;
    notifyListeners();
    
    // D'abord essayer le cache
    final cachedCities = _database.getSetting<List>('cities_cache');
    if (cachedCities != null && cachedCities.isNotEmpty) {
      _cities = cachedCities.map((c) => City.fromJson(Map<String, dynamic>.from(c))).toList();
      _isFromCache = true;
      _isLoading = false;
      notifyListeners();
    }
    
    // Si en ligne, rafraîchir depuis le serveur
    if (_connectivity.isOnline) {
      try {
        final response = await _apiService.get(
          ApiConfig.citiesEndpoint,
          requireAuth: false,
        );
        
        if (response.isSuccess && response.data != null) {
          final List citiesJson = response.data['cities'] ?? [];
          _cities = citiesJson.map((c) => City.fromJson(c)).toList();
          _isFromCache = false;
          
          // Sauvegarder en cache
          await _database.saveSetting('cities_cache', citiesJson);
        }
      } catch (e) {
        if (_cities.isEmpty) {
          _error = 'Erreur chargement des villes: $e';
        }
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  /// Charger les compagnies (avec cache)
  Future<void> loadCompanies() async {
    if (_companies.isNotEmpty) return;
    
    // D'abord essayer le cache
    final cachedCompanies = _database.getSetting<List>('companies_cache');
    if (cachedCompanies != null && cachedCompanies.isNotEmpty) {
      _companies = cachedCompanies.map((c) => TransportCompany.fromJson(Map<String, dynamic>.from(c))).toList();
      notifyListeners();
    }
    
    // Si en ligne, rafraîchir
    if (_connectivity.isOnline) {
      try {
        final response = await _apiService.get(
          ApiConfig.companiesEndpoint,
          requireAuth: false,
        );
        
        if (response.isSuccess && response.data != null) {
          final List companiesJson = response.data['companies'] ?? [];
          _companies = companiesJson.map((c) => TransportCompany.fromJson(c)).toList();
          
          // Sauvegarder en cache
          await _database.saveSetting('companies_cache', companiesJson);
          notifyListeners();
        }
      } catch (e) {
        // Ignorer si on a déjà des données en cache
      }
    }
  }
  
  /// Rechercher des voyages (avec support offline)
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
    _isFromCache = false;
    notifyListeners();
    
    // Si hors ligne, utiliser le cache
    if (!_connectivity.isOnline) {
      _loadTripsFromCache(departureCityId, arrivalCityId, departureDate);
      return;
    }
    
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
        
        // Sauvegarder en cache
        await _database.saveTrips(tripsJson.map((e) => Map<String, dynamic>.from(e)).toList());
        
        // Voyages retour si demandé
        if (returnDate != null && response.data['return_trips'] != null) {
          final List returnJson = response.data['return_trips'];
          _returnTrips = returnJson.map((t) => Trip.fromJson(t)).toList();
        }
      } else {
        _error = response.message;
        // Fallback vers le cache
        _loadTripsFromCache(departureCityId, arrivalCityId, departureDate);
      }
    } catch (e) {
      _error = 'Erreur recherche: $e';
      // Fallback vers le cache
      _loadTripsFromCache(departureCityId, arrivalCityId, departureDate);
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  /// Charge les voyages depuis le cache local
  void _loadTripsFromCache(int departureCityId, int arrivalCityId, String departureDate) {
    final cachedTrips = _database.getCachedTrips();
    
    // Filtrer par critères de recherche
    _searchResults = cachedTrips
        .where((t) {
          return t['departure_city_id'] == departureCityId &&
                 t['arrival_city_id'] == arrivalCityId &&
                 (t['departure_date'] as String).startsWith(departureDate);
        })
        .map((t) => Trip.fromJson(t))
        .toList();
    
    _isFromCache = true;
    _isLoading = false;
    
    if (_searchResults.isEmpty && cachedTrips.isNotEmpty) {
      // Afficher tous les voyages en cache si pas de correspondance exacte
      _searchResults = cachedTrips.map((t) => Trip.fromJson(t)).toList();
      _error = 'Résultats depuis le cache (mode hors ligne)';
    }
    
    notifyListeners();
  }
  
  /// Obtenir les détails d'un voyage
  Future<Trip?> getTripDetails(int tripId) async {
    _isLoading = true;
    notifyListeners();
    
    // D'abord chercher en cache
    final cachedTrip = _database.getTripById(tripId);
    if (cachedTrip != null) {
      _selectedTrip = Trip.fromJson(cachedTrip);
      _isFromCache = true;
    }
    
    // Si en ligne, rafraîchir
    if (_connectivity.isOnline) {
      try {
        final response = await _apiService.get(
          '${ApiConfig.tripsEndpoint}/$tripId',
          requireAuth: false,
        );
        
        if (response.isSuccess && response.data != null) {
          _selectedTrip = Trip.fromJson(response.data['trip']);
          _isFromCache = false;
        }
      } catch (e) {
        if (_selectedTrip == null) {
          _error = 'Erreur: $e';
        }
      }
    }
    
    _isLoading = false;
    notifyListeners();
    return _selectedTrip;
  }
  
  /// Sélectionner un voyage
  void selectTrip(Trip trip) {
    _selectedTrip = trip;
    notifyListeners();
  }
  
  /// Effacer la sélection
  void clearSelection() {
    _selectedTrip = null;
    notifyListeners();
  }
  
  /// Effacer les résultats de recherche
  void clearSearchResults() {
    _searchResults = [];
    _returnTrips = [];
    _isFromCache = false;
    notifyListeners();
  }
  
  /// Vérifier si le cache est valide
  bool get hasCachedTrips => _database.isTripsCacheValid();
  
  /// Effacer l'erreur
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
