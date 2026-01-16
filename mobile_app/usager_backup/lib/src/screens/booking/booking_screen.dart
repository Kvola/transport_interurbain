import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/trip_provider.dart';
import '../../providers/booking_provider.dart';
import '../../models/trip.dart';
import '../../models/transport.dart';
import '../../models/booking.dart';
import '../../theme/app_theme.dart';
import '../../widgets/other_passenger_form.dart';

class BookingScreen extends StatefulWidget {
  final int tripId;

  const BookingScreen({super.key, required this.tripId});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Trip? _trip;
  final Set<int> _selectedSeats = {};
  String _paymentMethod = 'wave';
  final _formKey = GlobalKey<FormState>();
  final List<Map<String, TextEditingController>> _passengerControllers = [];
  
  // État pour l'achat pour un tiers
  bool _isForOther = false;
  OtherPassenger? _otherPassenger;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  @override
  void dispose() {
    for (final controllers in _passengerControllers) {
      controllers['name']?.dispose();
      controllers['phone']?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTrip() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final trip = await tripProvider.getTripDetails(widget.tripId);
    if (mounted && trip != null) {
      setState(() {
        _trip = trip;
      });
    }
  }

  void _toggleSeat(Seat seat) {
    if (!seat.isAvailable) return;
    
    setState(() {
      if (_selectedSeats.contains(seat.id)) {
        _selectedSeats.remove(seat.id);
        _passengerControllers.removeLast();
      } else if (_selectedSeats.length < 10) {
        _selectedSeats.add(seat.id);
        _passengerControllers.add({
          'name': TextEditingController(),
          'phone': TextEditingController(),
        });
      }
    });
  }

  /// Afficher le choix entre "pour moi" et "pour quelqu'un d'autre"
  void _showBookingTypeChoice() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingTypeSheet(
        onForSelf: () {
          setState(() {
            _isForOther = false;
            _otherPassenger = null;
          });
          _proceedToPayment();
        },
        onForOther: () {
          _showOtherPassengerForm();
        },
      ),
    );
  }

  /// Afficher le formulaire pour saisir les infos du passager tiers
  void _showOtherPassengerForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: OtherPassengerForm(
            initialData: _otherPassenger,
            onSaved: (passenger) {
              Navigator.pop(context);
              setState(() {
                _isForOther = true;
                _otherPassenger = passenger;
              });
              _proceedToPayment();
            },
            onCancel: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  /// Procéder au paiement après validation
  void _proceedToPayment() {
    _confirmBooking();
  }

  double get _totalPrice {
    if (_trip == null) return 0;
    return _trip!.price * _selectedSeats.length;
  }

  Future<void> _confirmBooking() async {
    if (_selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner au moins un siège'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // Vérifier les infos du passager tiers si applicable
    if (_isForOther && (_otherPassenger == null || !_otherPassenger!.isValid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez compléter les informations du passager'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final passengers = <Map<String, String>>[];
    for (int i = 0; i < _passengerControllers.length; i++) {
      passengers.add({
        'name': _passengerControllers[i]['name']!.text,
        'phone': _passengerControllers[i]['phone']!.text,
        'seat_id': _selectedSeats.elementAt(i).toString(),
      });
    }

    final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
    final success = await bookingProvider.createBooking(
      tripId: widget.tripId,
      seatIds: _selectedSeats.toList(),
      passengers: passengers,
      paymentMethod: _paymentMethod,
      forOther: _isForOther,
      otherPassenger: _otherPassenger,
    );

    if (success && mounted) {
      // Rediriger vers la page de paiement ou de confirmation
      Navigator.pushReplacementNamed(
        context,
        '/booking/payment',
        arguments: {'bookingId': bookingProvider.lastBookingId},
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bookingProvider.error ?? 'Erreur lors de la réservation'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Réservation')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réservation'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Résumé du voyage
            _TripSummaryCard(trip: _trip!),
            
            // Option achat pour tiers
            if (_selectedSeats.isNotEmpty)
              _ForOtherSection(
                isForOther: _isForOther,
                otherPassenger: _otherPassenger,
                onToggle: (value) {
                  if (value) {
                    _showOtherPassengerForm();
                  } else {
                    setState(() {
                      _isForOther = false;
                      _otherPassenger = null;
                    });
                  }
                },
                onEdit: _showOtherPassengerForm,
              ),
            
            // Sélection des sièges
            _SeatSelectionSection(
              trip: _trip!,
              selectedSeats: _selectedSeats,
              onSeatTap: _toggleSeat,
            ),
            
            // Informations des passagers
            if (_selectedSeats.isNotEmpty)
              _PassengerInfoSection(
                formKey: _formKey,
                passengerCount: _selectedSeats.length,
                controllers: _passengerControllers,
              ),
            
            // Méthode de paiement
            if (_selectedSeats.isNotEmpty)
              _PaymentMethodSection(
                selectedMethod: _paymentMethod,
                onSelect: (method) {
                  setState(() => _paymentMethod = method);
                },
              ),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: _selectedSeats.isNotEmpty
          ? _BookingBottomBar(
              totalPrice: _totalPrice,
              seatCount: _selectedSeats.length,
              onConfirm: _confirmBooking,
              isLoading: context.watch<BookingProvider>().isLoading,
              isForOther: _isForOther,
              otherPassengerName: _otherPassenger?.name,
            )
          : null,
    );
  }
}

class _TripSummaryCard extends StatelessWidget {
  final Trip trip;

  const _TripSummaryCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.departureTime ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    trip.route.departureCity.name,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              Column(
                children: [
                  const Icon(Icons.arrow_forward, color: Colors.white),
                  Text(
                    '${trip.route.durationHours?.toStringAsFixed(1) ?? '-'}h',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trip.arrivalDatetime ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    trip.route.arrivalCity.name,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.directions_bus, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                trip.company.name,
                style: const TextStyle(color: Colors.white70),
              ),
              const Spacer(),
              Text(
                trip.formattedPrice + ' / place',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Section pour choisir d'acheter pour soi ou pour quelqu'un d'autre
class _ForOtherSection extends StatelessWidget {
  final bool isForOther;
  final OtherPassenger? otherPassenger;
  final Function(bool) onToggle;
  final VoidCallback onEdit;

  const _ForOtherSection({
    required this.isForOther,
    this.otherPassenger,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    color: AppTheme.accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acheter pour quelqu\'un d\'autre',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Offrez un voyage à un proche',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isForOther,
                  onChanged: onToggle,
                  activeColor: AppTheme.accentColor,
                ),
              ],
            ),
            
            // Afficher les infos du passager tiers si sélectionné
            if (isForOther && otherPassenger != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.accentColor.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.accentColor,
                      radius: 20,
                      child: Text(
                        otherPassenger!.name.isNotEmpty 
                            ? otherPassenger!.name[0].toUpperCase() 
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            otherPassenger!.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            otherPassenger!.phone,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (otherPassenger!.email != null)
                            Text(
                              otherPassenger!.email!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: Icon(
                        Icons.edit,
                        color: AppTheme.accentColor,
                      ),
                      tooltip: 'Modifier',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    trip.route.departureCity.name,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              Column(
                children: [
                  const Icon(Icons.arrow_forward, color: Colors.white),
                  Text(
                    '${trip.route.durationHours?.toStringAsFixed(1) ?? '-'}h',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trip.arrivalDatetime ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    trip.route.arrivalCity.name,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.directions_bus, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(
                trip.company.name,
                style: const TextStyle(color: Colors.white70),
              ),
              const Spacer(),
              Text(
                trip.formattedPrice + ' / place',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeatSelectionSection extends StatelessWidget {
  final Trip trip;
  final Set<int> selectedSeats;
  final Function(Seat) onSeatTap;

  const _SeatSelectionSection({
    required this.trip,
    required this.selectedSeats,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sélectionnez vos sièges',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${trip.availableSeats} places disponibles',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            
            // Légende
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: Colors.grey[300]!, label: 'Disponible'),
                const SizedBox(width: 16),
                _LegendItem(color: AppTheme.primaryColor, label: 'Sélectionné'),
                const SizedBox(width: 16),
                _LegendItem(color: Colors.grey[500]!, label: 'Occupé'),
              ],
            ),
            const SizedBox(height: 24),
            
            // Grille des sièges
            _SeatGrid(
              bus: trip.bus,
              selectedSeats: selectedSeats,
              onSeatTap: onSeatTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _SeatGrid extends StatelessWidget {
  final Bus bus;
  final Set<int> selectedSeats;
  final Function(Seat) onSeatTap;

  const _SeatGrid({
    required this.bus,
    required this.selectedSeats,
    required this.onSeatTap,
  });

  @override
  Widget build(BuildContext context) {
    final seats = bus.seats ?? [];
    final seatsPerRow = bus.seatsPerRow ?? 4;
    
    // Organiser les sièges par rangée
    final rows = <List<Seat?>>[];
    for (int i = 0; i < seats.length; i += seatsPerRow) {
      final row = <Seat?>[];
      for (int j = 0; j < seatsPerRow; j++) {
        if (i + j < seats.length) {
          row.add(seats[i + j]);
        } else {
          row.add(null);
        }
      }
      rows.add(row);
    }

    return Column(
      children: [
        // Indication du conducteur
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.airline_seat_recline_extra, size: 20),
              SizedBox(width: 8),
              Text('Conducteur'),
            ],
          ),
        ),
        
        // Grille des sièges
        ...rows.map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.asMap().entries.map((entry) {
              final index = entry.key;
              final seat = entry.value;
              
              // Ajouter un espace pour l'allée au milieu
              if (index == seatsPerRow ~/ 2) {
                return Row(
                  children: [
                    const SizedBox(width: 24),
                    seat != null ? _SeatWidget(
                      seat: seat,
                      isSelected: selectedSeats.contains(seat.id),
                      onTap: () => onSeatTap(seat),
                    ) : const SizedBox(width: 44),
                  ],
                );
              }
              
              return seat != null ? _SeatWidget(
                seat: seat,
                isSelected: selectedSeats.contains(seat.id),
                onTap: () => onSeatTap(seat),
              ) : const SizedBox(width: 44);
            }).toList(),
          ),
        )).toList(),
      ],
    );
  }
}

class _SeatWidget extends StatelessWidget {
  final Seat seat;
  final bool isSelected;
  final VoidCallback onTap;

  const _SeatWidget({
    required this.seat,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    
    if (!seat.isAvailable) {
      backgroundColor = Colors.grey[500]!;
      textColor = Colors.white;
    } else if (isSelected) {
      backgroundColor = AppTheme.primaryColor;
      textColor = Colors.white;
    } else {
      backgroundColor = Colors.grey[300]!;
      textColor = Colors.black87;
    }

    return GestureDetector(
      onTap: seat.isAvailable ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Center(
          child: Text(
            seat.number,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _PassengerInfoSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final int passengerCount;
  final List<Map<String, TextEditingController>> controllers;

  const _PassengerInfoSection({
    required this.formKey,
    required this.passengerCount,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informations des passagers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              ...List.generate(passengerCount, (index) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index > 0) const Divider(height: 24),
                    Text(
                      'Passager ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers[index]['name'],
                      decoration: const InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer le nom du passager';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controllers[index]['phone'],
                      decoration: const InputDecoration(
                        labelText: 'Téléphone',
                        prefixIcon: Icon(Icons.phone_outlined),
                        hintText: '07XXXXXXXX',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer le téléphone du passager';
                        }
                        return null;
                      },
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodSection extends StatelessWidget {
  final String selectedMethod;
  final Function(String) onSelect;

  const _PaymentMethodSection({
    required this.selectedMethod,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mode de paiement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _PaymentMethodTile(
              icon: 'assets/images/wave.png',
              title: 'Wave',
              subtitle: 'Paiement mobile sécurisé',
              isSelected: selectedMethod == 'wave',
              onTap: () => onSelect('wave'),
            ),
            const SizedBox(height: 8),
            _PaymentMethodTile(
              icon: 'assets/images/momo.png',
              title: 'Mobile Money',
              subtitle: 'MTN, Orange, Moov',
              isSelected: selectedMethod == 'mobile_money',
              onTap: () => onSelect('mobile_money'),
            ),
            const SizedBox(height: 8),
            _PaymentMethodTile(
              icon: 'assets/images/cash.png',
              title: 'Espèces',
              subtitle: 'Paiement à l\'embarquement',
              isSelected: selectedMethod == 'cash',
              onTap: () => onSelect('cash'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                title == 'Wave' ? Icons.waves
                    : title == 'Mobile Money' ? Icons.phone_android
                    : Icons.payments,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
              ),
          ],
        ),
      ),
    );
  }
}

class _BookingBottomBar extends StatelessWidget {
  final double totalPrice;
  final int seatCount;
  final VoidCallback onConfirm;
  final bool isLoading;
  final bool isForOther;
  final String? otherPassengerName;

  const _BookingBottomBar({
    required this.totalPrice,
    required this.seatCount,
    required this.onConfirm,
    required this.isLoading,
    this.isForOther = false,
    this.otherPassengerName,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'fr_FR');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge achat pour tiers
            if (isForOther) ...[
              ForOtherBadge(passengerName: otherPassengerName),
              const SizedBox(height: 12),
            ],
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$seatCount place${seatCount > 1 ? 's' : ''} sélectionnée${seatCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        '${formatter.format(totalPrice)} FCFA',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : onConfirm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Continuer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
