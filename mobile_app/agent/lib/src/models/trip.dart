class Trip {
  final int id;
  final String reference;
  final String companyName;
  final String departureCity;
  final String arrivalCity;
  final String departureDate;
  final String departureTime;
  final String? arrivalTime;
  final String state;
  final String busName;
  final String? busPlate;
  final int totalSeats;
  final int bookedSeats;
  final int checkedInCount;
  
  Trip({
    required this.id,
    required this.reference,
    required this.companyName,
    required this.departureCity,
    required this.arrivalCity,
    required this.departureDate,
    required this.departureTime,
    this.arrivalTime,
    required this.state,
    required this.busName,
    this.busPlate,
    required this.totalSeats,
    required this.bookedSeats,
    required this.checkedInCount,
  });
  
  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] ?? 0,
      reference: json['reference'] ?? '',
      companyName: json['company_name'] ?? json['company'] ?? '',
      departureCity: json['departure_city'] ?? '',
      arrivalCity: json['arrival_city'] ?? '',
      departureDate: json['departure_date'] ?? '',
      departureTime: json['departure_time'] ?? '',
      arrivalTime: json['arrival_time'],
      state: json['state'] ?? 'scheduled',
      busName: json['bus_name'] ?? '',
      busPlate: json['bus_plate'],
      totalSeats: json['total_seats'] ?? 0,
      bookedSeats: json['booked_seats'] ?? 0,
      checkedInCount: json['checked_in_count'] ?? 0,
    );
  }
  
  String get route => '$departureCity → $arrivalCity';
  
  double get occupancyRate => totalSeats > 0 
      ? bookedSeats / totalSeats * 100 
      : 0;
      
  double get checkInRate => bookedSeats > 0
      ? checkedInCount / bookedSeats * 100
      : 0;
}

class Passenger {
  final int bookingId;
  final String reference;
  final String name;
  final String phone;
  final String seat;
  final String state;
  final bool isCheckedIn;
  
  Passenger({
    required this.bookingId,
    required this.reference,
    required this.name,
    required this.phone,
    required this.seat,
    required this.state,
    required this.isCheckedIn,
  });
  
  factory Passenger.fromJson(Map<String, dynamic> json) {
    return Passenger(
      bookingId: json['booking_id'] ?? json['id'] ?? 0,
      reference: json['reference'] ?? '',
      name: json['name'] ?? json['passenger_name'] ?? '',
      phone: json['phone'] ?? json['passenger_phone'] ?? '',
      seat: json['seat'] ?? '',
      state: json['state'] ?? 'confirmed',
      isCheckedIn: json['is_checked_in'] ?? json['state'] == 'checked_in',
    );
  }
}
