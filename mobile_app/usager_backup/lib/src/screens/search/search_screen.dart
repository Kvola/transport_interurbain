import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/trip_provider.dart';
import '../../models/transport.dart';
import '../../models/trip.dart';
import '../../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  City? _departureCity;
  City? _arrivalCity;
  DateTime _departureDate = DateTime.now();
  DateTime? _returnDate;
  int _passengers = 1;
  bool _isRoundTrip = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    await tripProvider.loadCities();
  }

  void _swapCities() {
    setState(() {
      final temp = _departureCity;
      _departureCity = _arrivalCity;
      _arrivalCity = temp;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isReturn) async {
    final initialDate = isReturn 
        ? (_returnDate ?? _departureDate.add(const Duration(days: 1)))
        : _departureDate;
    
    final firstDate = isReturn ? _departureDate : DateTime.now();
    
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 90)),
      locale: const Locale('fr', 'FR'),
    );
    
    if (picked != null) {
      setState(() {
        if (isReturn) {
          _returnDate = picked;
        } else {
          _departureDate = picked;
          // Réinitialiser la date de retour si elle est avant la date de départ
          if (_returnDate != null && _returnDate!.isBefore(_departureDate)) {
            _returnDate = null;
          }
        }
      });
    }
  }

  Future<void> _search() async {
    if (_departureCity == null || _arrivalCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner les villes de départ et d\'arrivée'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    
    if (_departureCity!.id == _arrivalCity!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les villes de départ et d\'arrivée doivent être différentes'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    
    await tripProvider.searchTrips(
      departureCityId: _departureCity!.id,
      arrivalCityId: _arrivalCity!.id,
      departureDate: DateFormat('yyyy-MM-dd').format(_departureDate),
      returnDate: _isRoundTrip && _returnDate != null
          ? DateFormat('yyyy-MM-dd').format(_returnDate!)
          : null,
      passengers: _passengers,
    );
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _SearchResultsScreen(
            departureCity: _departureCity!,
            arrivalCity: _arrivalCity!,
            departureDate: _departureDate,
            returnDate: _returnDate,
            isRoundTrip: _isRoundTrip,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rechercher un voyage'),
      ),
      body: Consumer<TripProvider>(
        builder: (context, tripProvider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type de voyage
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ToggleButton(
                            label: 'Aller simple',
                            isSelected: !_isRoundTrip,
                            onTap: () {
                              setState(() {
                                _isRoundTrip = false;
                                _returnDate = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ToggleButton(
                            label: 'Aller-retour',
                            isSelected: _isRoundTrip,
                            onTap: () {
                              setState(() {
                                _isRoundTrip = true;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Villes
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Ville de départ
                        _CitySelector(
                          label: 'Départ',
                          icon: Icons.trip_origin,
                          city: _departureCity,
                          cities: tripProvider.cities,
                          onSelect: (city) {
                            setState(() => _departureCity = city);
                          },
                        ),
                        
                        // Bouton swap
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.swap_vert),
                            onPressed: _swapCities,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        
                        // Ville d'arrivée
                        _CitySelector(
                          label: 'Arrivée',
                          icon: Icons.location_on,
                          city: _arrivalCity,
                          cities: tripProvider.cities,
                          onSelect: (city) {
                            setState(() => _arrivalCity = city);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Dates
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _DateSelector(
                          label: 'Date de départ',
                          date: _departureDate,
                          onTap: () => _selectDate(context, false),
                        ),
                        if (_isRoundTrip) ...[
                          const Divider(height: 24),
                          _DateSelector(
                            label: 'Date de retour',
                            date: _returnDate,
                            onTap: () => _selectDate(context, true),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Nombre de passagers
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person, color: AppTheme.primaryColor),
                            SizedBox(width: 12),
                            Text(
                              'Passagers',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _passengers > 1
                                  ? () => setState(() => _passengers--)
                                  : null,
                            ),
                            Text(
                              '$_passengers',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _passengers < 10
                                  ? () => setState(() => _passengers++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Bouton rechercher
                ElevatedButton(
                  onPressed: tripProvider.isLoading ? null : _search,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: tripProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Rechercher',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Widgets d'aide

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CitySelector extends StatelessWidget {
  final String label;
  final IconData icon;
  final City? city;
  final List<City> cities;
  final Function(City) onSelect;

  const _CitySelector({
    required this.label,
    required this.icon,
    required this.city,
    required this.cities,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final selected = await showModalBottomSheet<City>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => _CityPickerSheet(
            title: 'Sélectionner la ville de $label',
            cities: cities,
          ),
        );
        if (selected != null) {
          onSelect(selected);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    city?.name ?? 'Sélectionner une ville',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: city != null ? FontWeight.w500 : FontWeight.normal,
                      color: city != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _CityPickerSheet extends StatefulWidget {
  final String title;
  final List<City> cities;

  const _CityPickerSheet({
    required this.title,
    required this.cities,
  });

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _search = '';
  
  List<City> get filteredCities {
    if (_search.isEmpty) return widget.cities;
    return widget.cities.where((c) =>
      c.name.toLowerCase().contains(_search.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher une ville...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setState(() => _search = value);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: filteredCities.length,
                itemBuilder: (context, index) {
                  final city = filteredCities[index];
                  return ListTile(
                    leading: city.isMajor
                        ? const Icon(Icons.star, color: AppTheme.secondaryColor)
                        : const Icon(Icons.location_city),
                    title: Text(city.name),
                    subtitle: city.region != null ? Text(city.region!) : null,
                    onTap: () => Navigator.pop(context, city),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DateSelector extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateSelector({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date != null 
                      ? dateFormat.format(date!)
                      : 'Sélectionner une date',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                    color: date != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}

// Écran des résultats de recherche
class _SearchResultsScreen extends StatelessWidget {
  final City departureCity;
  final City arrivalCity;
  final DateTime departureDate;
  final DateTime? returnDate;
  final bool isRoundTrip;

  const _SearchResultsScreen({
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    this.returnDate,
    required this.isRoundTrip,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: isRoundTrip ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${departureCity.name} → ${arrivalCity.name}'),
          bottom: isRoundTrip
              ? TabBar(
                  indicatorColor: Colors.white,
                  tabs: [
                    Tab(text: 'Aller - ${DateFormat('dd/MM').format(departureDate)}'),
                    Tab(text: 'Retour - ${returnDate != null ? DateFormat('dd/MM').format(returnDate!) : ''}'),
                  ],
                )
              : null,
        ),
        body: Consumer<TripProvider>(
          builder: (context, tripProvider, _) {
            if (tripProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (isRoundTrip) {
              return TabBarView(
                children: [
                  _TripsList(trips: tripProvider.searchResults),
                  _TripsList(trips: tripProvider.returnTrips),
                ],
              );
            }
            
            return _TripsList(trips: tripProvider.searchResults);
          },
        ),
      ),
    );
  }
}

class _TripsList extends StatelessWidget {
  final List<Trip> trips;

  const _TripsList({required this.trips});

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun voyage trouvé',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez de modifier vos critères de recherche',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        return _TripCard(trip: trip);
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;

  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/booking',
            arguments: {'tripId': trip.id},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compagnie
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    radius: 20,
                    child: Text(
                      trip.company.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
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
                          trip.company.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            Text(
                              ' ${trip.company.rating.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        trip.formattedPrice,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        '${trip.availableSeats} places',
                        style: TextStyle(
                          fontSize: 12,
                          color: trip.availableSeats < 5 
                              ? AppTheme.errorColor 
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              
              // Horaires
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.departureTime ?? '',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          trip.route.departureCity.name,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      const Icon(
                        Icons.arrow_forward,
                        color: AppTheme.primaryColor,
                      ),
                      Text(
                        '${trip.route.durationHours?.toStringAsFixed(1) ?? '-'}h',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          trip.arrivalDatetime ?? '-',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          trip.route.arrivalCity.name,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Infos supplémentaires
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trip.meetingPoint,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trip.bus.amenities != null) ...[
                    const Icon(Icons.wifi, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    const Icon(Icons.ac_unit, size: 16, color: AppTheme.textSecondary),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
