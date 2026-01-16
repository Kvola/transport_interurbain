class Trip {
  final int id;
  final String reference;
  final String companyName;
  final String? companyLogo;
  final String departureCity;
  final String arrivalCity;
  final String departureDate;
  final String departureTime;
  final String? arrivalTime;
  final String? duration;
  final double price;
  final String currency;
  final int totalSeats;
  final int availableSeats;
  final String state;
  final String busName;
  final String? busType;
  final List<Seat> seats;
  
  Trip({
    required this.id,
    required this.reference,
    required this.companyName,
    this.companyLogo,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    required this.departureTime,
    this.arrivalTime,
    this.duration,
    required this.price,
    this.currency = 'FCFA',
    required this.totalSeats,
    required this.availableSeats,
    required this.state,
    required this.busName,
    this.busType,
    this.seats = const [],
  });
  
  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? 0,
      reference: json['reference'] ?? '',
      companyName: json['company_name'] ?? json['company'] ?? '',
      companyLogo: json['company_logo'],
      departureCity: json['departure_city'] ?? '',
      arrivalCity: json['arrival_city'] ?? '',
      departureDate: json['departure_date'] ?? '',
      departureTime: json['departure_time'] ?? '',
      arrivalTime: json['arrival_time'],
      duration: json['duration'],
      price: (json['price'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'FCFA',
      totalSeats: json['total_seats'] ?? 0,
      availableSeats: json['available_seats'] ?? 0,
      state: json['state'] ?? 'scheduled',
      busName: json['bus_name'] ?? '',
      busType: json['bus_type'],
      seats: (json['seats'] as List? ?? [])
          .map((s) => Seat.fromJson(s))
          .toList(),
    );
  }
  
  String get formattedPrice => '${price.toInt()} $currency';
  
  bool get hasAvailableSeats => availableSeats > 0;
  
  double get occupancyRate => totalSeats > 0 
      ? (totalSeats - availableSeats) / totalSeats * 100 
      : 0;
}

class Seat {
  final String number;
  final String state;
  final bool isAvailable;
  final bool isDriver;
  
  Seat({
    required this.number,
    required this.state,
    this.isAvailable = true,
    this.isDriver = false,
  });
  
  factory Seat.fromJson(Map<String, dynamic> json) {
    return Seat(
      number: json['number'] ?? '',
      state: json['state'] ?? 'available',
      isAvailable: json['is_available'] ?? json['state'] == 'available',
      isDriver: json['is_driver'] ?? false,
    );
  }
}

class City {
  final int id;
  final String name;
  final String? code;
  
  City({
    required this.id,
    required this.name,
    this.code,
  });
  
  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'],
    );
  }
}
