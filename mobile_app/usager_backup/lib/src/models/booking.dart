/// Modèle Réservation
class Booking {
  final int id;
  final String reference;
  final String state;
  final String? stateLabel;
  final String bookingType;
  final String? bookingDate;
  final BookingTrip trip;
  final String? seat;
  final String ticketType;
  final double ticketPrice;
  final double? luggageWeight;
  final double luggageExtraPrice;
  final double totalAmount;
  final double amountPaid;
  final double amountDue;
  final String currency;
  final bool hasTicket;
  final bool hasQrCode;
  final String? reservationDeadline;
  final BookingPassenger? passenger;
  final BookingStop? boardingStop;
  final BookingStop? alightingStop;
  // Achat pour un tiers
  final bool isForOther;
  final BookingBuyer? buyer;
  
  Booking({
    required this.id,
    required this.reference,
    required this.state,
    this.stateLabel,
    required this.bookingType,
    this.bookingDate,
    required this.trip,
    this.seat,
    required this.ticketType,
    required this.ticketPrice,
    this.luggageWeight,
    this.luggageExtraPrice = 0,
    required this.totalAmount,
    required this.amountPaid,
    required this.amountDue,
    this.currency = 'FCFA',
    this.hasTicket = false,
    this.hasQrCode = false,
    this.reservationDeadline,
    this.passenger,
    this.boardingStop,
    this.alightingStop,
    this.isForOther = false,
    this.buyer,
  });
  
  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] ?? 0,
      reference: json['reference'] ?? '',
      state: json['state'] ?? 'draft',
      stateLabel: json['state_label'],
      bookingType: json['booking_type'] ?? 'reservation',
      bookingDate: json['booking_date'],
      trip: BookingTrip.fromJson(json['trip'] ?? {}),
      seat: json['seat'],
      ticketType: json['ticket_type'] ?? 'adult',
      ticketPrice: (json['ticket_price'] ?? 0).toDouble(),
      luggageWeight: json['luggage_weight']?.toDouble(),
      luggageExtraPrice: (json['luggage_extra_price'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      amountPaid: (json['amount_paid'] ?? 0).toDouble(),
      amountDue: (json['amount_due'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'FCFA',
      hasTicket: json['has_ticket'] ?? false,
      hasQrCode: json['has_qr_code'] ?? false,
      reservationDeadline: json['reservation_deadline'],
      passenger: json['passenger'] != null
          ? BookingPassenger.fromJson(json['passenger'])
          : null,
      boardingStop: json['boarding_stop'] != null
          ? BookingStop.fromJson(json['boarding_stop'])
          : null,
      alightingStop: json['alighting_stop'] != null
          ? BookingStop.fromJson(json['alighting_stop'])
          : null,
      isForOther: json['is_for_other'] ?? false,
      buyer: json['buyer'] != null
          ? BookingBuyer.fromJson(json['buyer'])
          : null,
    );
  }
  
  String get formattedTotal => '${totalAmount.toInt()} $currency';
  String get formattedAmountDue => '${amountDue.toInt()} $currency';
  
  bool get isPaid => amountDue <= 0;
  bool get canPay => state == 'draft' || state == 'reserved';
  bool get canCancel => !['checked_in', 'completed', 'cancelled', 'refunded'].contains(state);
  
  /// Alias pour la compatibilité avec les écrans
  String get status => state;
  
  /// Label de statut en français
  String get statusLabel {
    if (stateLabel != null) return stateLabel!;
    switch (state) {
      case 'draft':
        return 'Brouillon';
      case 'reserved':
        return 'Réservé';
      case 'confirmed':
        return 'Confirmé';
      case 'checked_in':
        return 'Embarqué';
      case 'completed':
        return 'Terminé';
      case 'cancelled':
        return 'Annulé';
      case 'refunded':
        return 'Remboursé';
      default:
        return state;
    }
  }
  
  /// Nom de la compagnie
  String get companyName => trip.company;
  
  /// Heure de départ
  String? get departureTime {
    // Extraire l'heure de la date de départ
    if (trip.departure.isEmpty) return null;
    final parts = trip.departure.split(' ');
    if (parts.length >= 2) return parts[1];
    return null;
  }
  
  /// Date de départ
  DateTime? get departureDate {
    if (trip.departure.isEmpty) return null;
    try {
      return DateTime.parse(trip.departure.replaceAll('/', '-'));
    } catch (e) {
      return null;
    }
  }
  
  String get ticketTypeLabel {
    switch (ticketType) {
      case 'adult':
        return 'Adulte';
      case 'child':
        return 'Enfant';
      case 'vip':
        return 'VIP';
      default:
        return ticketType;
    }
  }
}

/// Info voyage dans une réservation
class BookingTrip {
  final int id;
  final String reference;
  final String company;
  final String route;
  final String departure;
  final String meetingPoint;
  
  BookingTrip({
    required this.id,
    required this.reference,
    required this.company,
    required this.route,
    required this.departure,
    required this.meetingPoint,
  });
  
  factory BookingTrip.fromJson(Map<String, dynamic> json) {
    return BookingTrip(
      id: json['id'] ?? 0,
      reference: json['reference'] ?? '',
      company: json['company'] ?? '',
      route: json['route'] ?? '',
      departure: json['departure'] ?? '',
      meetingPoint: json['meeting_point'] ?? '',
    );
  }
}

/// Info passager dans une réservation
class BookingPassenger {
  final String name;
  final String phone;
  final String? email;
  final String? idType;
  final String? idNumber;
  
  BookingPassenger({
    required this.name,
    required this.phone,
    this.email,
    this.idType,
    this.idNumber,
  });
  
  factory BookingPassenger.fromJson(Map<String, dynamic> json) {
    return BookingPassenger(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      idType: json['id_type'],
      idNumber: json['id_number'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    if (email != null) 'email': email,
    if (idType != null) 'id_type': idType,
    if (idNumber != null) 'id_number': idNumber,
  };
}

/// Info acheteur (pour les achats tiers)
class BookingBuyer {
  final String name;
  final String phone;
  
  BookingBuyer({
    required this.name,
    required this.phone,
  });
  
  factory BookingBuyer.fromJson(Map<String, dynamic> json) {
    return BookingBuyer(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
    );
  }
}

/// Info arrêt dans une réservation
class BookingStop {
  final int id;
  final String name;
  
  BookingStop({
    required this.id,
    required this.name,
  });
  
  factory BookingStop.fromJson(Map<String, dynamic> json) {
    return BookingStop(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

/// Modèle pour passager tiers (achat pour quelqu'un d'autre)
class OtherPassenger {
  String name;
  String phone;
  String? email;
  String? idType;
  String? idNumber;
  
  OtherPassenger({
    required this.name,
    required this.phone,
    this.email,
    this.idType,
    this.idNumber,
  });
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    if (email != null && email!.isNotEmpty) 'email': email,
    if (idType != null && idType!.isNotEmpty) 'id_type': idType,
    if (idNumber != null && idNumber!.isNotEmpty) 'id_number': idNumber,
  };
  
  bool get isValid => name.isNotEmpty && phone.length >= 8;
}
