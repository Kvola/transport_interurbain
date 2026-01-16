import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

/// Widget qui affiche un indicateur de connexion en haut de l'écran (Agent)
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
        backgroundColor = AppTheme.scanSuccessColor;
        icon = Icons.wifi;
        message = 'Connecté';
        break;
      case ConnectionStatus.offline:
        backgroundColor = AppTheme.scanErrorColor;
        icon = Icons.wifi_off;
        message = 'Mode hors ligne - Les scans seront synchronisés';
        break;
      case ConnectionStatus.serverUnavailable:
        backgroundColor = AppTheme.scanWarningColor;
        icon = Icons.cloud_off;
        message = 'Serveur inaccessible - Mode dégradé';
        break;
    }

    return Material(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Badge de synchronisation pour l'AppBar agent
class SyncStatusBadge extends StatelessWidget {
  final VoidCallback? onTap;

  const SyncStatusBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: SyncService(),
      child: Consumer<SyncService>(
        builder: (context, syncService, _) {
          final pendingCount = syncService.pendingBoardings;
          
          if (pendingCount <= 0 && !syncService.isSyncing) {
            return const SizedBox.shrink();
          }

          return GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: syncService.isSyncing 
                    ? AppTheme.accentColor 
                    : AppTheme.scanWarningColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (syncService.isSyncing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    const Icon(Icons.sync_problem, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    syncService.isSyncing 
                        ? 'Sync...' 
                        : '$pendingCount en attente',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Indicateur de scan offline
class OfflineScanIndicator extends StatelessWidget {
  const OfflineScanIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.scanWarningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.scanWarningColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.offline_bolt, color: AppTheme.scanWarningColor, size: 16),
          const SizedBox(width: 6),
          Text(
            'Scan hors ligne',
            style: TextStyle(
              color: AppTheme.scanWarningColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton de synchronisation pour l'agent
class AgentSyncButton extends StatefulWidget {
  final bool showLabel;
  final Color? iconColor;

  const AgentSyncButton({
    super.key,
    this.showLabel = false,
    this.iconColor,
  });

  @override
  State<AgentSyncButton> createState() => _AgentSyncButtonState();
}

class _AgentSyncButtonState extends State<AgentSyncButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

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

  @override
  Widget build(BuildContext context) {
    final connectivity = ConnectivityService();
    final syncService = SyncService();

    return ListenableBuilder(
      listenable: Listenable.merge([connectivity, syncService]),
      builder: (context, _) {
        final isSyncing = syncService.isSyncing;
        final isOnline = connectivity.isOnline;

        if (isSyncing) {
          _controller.repeat();
        } else {
          _controller.stop();
        }

        if (widget.showLabel) {
          return ElevatedButton.icon(
            onPressed: isOnline && !isSyncing 
                ? () => syncService.syncAll() 
                : null,
            icon: RotationTransition(
              turns: _controller,
              child: Icon(Icons.sync, color: widget.iconColor),
            ),
            label: Text(isSyncing ? 'Synchronisation...' : 'Synchroniser'),
          );
        }

        return IconButton(
          onPressed: isOnline && !isSyncing 
              ? () => syncService.syncAll() 
              : null,
          icon: RotationTransition(
            turns: _controller,
            child: Icon(
              Icons.sync, 
              color: widget.iconColor ?? (isOnline ? null : Colors.grey),
            ),
          ),
          tooltip: isSyncing ? 'Synchronisation en cours...' : 'Synchroniser',
        );
      },
    );
  }
}

/// Carte d'info pour le mode hors ligne sur l'écran d'accueil
class OfflineModeCard extends StatelessWidget {
  final int pendingBoardings;
  final VoidCallback? onSync;

  const OfflineModeCard({
    super.key,
    required this.pendingBoardings,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.scanWarningColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi_off, color: AppTheme.scanWarningColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Mode hors ligne',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              pendingBoardings > 0
                  ? 'Vous avez $pendingBoardings embarquement(s) en attente de synchronisation.'
                  : 'Vous pouvez continuer à scanner les passagers. Les données seront synchronisées automatiquement.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            if (pendingBoardings > 0 && onSync != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Consumer<ConnectivityService>(
                  builder: (context, connectivity, _) {
                    return ElevatedButton.icon(
                      onPressed: connectivity.isOnline ? onSync : null,
                      icon: const Icon(Icons.sync),
                      label: const Text('Synchroniser maintenant'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
