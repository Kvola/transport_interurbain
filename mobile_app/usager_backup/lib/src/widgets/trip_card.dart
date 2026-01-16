import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Card amélioré pour afficher un voyage
class TripCard extends StatelessWidget {
  final String companyName;
  final String? companyLogo;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureTime;
  final double price;
  final int availableSeats;
  final String? busType;
  final bool hasWifi;
  final bool hasAC;
  final VoidCallback? onTap;
  final bool isSelected;

  const TripCard({
    super.key,
    required this.companyName,
    this.companyLogo,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureTime,
    required this.price,
    required this.availableSeats,
    this.busType,
    this.hasWifi = false,
    this.hasAC = false,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? const BorderSide(color: AppTheme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête compagnie
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: companyLogo != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              companyLogo!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.directions_bus,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.directions_bus,
                            color: AppTheme.primaryColor,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (busType != null)
                          Text(
                            busType!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildAvailabilityBadge(),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              
              // Trajet
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatTime(departureTime),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          departureCity,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.grey[400],
                      ),
                      Text(
                        _formatDate(departureTime),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '---',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          arrivalCity,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Pied avec prix et options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (hasWifi)
                        _buildFeatureIcon(Icons.wifi, 'WiFi'),
                      if (hasAC)
                        _buildFeatureIcon(Icons.ac_unit, 'Climatisation'),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${price.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                        ),
                      ),
                      Text(
                        'par personne',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityBadge() {
    Color bgColor;
    Color textColor;
    String text;

    if (availableSeats == 0) {
      bgColor = Colors.red[50]!;
      textColor = Colors.red;
      text = 'Complet';
    } else if (availableSeats <= 5) {
      bgColor = Colors.orange[50]!;
      textColor = Colors.orange;
      text = '$availableSeats places';
    } else {
      bgColor = Colors.green[50]!;
      textColor = Colors.green;
      text = '$availableSeats places';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
                   'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}

/// Card pour afficher un ticket de réservation
class TicketCard extends StatelessWidget {
  final String ticketNumber;
  final String passengerName;
  final String departureCity;
  final String arrivalCity;
  final DateTime departureTime;
  final String seatNumber;
  final String status;
  final VoidCallback? onTap;
  final VoidCallback? onShare;

  const TicketCard({
    super.key,
    required this.ticketNumber,
    required this.passengerName,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureTime,
    required this.seatNumber,
    required this.status,
    this.onTap,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.confirmation_number,
                        color: _getStatusColor(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        ticketNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _getStatusColor(),
                        ),
                      ),
                    ],
                  ),
                  _buildStatusBadge(),
                ],
              ),
            ),
            
            // Corps
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Passager
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.grey[500], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        passengerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Trajet
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.trip_origin,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              departureCity,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                5,
                                (i) => Container(
                                  width: 6,
                                  height: 2,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  color: Colors.grey[300],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDateTime(departureTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.red[400],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              arrivalCity,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Pied
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_seat, color: Colors.grey[500], size: 20),
                          const SizedBox(width: 4),
                          Text(
                            'Siège $seatNumber',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      if (onShare != null && status == 'confirmed')
                        IconButton(
                          onPressed: onShare,
                          icon: const Icon(Icons.share),
                          color: AppTheme.primaryColor,
                          tooltip: 'Partager le ticket',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getStatusText(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case 'confirmed':
        return AppTheme.successColor;
      case 'reserved':
        return AppTheme.warningColor;
      case 'checked_in':
        return Colors.blue;
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (status) {
      case 'confirmed':
        return 'Confirmé';
      case 'reserved':
        return 'Réservé';
      case 'checked_in':
        return 'Embarqué';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime dt) {
    const weekdays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return '${weekdays[dt.weekday - 1]} ${dt.day}/${dt.month} à ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
