import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/trip_provider.dart';
import '../../providers/scan_provider.dart';
import '../../models/agent_models.dart';
import '../../theme/app_theme.dart';

class TripDetailScreen extends StatefulWidget {
  final int tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    await Future.wait([
      tripProvider.loadTripDetails(widget.tripId),
      tripProvider.loadPassengers(widget.tripId),
    ]);
  }

  List<Passenger> _getFilteredPassengers(List<Passenger> passengers) {
    switch (_filter) {
      case 'paid':
        return passengers.where((p) => p.isPaid).toList();
      case 'unpaid':
        return passengers.where((p) => !p.isPaid).toList();
      case 'boarded':
        return passengers.where((p) => p.isBoarded).toList();
      case 'not_boarded':
        return passengers.where((p) => !p.isBoarded).toList();
      default:
        return passengers;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<TripProvider>(
        builder: (context, tripProvider, _) {
          final trip = tripProvider.currentTrip;

          if (tripProvider.isLoading || trip == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                // AppBar avec infos voyage
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: AppTheme.primaryColor,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.primaryColor,
                            Color(0xFF0D2137),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Trajet
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        trip.departureTime ?? '-',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        trip.departureCity,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 24),
                                    child: Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        trip.arrivalTime ?? '-',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        trip.arrivalCity,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Infos complémentaires
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _InfoChip(
                                    icon: Icons.directions_bus,
                                    label: trip.busNumber,
                                  ),
                                  const SizedBox(width: 12),
                                  _InfoChip(
                                    icon: Icons.business,
                                    label: trip.companyName,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadData,
                    ),
                  ],
                ),

                // Statistiques
                SliverToBoxAdapter(
                  child: _StatsRow(trip: trip),
                ),

                // TabBar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primaryColor,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.primaryColor,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.people, size: 18),
                              const SizedBox(width: 8),
                              Text('Passagers (${tripProvider.passengers.length})'),
                            ],
                          ),
                        ),
                        const Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.info_outline, size: 18),
                              SizedBox(width: 8),
                              Text('Détails'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                // Tab Passagers
                _PassengersTab(
                  passengers: tripProvider.passengers,
                  filter: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  getFilteredPassengers: _getFilteredPassengers,
                ),
                
                // Tab Détails
                _DetailsTab(trip: trip),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/scan');
        },
        backgroundColor: AppTheme.secondaryColor,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scanner'),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Trip trip;

  const _StatsRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatCard(
            value: trip.bookedSeats.toString(),
            label: 'Réservés',
            icon: Icons.event_seat,
            color: AppTheme.primaryColor,
          ),
          _StatCard(
            value: trip.boardedCount.toString(),
            label: 'Embarqués',
            icon: Icons.check_circle,
            color: AppTheme.boardedColor,
          ),
          _StatCard(
            value: trip.paidCount.toString(),
            label: 'Payés',
            icon: Icons.payment,
            color: AppTheme.paidColor,
          ),
          _StatCard(
            value: trip.unpaidCount.toString(),
            label: 'Non payés',
            icon: Icons.money_off,
            color: AppTheme.unpaidColor,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class _PassengersTab extends StatelessWidget {
  final List<Passenger> passengers;
  final String filter;
  final Function(String) onFilterChanged;
  final List<Passenger> Function(List<Passenger>) getFilteredPassengers;

  const _PassengersTab({
    required this.passengers,
    required this.filter,
    required this.onFilterChanged,
    required this.getFilteredPassengers,
  });

  @override
  Widget build(BuildContext context) {
    final filteredPassengers = getFilteredPassengers(passengers);

    return Column(
      children: [
        // Filtres
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _FilterChip(
                label: 'Tous',
                isSelected: filter == 'all',
                onTap: () => onFilterChanged('all'),
              ),
              _FilterChip(
                label: 'Payés',
                isSelected: filter == 'paid',
                onTap: () => onFilterChanged('paid'),
                color: AppTheme.paidColor,
              ),
              _FilterChip(
                label: 'Non payés',
                isSelected: filter == 'unpaid',
                onTap: () => onFilterChanged('unpaid'),
                color: AppTheme.unpaidColor,
              ),
              _FilterChip(
                label: 'Embarqués',
                isSelected: filter == 'boarded',
                onTap: () => onFilterChanged('boarded'),
                color: AppTheme.boardedColor,
              ),
              _FilterChip(
                label: 'Non embarqués',
                isSelected: filter == 'not_boarded',
                onTap: () => onFilterChanged('not_boarded'),
              ),
            ],
          ),
        ),

        // Liste
        Expanded(
          child: filteredPassengers.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun passager',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredPassengers.length,
                  itemBuilder: (context, index) {
                    return _PassengerCard(
                      passenger: filteredPassengers[index],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryColor;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: chipColor.withOpacity(0.2),
        checkmarkColor: chipColor,
        labelStyle: TextStyle(
          color: isSelected ? chipColor : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

class _PassengerCard extends StatelessWidget {
  final Passenger passenger;

  const _PassengerCard({required this.passenger});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/boarding',
            arguments: {
              'bookingId': passenger.bookingId,
              'passengerName': passenger.name,
            },
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: passenger.isBoarded
                    ? AppTheme.boardedColor.withOpacity(0.1)
                    : passenger.isPaid
                        ? AppTheme.paidColor.withOpacity(0.1)
                        : AppTheme.unpaidColor.withOpacity(0.1),
                child: Text(
                  passenger.initials,
                  style: TextStyle(
                    color: passenger.isBoarded
                        ? AppTheme.boardedColor
                        : passenger.isPaid
                            ? AppTheme.paidColor
                            : AppTheme.unpaidColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passenger.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.event_seat,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Siège ${passenger.seatNumber ?? '-'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.phone,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          passenger.phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Statuts
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(
                    label: passenger.isPaid ? 'Payé' : 'Non payé',
                    color: passenger.isPaid ? AppTheme.paidColor : AppTheme.unpaidColor,
                  ),
                  const SizedBox(height: 4),
                  if (passenger.isBoarded)
                    _StatusBadge(
                      label: 'Embarqué',
                      color: AppTheme.boardedColor,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final Trip trip;

  const _DetailsTab({required this.trip});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailCard(
            title: 'Informations du voyage',
            children: [
              _DetailRow(label: 'Référence', value: trip.reference),
              _DetailRow(label: 'Compagnie', value: trip.companyName),
              _DetailRow(label: 'Bus', value: trip.busNumber),
              _DetailRow(label: 'Capacité', value: '${trip.totalSeats} places'),
              if (trip.driverName != null)
                _DetailRow(label: 'Chauffeur', value: trip.driverName!),
            ],
          ),
          const SizedBox(height: 16),
          _DetailCard(
            title: 'Point de rencontre',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        trip.meetingPoint ?? 'Non spécifié',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary),
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
