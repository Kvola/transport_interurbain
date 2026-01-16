import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// États de connexion possibles
enum ConnectionStatus {
  online,   // Connecté et serveur accessible
  offline,  // Pas de connexion réseau
  serverUnavailable,  // Réseau OK mais serveur inaccessible
}

/// Service de surveillance de la connectivité
/// Détecte les changements de connexion et vérifie l'accessibilité du serveur
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  ConnectionStatus _status = ConnectionStatus.offline;
  ConnectionStatus get status => _status;
  
  bool get isOnline => _status == ConnectionStatus.online;
  bool get isOffline => _status == ConnectionStatus.offline;
  bool get isServerUnavailable => _status == ConnectionStatus.serverUnavailable;
  
  DateTime? _lastOnline;
  DateTime? get lastOnline => _lastOnline;
  
  /// Callbacks pour les changements de connexion
  final List<Function(ConnectionStatus)> _listeners = [];

  /// Initialise le service de connectivité
  Future<void> initialize() async {
    // Vérifier l'état initial
    await checkConnection();
    
    // Écouter les changements
    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  /// Appelé quand la connectivité change
  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    await checkConnection();
  }

  /// Vérifie la connexion réseau et l'accessibilité du serveur
  Future<ConnectionStatus> checkConnection() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    
    // Pas de connexion réseau
    if (connectivityResult.contains(ConnectivityResult.none) || connectivityResult.isEmpty) {
      _updateStatus(ConnectionStatus.offline);
      return _status;
    }
    
    // Vérifier si le serveur est accessible
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/transport/ping'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        _lastOnline = DateTime.now();
        _updateStatus(ConnectionStatus.online);
      } else {
        _updateStatus(ConnectionStatus.serverUnavailable);
      }
    } catch (e) {
      _updateStatus(ConnectionStatus.serverUnavailable);
    }
    
    return _status;
  }

  /// Met à jour le statut et notifie les listeners
  void _updateStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
      
      // Notifier les callbacks
      for (final listener in _listeners) {
        listener(newStatus);
      }
    }
  }

  /// Ajoute un callback pour les changements de connexion
  void addConnectionListener(Function(ConnectionStatus) listener) {
    _listeners.add(listener);
  }

  /// Retire un callback
  void removeConnectionListener(Function(ConnectionStatus) listener) {
    _listeners.remove(listener);
  }

  /// Force une vérification de la connexion
  Future<bool> forceCheck() async {
    final status = await checkConnection();
    return status == ConnectionStatus.online;
  }

  /// Retourne un message lisible pour l'état de connexion
  String get statusMessage {
    switch (_status) {
      case ConnectionStatus.online:
        return 'Connecté';
      case ConnectionStatus.offline:
        return 'Hors ligne';
      case ConnectionStatus.serverUnavailable:
        return 'Serveur inaccessible';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
