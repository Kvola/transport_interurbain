/// Modèle Ville
class City {
  final int id;
  final String name;
  final String? region;
  final bool isMajor;
  
  City({
    required this.id,
    required this.name,
    this.region,
    this.isMajor = false,
  });
  
  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      region: json['region'],
      isMajor: json['is_major'] ?? false,
    );
  }
}

/// Modèle Compagnie de transport
class TransportCompany {
  final int id;
  final String name;
  final String? logo;
  final double rating;
  final String? phone;
  final String? email;
  final String? description;
  
  TransportCompany({
    required this.id,
    required this.name,
    this.logo,
    this.rating = 0,
    this.phone,
    this.email,
    this.description,
  });
  
  factory TransportCompany.fromJson(Map<String, dynamic> json) {
    return TransportCompany(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      logo: json['logo'],
      rating: (json['rating'] ?? 0).toDouble(),
      phone: json['phone'],
      email: json['email'],
      description: json['description'],
    );
  }
}

/// Modèle Itinéraire
class Route {
  final int id;
  final City departureCity;
  final City arrivalCity;
  final double? distanceKm;
  final double? durationHours;
  
  Route({
    required this.id,
    required this.departureCity,
    required this.arrivalCity,
    this.distanceKm,
    this.durationHours,
  });
  
  factory Route.fromJson(Map<String, dynamic> json) {
    return Route(
      id: json['id'] ?? 0,
      departureCity: City.fromJson(json['departure_city'] ?? {}),
      arrivalCity: City.fromJson(json['arrival_city'] ?? {}),
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      durationHours: (json['duration_hours'] ?? 0).toDouble(),
    );
  }
  
  String get displayName => '${departureCity.name} → ${arrivalCity.name}';
}

/// Modèle Bus
class Bus {
  final int id;
  final String name;
  final String? model;
  final String? amenities;
  
  Bus({
    required this.id,
    required this.name,
    this.model,
    this.amenities,
  });
  
  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      model: json['model'],
      amenities: json['amenities'],
    );
  }
}

/// Modèle Siège
class Seat {
  final int id;
  final String number;
  final String? type;
  final int? row;
  final int? column;
  final bool isAvailable;
  final double priceSupplement;
  
  Seat({
    required this.id,
    required this.number,
    this.type,
    this.row,
    this.column,
    this.isAvailable = true,
    this.priceSupplement = 0,
  });
  
  factory Seat.fromJson(Map<String, dynamic> json) {
    return Seat(
      id: json['id'] ?? 0,
      number: json['number'] ?? '',
      type: json['type'],
      row: json['row'],
      column: json['column'],
      isAvailable: json['is_available'] ?? true,
      priceSupplement: (json['price_supplement'] ?? 0).toDouble(),
    );
  }
}
