import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/connectivity_service.dart';

/// Widget qui affiche un indicateur de connexion en haut de l'écran
class ConnectionIndicator extends StatelessWidget {
  final Widget child;
  final bool showWhenOnline;

  const ConnectionIndicator({
    super.key,
    required this.child,
    this.showWhenOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: ConnectivityService(),
      child: Consumer<ConnectivityService>(
        builder: (context, connectivity, _) {
          return Column(
            children: [
              // Bande d'état de connexion
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: (!connectivity.isOnline || showWhenOnline) ? null : 0,
                child: _ConnectionBanner(status: connectivity.status),
              ),
              // Contenu principal
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  final ConnectionStatus status;

  const _ConnectionBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    IconData icon;
    String message;

    switch (status) {
      case ConnectionStatus.online:
        backgroundColor = Colors.green;
        icon = Icons.wifi;
        message = 'Connecté';
        break;
      case ConnectionStatus.offline:
        backgroundColor = Colors.red.shade700;
        icon = Icons.wifi_off;
        message = 'Hors ligne - Mode déconnecté';
        break;
      case ConnectionStatus.serverUnavailable:
        backgroundColor = Colors.orange.shade700;
        icon = Icons.cloud_off;
        message = 'Serveur inaccessible';
        break;
    }

    return Material(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge de synchronisation à afficher dans l'AppBar
class SyncBadge extends StatelessWidget {
  final int pendingCount;
  final VoidCallback? onTap;

  const SyncBadge({
    super.key,
    required this.pendingCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingCount <= 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              '$pendingCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicateur de mode offline pour les cartes/listes
class OfflineIndicator extends StatelessWidget {
  final bool isFromCache;

  const OfflineIndicator({super.key, required this.isFromCache});

  @override
  Widget build(BuildContext context) {
    if (!isFromCache) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.offline_bolt, color: Colors.grey.shade600, size: 12),
          const SizedBox(width: 4),
          Text(
            'Cache',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton de synchronisation manuelle
class SyncButton extends StatefulWidget {
  final Future<void> Function() onSync;
  final bool showLabel;

  const SyncButton({
    super.key,
    required this.onSync,
    this.showLabel = true,
  });

  @override
  State<SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);
    _controller.repeat();

    try {
      await widget.onSync();
    } finally {
      _controller.stop();
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivity, _) {
        final isEnabled = connectivity.isOnline && !_isSyncing;

        if (widget.showLabel) {
          return ElevatedButton.icon(
            onPressed: isEnabled ? _sync : null,
            icon: RotationTransition(
              turns: _controller,
              child: const Icon(Icons.sync),
            ),
            label: Text(_isSyncing ? 'Synchronisation...' : 'Synchroniser'),
          );
        }

        return IconButton(
          onPressed: isEnabled ? _sync : null,
          icon: RotationTransition(
            turns: _controller,
            child: const Icon(Icons.sync),
          ),
          tooltip: 'Synchroniser',
        );
      },
    );
  }
}

/// Wrapper pour afficher un message quand les données viennent du cache
class CacheDataBanner extends StatelessWidget {
  final bool isFromCache;
  final DateTime? lastSyncTime;
  final VoidCallback? onRefresh;
  final Widget child;

  const CacheDataBanner({
    super.key,
    required this.isFromCache,
    this.lastSyncTime,
    this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isFromCache) return child;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.amber.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber.shade800, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lastSyncTime != null
                      ? 'Données en cache (dernière sync: ${_formatTime(lastSyncTime!)})'
                      : 'Données en cache',
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontSize: 12,
                  ),
                ),
              ),
              if (onRefresh != null)
                Consumer<ConnectivityService>(
                  builder: (context, connectivity, _) {
                    return TextButton(
                      onPressed: connectivity.isOnline ? onRefresh : null,
                      child: const Text('Actualiser'),
                    );
                  },
                ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'à l\'instant';
    } else if (diff.inMinutes < 60) {
      return 'il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'il y a ${diff.inHours}h';
    } else {
      return 'il y a ${diff.inDays}j';
    }
  }
}
