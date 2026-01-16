/// Modèle Passager/Utilisateur
class Passenger {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? idType;
  final String? idNumber;
  final String? dateOfBirth;
  final String? gender;
  final String? preferredSeatPosition;
  final int loyaltyPoints;
  final String? loyaltyLevel;
  final String? uniqueToken;
  final int? bookingCount;
  final double? totalSpent;
  final String? lastTripDate;
  
  Passenger({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.idType,
    this.idNumber,
    this.dateOfBirth,
    this.gender,
    this.preferredSeatPosition,
    this.loyaltyPoints = 0,
    this.loyaltyLevel,
    this.uniqueToken,
    this.bookingCount,
    this.totalSpent,
    this.lastTripDate,
  });
  
  factory Passenger.fromJson(Map<String, dynamic> json) {
    return Passenger(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      idType: json['id_type'],
      idNumber: json['id_number'],
      dateOfBirth: json['date_of_birth'],
      gender: json['gender'],
      preferredSeatPosition: json['preferred_seat_position'],
      loyaltyPoints: json['loyalty_points'] ?? 0,
      loyaltyLevel: json['loyalty_level'],
      uniqueToken: json['unique_token'],
      bookingCount: json['booking_count'],
      totalSpent: (json['total_spent'] ?? 0).toDouble(),
      lastTripDate: json['last_trip_date'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'id_type': idType,
      'id_number': idNumber,
      'date_of_birth': dateOfBirth,
      'gender': gender,
      'preferred_seat_position': preferredSeatPosition,
      'loyalty_points': loyaltyPoints,
      'loyalty_level': loyaltyLevel,
      'unique_token': uniqueToken,
    };
  }
  
  String get loyaltyLevelLabel {
    switch (loyaltyLevel) {
      case 'bronze':
        return 'Bronze';
      case 'silver':
        return 'Argent';
      case 'gold':
        return 'Or';
      case 'platinum':
        return 'Platine';
      default:
        return 'Bronze';
    }
  }
  
  String get genderLabel {
    switch (gender) {
      case 'male':
        return 'Homme';
      case 'female':
        return 'Femme';
      default:
        return '';
    }
  }
}
