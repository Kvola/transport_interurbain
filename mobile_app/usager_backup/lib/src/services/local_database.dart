import 'package:hive_flutter/hive_flutter.dart';

/// Service de base de données locale avec Hive
/// Stocke les données pour le mode hors ligne
class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  // Noms des boxes
  static const String _userBox = 'user_data';
  static const String _tripsBox = 'trips_cache';
  static const String _bookingsBox = 'bookings_cache';
  static const String _ticketsBox = 'tickets_cache';
  static const String _syncQueueBox = 'sync_queue';
  static const String _settingsBox = 'settings';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialise Hive et ouvre les boxes
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    
    // Ouvrir les boxes
    await Hive.openBox(_userBox);
    await Hive.openBox<Map>(_tripsBox);
    await Hive.openBox<Map>(_bookingsBox);
    await Hive.openBox<Map>(_ticketsBox);
    await Hive.openBox<Map>(_syncQueueBox);
    await Hive.openBox(_settingsBox);
    
    _isInitialized = true;
  }

  // ==================== USER DATA ====================

  /// Sauvegarde les données utilisateur
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final box = Hive.box(_userBox);
    await box.put('current_user', userData);
    await box.put('last_sync', DateTime.now().toIso8601String());
  }

  /// Récupère les données utilisateur
  Map<String, dynamic>? getUserData() {
    final box = Hive.box(_userBox);
    final data = box.get('current_user');
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// Sauvegarde le token d'authentification
  Future<void> saveAuthToken(String token) async {
    final box = Hive.box(_userBox);
    await box.put('auth_token', token);
  }

  /// Récupère le token d'authentification
  String? getAuthToken() {
    final box = Hive.box(_userBox);
    return box.get('auth_token');
  }

  /// Efface les données utilisateur (déconnexion)
  Future<void> clearUserData() async {
    final box = Hive.box(_userBox);
    await box.clear();
  }

  // ==================== TRIPS CACHE ====================

  /// Sauvegarde les voyages en cache
  Future<void> saveTrips(List<Map<String, dynamic>> trips) async {
    final box = Hive.box<Map>(_tripsBox);
    await box.clear();
    
    for (final trip in trips) {
      await box.put(trip['id'].toString(), trip);
    }
    
    // Enregistrer la date de mise en cache
    final settingsBox = Hive.box(_settingsBox);
    await settingsBox.put('trips_cached_at', DateTime.now().toIso8601String());
  }

  /// Récupère les voyages du cache
  List<Map<String, dynamic>> getCachedTrips() {
    final box = Hive.box<Map>(_tripsBox);
    return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Vérifie si le cache des voyages est valide (moins de 30 minutes)
  bool isTripsCacheValid() {
    final settingsBox = Hive.box(_settingsBox);
    final cachedAt = settingsBox.get('trips_cached_at');
    
    if (cachedAt == null) return false;
    
    final cacheTime = DateTime.parse(cachedAt);
    final now = DateTime.now();
    
    return now.difference(cacheTime).inMinutes < 30;
  }

  /// Récupère un voyage par ID
  Map<String, dynamic>? getTripById(int tripId) {
    final box = Hive.box<Map>(_tripsBox);
    final data = box.get(tripId.toString());
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  // ==================== BOOKINGS CACHE ====================

  /// Sauvegarde les réservations en cache
  Future<void> saveBookings(List<Map<String, dynamic>> bookings) async {
    final box = Hive.box<Map>(_bookingsBox);
    await box.clear();
    
    for (final booking in bookings) {
      await box.put(booking['id'].toString(), booking);
    }
    
    final settingsBox = Hive.box(_settingsBox);
    await settingsBox.put('bookings_cached_at', DateTime.now().toIso8601String());
  }

  /// Récupère les réservations du cache
  List<Map<String, dynamic>> getCachedBookings() {
    final box = Hive.box<Map>(_bookingsBox);
    return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Ajoute une réservation au cache
  Future<void> addBookingToCache(Map<String, dynamic> booking) async {
    final box = Hive.box<Map>(_bookingsBox);
    await box.put(booking['id'].toString(), booking);
  }

  // ==================== TICKETS CACHE ====================

  /// Sauvegarde les billets en cache
  Future<void> saveTickets(List<Map<String, dynamic>> tickets) async {
    final box = Hive.box<Map>(_ticketsBox);
    await box.clear();
    
    for (final ticket in tickets) {
      await box.put(ticket['id'].toString(), ticket);
    }
  }

  /// Récupère les billets du cache
  List<Map<String, dynamic>> getCachedTickets() {
    final box = Hive.box<Map>(_ticketsBox);
    return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Récupère un billet par ID
  Map<String, dynamic>? getTicketById(int ticketId) {
    final box = Hive.box<Map>(_ticketsBox);
    final data = box.get(ticketId.toString());
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  // ==================== SYNC QUEUE ====================

  /// Ajoute une action à la file de synchronisation
  Future<void> addToSyncQueue(SyncAction action) async {
    final box = Hive.box<Map>(_syncQueueBox);
    await box.put(action.id, action.toMap());
  }

  /// Récupère toutes les actions en attente
  List<SyncAction> getPendingSyncActions() {
    final box = Hive.box<Map>(_syncQueueBox);
    return box.values.map((e) => SyncAction.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  /// Supprime une action de la file
  Future<void> removeSyncAction(String actionId) async {
    final box = Hive.box<Map>(_syncQueueBox);
    await box.delete(actionId);
  }

  /// Vide la file de synchronisation
  Future<void> clearSyncQueue() async {
    final box = Hive.box<Map>(_syncQueueBox);
    await box.clear();
  }

  /// Nombre d'actions en attente
  int get pendingSyncCount {
    final box = Hive.box<Map>(_syncQueueBox);
    return box.length;
  }

  // ==================== SETTINGS ====================

  /// Sauvegarde un paramètre
  Future<void> saveSetting(String key, dynamic value) async {
    final box = Hive.box(_settingsBox);
    await box.put(key, value);
  }

  /// Récupère un paramètre
  T? getSetting<T>(String key) {
    final box = Hive.box(_settingsBox);
    return box.get(key) as T?;
  }

  /// Dernière synchronisation
  DateTime? get lastSyncTime {
    final settingsBox = Hive.box(_settingsBox);
    final lastSync = settingsBox.get('last_full_sync');
    if (lastSync != null) {
      return DateTime.parse(lastSync);
    }
    return null;
  }

  /// Enregistre l'heure de la dernière synchronisation
  Future<void> setLastSyncTime(DateTime time) async {
    final settingsBox = Hive.box(_settingsBox);
    await settingsBox.put('last_full_sync', time.toIso8601String());
  }

  // ==================== CLEANUP ====================

  /// Efface toutes les données locales
  Future<void> clearAll() async {
    await Hive.box(_userBox).clear();
    await Hive.box<Map>(_tripsBox).clear();
    await Hive.box<Map>(_bookingsBox).clear();
    await Hive.box<Map>(_ticketsBox).clear();
    await Hive.box<Map>(_syncQueueBox).clear();
    // Ne pas effacer les settings
  }

  /// Ferme toutes les boxes
  Future<void> close() async {
    await Hive.close();
    _isInitialized = false;
  }
}

/// Action à synchroniser quand la connexion revient
class SyncAction {
  final String id;
  final SyncActionType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;

  SyncAction({
    required this.id,
    required this.type,
    required this.data,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'data': data,
    'created_at': createdAt.toIso8601String(),
    'retry_count': retryCount,
  };

  factory SyncAction.fromMap(Map<String, dynamic> map) => SyncAction(
    id: map['id'],
    type: SyncActionType.values.firstWhere((e) => e.name == map['type']),
    data: Map<String, dynamic>.from(map['data']),
    createdAt: DateTime.parse(map['created_at']),
    retryCount: map['retry_count'] ?? 0,
  );
}

/// Types d'actions à synchroniser
enum SyncActionType {
  createBooking,
  cancelBooking,
  updateProfile,
  confirmPayment,
}
