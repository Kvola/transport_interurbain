import 'package:intl/intl.dart';

class Agent {
  final int id;
  final String name;
  final String username;
  final String? email;
  final String? phone;
  final List<TransportCompany> companies;
  final String? profileImage;

  Agent({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    this.phone,
    required this.companies,
    this.profileImage,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'],
      name: json['name'] ?? '',
      username: json['username'] ?? json['login'] ?? '',
      email: json['email'],
      phone: json['phone'],
      companies: json['companies'] != null
          ? (json['companies'] as List)
              .map((c) => TransportCompany.fromJson(c))
              .toList()
          : [],
      profileImage: json['profile_image'],
    );
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
  }
}

class TransportCompany {
  final int id;
  final String name;
  final String? logo;

  TransportCompany({
    required this.id,
    required this.name,
    this.logo,
  });

  factory TransportCompany.fromJson(Map<String, dynamic> json) {
    return TransportCompany(
      id: json['id'],
      name: json['name'] ?? '',
      logo: json['logo'],
    );
  }
}

class Trip {
  final int id;
  final String reference;
  final String departureCity;
  final String arrivalCity;
  final DateTime? departureDate;
  final String? departureTime;
  final String? arrivalTime;
  final String companyName;
  final String busNumber;
  final int totalSeats;
  final int bookedSeats;
  final int boardedCount;
  final int paidCount;
  final int unpaidCount;
  final String status;
  final String? driverName;
  final String? meetingPoint;

  Trip({
    required this.id,
    required this.reference,
    required this.departureCity,
    required this.arrivalCity,
    this.departureDate,
    this.departureTime,
    this.arrivalTime,
    required this.companyName,
    required this.busNumber,
    required this.totalSeats,
    required this.bookedSeats,
    required this.boardedCount,
    required this.paidCount,
    required this.unpaidCount,
    required this.status,
    this.driverName,
    this.meetingPoint,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'],
      reference: json['reference'] ?? '',
      departureCity: json['departure_city'] ?? '',
      arrivalCity: json['arrival_city'] ?? '',
      departureDate: json['departure_date'] != null
          ? DateTime.tryParse(json['departure_date'])
          : null,
      departureTime: json['departure_time'],
      arrivalTime: json['arrival_time'],
      companyName: json['company_name'] ?? '',
      busNumber: json['bus_number'] ?? '',
      totalSeats: json['total_seats'] ?? 0,
      bookedSeats: json['booked_seats'] ?? 0,
      boardedCount: json['boarded_count'] ?? 0,
      paidCount: json['paid_count'] ?? 0,
      unpaidCount: json['unpaid_count'] ?? 0,
      status: json['status'] ?? 'scheduled',
      driverName: json['driver_name'],
      meetingPoint: json['meeting_point'],
    );
  }

  String get formattedDate {
    if (departureDate == null) return '-';
    final format = DateFormat('EEE d MMM', 'fr_FR');
    return format.format(departureDate!);
  }

  String get route => '$departureCity → $arrivalCity';

  int get remainingSeats => totalSeats - bookedSeats;

  double get boardingProgress {
    if (bookedSeats == 0) return 0;
    return boardedCount / bookedSeats;
  }

  bool get isCompleted => status == 'completed';
  bool get isOngoing => status == 'ongoing';
  bool get isScheduled => status == 'scheduled';
}

class Passenger {
  final int id;
  final int bookingId;
  final String name;
  final String phone;
  final String? seatNumber;
  final bool isPaid;
  final bool isBoarded;
  final double amountPaid;
  final double amountDue;
  final String? paymentMethod;
  final DateTime? boardingTime;
  final String bookingReference;

  Passenger({
    required this.id,
    required this.bookingId,
    required this.name,
    required this.phone,
    this.seatNumber,
    required this.isPaid,
    required this.isBoarded,
    required this.amountPaid,
    required this.amountDue,
    this.paymentMethod,
    this.boardingTime,
    required this.bookingReference,
  });

  factory Passenger.fromJson(Map<String, dynamic> json) {
    return Passenger(
      id: json['id'],
      bookingId: json['booking_id'],
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      seatNumber: json['seat_number'],
      isPaid: json['is_paid'] ?? false,
      isBoarded: json['is_boarded'] ?? false,
      amountPaid: (json['amount_paid'] ?? 0).toDouble(),
      amountDue: (json['amount_due'] ?? 0).toDouble(),
      paymentMethod: json['payment_method'],
      boardingTime: json['boarding_time'] != null
          ? DateTime.tryParse(json['boarding_time'])
          : null,
      bookingReference: json['booking_reference'] ?? '',
    );
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
  }

  String get formattedAmountDue {
    final formatter = NumberFormat('#,###', 'fr_FR');
    return '${formatter.format(amountDue)} FCFA';
  }

  String get statusText {
    if (isBoarded) return 'Embarqué';
    if (isPaid) return 'Payé';
    return 'Non payé';
  }
}

class ScanResult {
  final bool success;
  final String type; // 'passenger' ou 'ticket'
  final Passenger? passenger;
  final List<Passenger>? passengers; // Pour scan passager (peut avoir plusieurs billets)
  final String? message;
  final String? errorCode;

  ScanResult({
    required this.success,
    required this.type,
    this.passenger,
    this.passengers,
    this.message,
    this.errorCode,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    List<Passenger>? passengers;
    if (json['passengers'] != null) {
      passengers = (json['passengers'] as List)
          .map((p) => Passenger.fromJson(p))
          .toList();
    }

    return ScanResult(
      success: json['success'] ?? false,
      type: json['type'] ?? 'unknown',
      passenger: json['passenger'] != null 
          ? Passenger.fromJson(json['passenger'])
          : null,
      passengers: passengers,
      message: json['message'],
      errorCode: json['error_code'],
    );
  }

  bool get hasMultipleTickets => passengers != null && passengers!.length > 1;
  
  int get paidTicketsCount => passengers?.where((p) => p.isPaid).length ?? 0;
  int get unpaidTicketsCount => passengers?.where((p) => !p.isPaid).length ?? 0;
}
