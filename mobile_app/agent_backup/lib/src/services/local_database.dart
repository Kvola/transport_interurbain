import 'package:hive_flutter/hive_flutter.dart';

/// Service de base de données locale avec Hive pour l'application Agent
/// Stocke les données pour le mode hors ligne
class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  // Noms des boxes
  static const String _agentBox = 'agent_data';
  static const String _tripsBox = 'trips_cache';
  static const String _passengersBox = 'passengers_cache';
  static const String _boardingsBox = 'boardings_cache';
  static const String _syncQueueBox = 'sync_queue';
  static const String _settingsBox = 'settings';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialise Hive et ouvre les boxes
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    
    // Ouvrir les boxes
    await Hive.openBox(_agentBox);
    await Hive.openBox<Map>(_tripsBox);
    await Hive.openBox<Map>(_passengersBox);
    await Hive.openBox<Map>(_boardingsBox);
    await Hive.openBox<Map>(_syncQueueBox);
    await Hive.openBox(_settingsBox);
    
    _isInitialized = true;
  }

  // ==================== AGENT DATA ====================

  /// Sauvegarde les données agent
  Future<void> saveAgentData(Map<String, dynamic> agentData) async {
    final box = Hive.box(_agentBox);
    await box.put('current_agent', agentData);
    await box.put('last_sync', DateTime.now().toIso8601String());
  }

  /// Récupère les données agent
  Map<String, dynamic>? getAgentData() {
    final box = Hive.box(_agentBox);
    final data = box.get('current_agent');
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// Sauvegarde le token d'authentification
  Future<void> saveAuthToken(String token) async {
    final box = Hive.box(_agentBox);
    await box.put('auth_token', token);
  }

  /// Récupère le token d'authentification
  String? getAuthToken() {
    final box = Hive.box(_agentBox);
    return box.get('auth_token');
  }

  /// Efface les données agent (déconnexion)
  Future<void> clearAgentData() async {
    final box = Hive.box(_agentBox);
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

  /// Vérifie si le cache des voyages est valide (moins de 15 minutes pour l'agent)
  bool isTripsCacheValid() {
    final settingsBox = Hive.box(_settingsBox);
    final cachedAt = settingsBox.get('trips_cached_at');
    
    if (cachedAt == null) return false;
    
    final cacheTime = DateTime.parse(cachedAt);
    final now = DateTime.now();
    
    // Cache valide 15 minutes pour l'agent (données plus sensibles)
    return now.difference(cacheTime).inMinutes < 15;
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

  // ==================== PASSENGERS CACHE ====================

  /// Sauvegarde les passagers d'un voyage
  Future<void> savePassengers(int tripId, List<Map<String, dynamic>> passengers) async {
    final box = Hive.box<Map>(_passengersBox);
    
    // Stocker avec clé composée trip_id + passenger
    for (final passenger in passengers) {
      final key = '${tripId}_${passenger['booking_id']}';
      await box.put(key, {
        'trip_id': tripId,
        ...passenger,
      });
    }
    
    // Marquer le cache des passagers pour ce voyage
    final settingsBox = Hive.box(_settingsBox);
    await settingsBox.put('passengers_${tripId}_cached_at', DateTime.now().toIso8601String());
  }

  /// Récupère les passagers d'un voyage
  List<Map<String, dynamic>> getCachedPassengers(int tripId) {
    final box = Hive.box<Map>(_passengersBox);
    return box.values
        .where((e) => e['trip_id'] == tripId)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Met à jour le statut d'embarquement d'un passager localement
  Future<void> updatePassengerBoarded(int tripId, int bookingId, bool isBoarded, DateTime? boardingTime) async {
    final box = Hive.box<Map>(_passengersBox);
    final key = '${tripId}_$bookingId';
    
    final existing = box.get(key);
    if (existing != null) {
      final updated = Map<String, dynamic>.from(existing);
      updated['is_boarded'] = isBoarded;
      updated['boarding_time'] = boardingTime?.toIso8601String();
      await box.put(key, updated);
    }
  }

  /// Vérifie si le cache des passagers est valide pour un voyage
  bool isPassengersCacheValid(int tripId) {
    final settingsBox = Hive.box(_settingsBox);
    final cachedAt = settingsBox.get('passengers_${tripId}_cached_at');
    
    if (cachedAt == null) return false;
    
    final cacheTime = DateTime.parse(cachedAt);
    final now = DateTime.now();
    
    // Cache valide 10 minutes pour les passagers
    return now.difference(cacheTime).inMinutes < 10;
  }

  // ==================== BOARDINGS OFFLINE ====================

  /// Enregistre un embarquement effectué hors ligne
  Future<void> saveOfflineBoarding(Map<String, dynamic> boarding) async {
    final box = Hive.box<Map>(_boardingsBox);
    await box.put(boarding['booking_id'].toString(), boarding);
  }

  /// Récupère les embarquements effectués hors ligne
  List<Map<String, dynamic>> getOfflineBoardings() {
    final box = Hive.box<Map>(_boardingsBox);
    return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Supprime un embarquement synchronisé
  Future<void> removeOfflineBoarding(int bookingId) async {
    final box = Hive.box<Map>(_boardingsBox);
    await box.delete(bookingId.toString());
  }

  /// Vide les embarquements offline
  Future<void> clearOfflineBoardings() async {
    final box = Hive.box<Map>(_boardingsBox);
    await box.clear();
  }

  /// Nombre d'embarquements en attente de sync
  int get pendingBoardingsCount {
    final box = Hive.box<Map>(_boardingsBox);
    return box.length;
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
    await Hive.box(_agentBox).clear();
    await Hive.box<Map>(_tripsBox).clear();
    await Hive.box<Map>(_passengersBox).clear();
    await Hive.box<Map>(_boardingsBox).clear();
    await Hive.box<Map>(_syncQueueBox).clear();
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

/// Types d'actions à synchroniser pour l'agent
enum SyncActionType {
  boardPassenger,       // Embarquer un passager
  boardMultiple,        // Embarquer plusieurs passagers
  verifyPayment,        // Vérifier/confirmer un paiement
}
