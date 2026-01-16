import 'transport.dart';

/// Modèle Voyage
class Trip {
  final int id;
  final String reference;
  final TransportCompany company;
  final Route route;
  final String departureDatetime;
  final String? departureDate;
  final String? departureTime;
  final String? arrivalDatetime;
  final String meetingPoint;
  final String? meetingPointAddress;
  final int meetingTimeBefore;
  final double price;
  final double? vipPrice;
  final double? childPrice;
  final String currency;
  final int availableSeats;
  final int totalSeats;
  final Bus bus;
  final bool manageLuggage;
  final double luggageIncludedKg;
  final double? extraLuggagePrice;
  final List<Seat>? seats;
  
  Trip({
    required this.id,
    required this.reference,
    required this.company,
    required this.route,
    required this.departureDatetime,
    this.departureDate,
    this.departureTime,
    this.arrivalDatetime,
    required this.meetingPoint,
    this.meetingPointAddress,
    this.meetingTimeBefore = 30,
    required this.price,
    this.vipPrice,
    this.childPrice,
    this.currency = 'FCFA',
    required this.availableSeats,
    required this.totalSeats,
    required this.bus,
    this.manageLuggage = false,
    this.luggageIncludedKg = 25,
    this.extraLuggagePrice,
    this.seats,
  });
  
  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? 0,
      reference: json['reference'] ?? '',
      company: TransportCompany.fromJson(json['company'] ?? {}),
      route: Route.fromJson(json['route'] ?? {}),
      departureDatetime: json['departure_datetime'] ?? '',
      departureDate: json['departure_date'],
      departureTime: json['departure_time'],
      arrivalDatetime: json['arrival_datetime'],
      meetingPoint: json['meeting_point'] ?? '',
      meetingPointAddress: json['meeting_point_address'],
      meetingTimeBefore: json['meeting_time_before'] ?? 30,
      price: (json['price'] ?? 0).toDouble(),
      vipPrice: json['vip_price']?.toDouble(),
      childPrice: json['child_price']?.toDouble(),
      currency: json['currency'] ?? 'FCFA',
      availableSeats: json['available_seats'] ?? 0,
      totalSeats: json['total_seats'] ?? 0,
      bus: Bus.fromJson(json['bus'] ?? {}),
      manageLuggage: json['manage_luggage'] ?? false,
      luggageIncludedKg: (json['luggage_included_kg'] ?? 25).toDouble(),
      extraLuggagePrice: json['extra_luggage_price']?.toDouble(),
      seats: json['seats'] != null
          ? (json['seats'] as List).map((s) => Seat.fromJson(s)).toList()
          : null,
    );
  }
  
  String get formattedPrice => '${price.toInt()} $currency';
  
  String get routeDisplay => route.displayName;
  
  bool get hasAvailableSeats => availableSeats > 0;
  
  double getPriceForType(String ticketType) {
    switch (ticketType) {
      case 'vip':
        return vipPrice ?? price;
      case 'child':
        return childPrice ?? (price * 0.5);
      default:
        return price;
    }
  }
}
