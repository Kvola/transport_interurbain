import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/scan_provider.dart';
import '../../providers/trip_provider.dart';
import '../../services/api_service.dart';
import '../../models/agent_models.dart';
import '../../theme/app_theme.dart';

class BoardingScreen extends StatefulWidget {
  final int bookingId;
  final String passengerName;

  const BoardingScreen({
    super.key,
    required this.bookingId,
    required this.passengerName,
  });

  @override
  State<BoardingScreen> createState() => _BoardingScreenState();
}

class _BoardingScreenState extends State<BoardingScreen> {
  Passenger? _passenger;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPassengerDetails();
  }

  Future<void> _loadPassengerDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      
      // Trouver le passager dans la liste
      _passenger = tripProvider.passengers.firstWhere(
        (p) => p.bookingId == widget.bookingId,
        orElse: () => throw Exception('Passager non trouvé'),
      );
    } catch (e) {
      _error = e.toString();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _boardPassenger() async {
    if (_passenger == null || _passenger!.isBoarded) return;

    final scanProvider = Provider.of<ScanProvider>(context, listen: false);
    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    final success = await scanProvider.boardPassenger(widget.bookingId);

    if (success && mounted) {
      tripProvider.updatePassengerBoarded(widget.bookingId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passager embarqué avec succès'),
          backgroundColor: AppTheme.scanSuccessColor,
        ),
      );
      
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(scanProvider.error ?? 'Erreur lors de l\'embarquement'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Embarquement'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(
                  message: _error!,
                  onRetry: _loadPassengerDetails,
                )
              : _passenger != null
                  ? _PassengerDetails(
                      passenger: _passenger!,
                      onBoard: _boardPassenger,
                    )
                  : const Center(child: Text('Passager non trouvé')),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassengerDetails extends StatelessWidget {
  final Passenger passenger;
  final VoidCallback onBoard;

  const _PassengerDetails({
    required this.passenger,
    required this.onBoard,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'fr_FR');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête avec statut
          Container(
            padding: const EdgeInsets.all(24),
            color: passenger.isBoarded
                ? AppTheme.boardedColor.withOpacity(0.1)
                : passenger.isPaid
                    ? AppTheme.paidColor.withOpacity(0.1)
                    : AppTheme.unpaidColor.withOpacity(0.1),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: passenger.isBoarded
                      ? AppTheme.boardedColor
                      : passenger.isPaid
                          ? AppTheme.paidColor
                          : AppTheme.unpaidColor,
                  child: Text(
                    passenger.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  passenger.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  passenger.phone,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                _StatusBadge(passenger: passenger),
              ],
            ),
          ),

          // Informations détaillées
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Infos billet
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informations du billet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 24),
                        _InfoRow(
                          icon: Icons.confirmation_number,
                          label: 'Référence',
                          value: passenger.bookingReference,
                        ),
                        _InfoRow(
                          icon: Icons.event_seat,
                          label: 'Siège',
                          value: passenger.seatNumber ?? 'Non attribué',
                        ),
                        _InfoRow(
                          icon: Icons.payment,
                          label: 'Mode de paiement',
                          value: _getPaymentMethodLabel(passenger.paymentMethod),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Infos paiement
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Paiement',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Montant payé'),
                            Text(
                              '${formatter.format(passenger.amountPaid)} FCFA',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.paidColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Montant dû'),
                            Text(
                              '${formatter.format(passenger.amountDue)} FCFA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: passenger.amountDue > 0
                                    ? AppTheme.unpaidColor
                                    : AppTheme.paidColor,
                              ),
                            ),
                          ],
                        ),
                        if (passenger.amountDue > 0) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.warningColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning,
                                  color: AppTheme.warningColor,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'À percevoir: ${formatter.format(passenger.amountDue)} FCFA',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.warningColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Historique embarquement si déjà embarqué
                if (passenger.isBoarded && passenger.boardingTime != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Embarquement',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: AppTheme.boardedColor,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Embarqué le ${DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(passenger.boardingTime!)}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bouton d'action
          Padding(
            padding: const EdgeInsets.all(16),
            child: Consumer<ScanProvider>(
              builder: (context, scanProvider, _) {
                if (passenger.isBoarded) {
                  return ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check),
                    label: const Text('Déjà embarqué'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  );
                }

                return ElevatedButton.icon(
                  onPressed: scanProvider.isProcessing ? null : onBoard,
                  icon: scanProvider.isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                    passenger.isPaid
                        ? 'Confirmer l\'embarquement'
                        : 'Embarquer (paiement à percevoir)',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: passenger.isPaid
                        ? AppTheme.accentColor
                        : AppTheme.warningColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getPaymentMethodLabel(String? method) {
    switch (method) {
      case 'wave':
        return 'Wave';
      case 'mobile_money':
        return 'Mobile Money';
      case 'cash':
        return 'Espèces';
      default:
        return method ?? 'Non spécifié';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final Passenger passenger;

  const _StatusBadge({required this.passenger});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    if (passenger.isBoarded) {
      color = AppTheme.boardedColor;
      label = 'Embarqué';
      icon = Icons.check_circle;
    } else if (passenger.isPaid) {
      color = AppTheme.paidColor;
      label = 'Payé - En attente d\'embarquement';
      icon = Icons.payment;
    } else {
      color = AppTheme.unpaidColor;
      label = 'Non payé';
      icon = Icons.money_off;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
