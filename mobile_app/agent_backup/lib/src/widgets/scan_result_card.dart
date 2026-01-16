import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Widget pour afficher le résultat d'un scan de ticket
class ScanResultCard extends StatelessWidget {
  final bool isValid;
  final String ticketNumber;
  final String passengerName;
  final String? passengerPhone;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureTime;
  final String seatNumber;
  final String status;
  final VoidCallback? onValidate;
  final VoidCallback? onClose;

  const ScanResultCard({
    super.key,
    required this.isValid,
    required this.ticketNumber,
    required this.passengerName,
    this.passengerPhone,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureTime,
    required this.seatNumber,
    required this.status,
    this.onValidate,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête avec statut
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isValid ? AppTheme.successColor : AppTheme.errorColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isValid ? Icons.check_circle : Icons.cancel,
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  isValid ? 'TICKET VALIDE' : 'TICKET INVALIDE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ticketNumber,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          // Corps avec informations
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Passager
                _buildInfoRow(
                  Icons.person,
                  'Passager',
                  passengerName,
                  isBold: true,
                ),
                if (passengerPhone != null)
                  _buildInfoRow(
                    Icons.phone,
                    'Téléphone',
                    passengerPhone!,
                  ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                
                // Trajet
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            Icons.trip_origin,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            departureCity,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.grey[400],
                      size: 32,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.red[400],
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            arrivalCity,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Date et siège
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        Icons.calendar_today,
                        'Départ',
                        _formatDateTime(departureTime),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        Icons.event_seat,
                        'Siège',
                        seatNumber,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Statut
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getStatusIcon(),
                        color: _getStatusColor(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Statut: ${_getStatusText()}',
                        style: TextStyle(
                          color: _getStatusColor(),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Actions
          if (isValid && status == 'confirmed')
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onClose,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Fermer'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onValidate,
                      icon: const Icon(Icons.check),
                      label: const Text('EMBARQUER'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Fermer'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[500], size: 20),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case 'confirmed':
        return AppTheme.successColor;
      case 'checked_in':
        return Colors.blue;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (status) {
      case 'confirmed':
        return Icons.check_circle;
      case 'checked_in':
        return Icons.directions_bus;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText() {
    switch (status) {
      case 'confirmed':
        return 'Confirmé - Prêt à embarquer';
      case 'checked_in':
        return 'Déjà embarqué';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}\n${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Widget pour les statistiques de voyage
class TripStatsCard extends StatelessWidget {
  final String tripName;
  final int totalSeats;
  final int bookedSeats;
  final int checkedInSeats;
  final double revenue;

  const TripStatsCard({
    super.key,
    required this.tripName,
    required this.totalSeats,
    required this.bookedSeats,
    required this.checkedInSeats,
    required this.revenue,
  });

  @override
  Widget build(BuildContext context) {
    final occupancyRate = (bookedSeats / totalSeats * 100).round();
    final checkInRate = bookedSeats > 0 
        ? (checkedInSeats / bookedSeats * 100).round() 
        : 0;

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tripName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$occupancyRate% rempli',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Barre de progression
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: bookedSeats / totalSeats,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: checkedInSeats / totalSeats,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.successColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Légende
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  color: AppTheme.successColor,
                  label: 'Embarqués',
                  value: checkedInSeats.toString(),
                ),
                _buildStatItem(
                  color: AppTheme.warningColor,
                  label: 'En attente',
                  value: (bookedSeats - checkedInSeats).toString(),
                ),
                _buildStatItem(
                  color: Colors.grey[300]!,
                  label: 'Disponibles',
                  value: (totalSeats - bookedSeats).toString(),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            
            // Revenus
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Revenus',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '${revenue.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Taux d'embarquement
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Taux d\'embarquement',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '$checkInRate%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: checkInRate >= 80 
                        ? AppTheme.successColor 
                        : checkInRate >= 50 
                            ? AppTheme.warningColor 
                            : AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
