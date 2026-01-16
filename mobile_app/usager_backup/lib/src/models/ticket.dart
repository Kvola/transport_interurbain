/// Modèle Ticket
class Ticket {
  final String ticketNumber;
  final String ticketToken;
  final String? ticketQrCode;
  final String ticketQrData;
  final TicketPassenger passenger;
  final TicketTrip trip;
  final String seat;
  final String boardingPoint;
  final String alightingPoint;
  final String status;
  // Support achat pour tiers
  final bool isForOther;
  final TicketBuyer? buyer;
  
  Ticket({
    required this.ticketNumber,
    required this.ticketToken,
    this.ticketQrCode,
    required this.ticketQrData,
    required this.passenger,
    required this.trip,
    required this.seat,
    required this.boardingPoint,
    required this.alightingPoint,
    required this.status,
    this.isForOther = false,
    this.buyer,
  });
  
  /// Accesseurs de compatibilité
  String get companyName => trip.company.name;
  String get passengerName => passenger.name;
  String get passengerPhone => passenger.phone;
  String get routeName => trip.route.display;
  String? get seatNumber => seat;
  String? get meetingPoint => trip.meetingPoint;
  
  /// Label de statut traduit
  String get statusLabel {
    switch (status) {
      case 'valid':
        return 'Valide';
      case 'used':
        return 'Utilisé';
      case 'expired':
        return 'Expiré';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }
  
  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      ticketNumber: json['ticket_number'] ?? '',
      ticketToken: json['ticket_token'] ?? '',
      ticketQrCode: json['ticket_qr_code'],
      ticketQrData: json['ticket_qr_data'] ?? '',
      passenger: TicketPassenger.fromJson(json['passenger'] ?? {}),
      trip: TicketTrip.fromJson(json['trip'] ?? {}),
      seat: json['seat'] ?? 'Non assigné',
      boardingPoint: json['boarding_point'] ?? '',
      alightingPoint: json['alighting_point'] ?? '',
      status: json['status'] ?? '',
      isForOther: json['is_for_other'] ?? false,
      buyer: json['buyer'] != null ? TicketBuyer.fromJson(json['buyer']) : null,
    );
  }
}

/// Informations de l'acheteur (quand achat pour tiers)
class TicketBuyer {
  final String name;
  final String phone;
  
  TicketBuyer({
    required this.name,
    required this.phone,
  });
  
  factory TicketBuyer.fromJson(Map<String, dynamic> json) {
    return TicketBuyer(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
    );
  }
}

class TicketPassenger {
  final String name;
  final String phone;
  final String? uniqueQrCode;
  final String? uniqueQrData;
  
  TicketPassenger({
    required this.name,
    required this.phone,
    this.uniqueQrCode,
    this.uniqueQrData,
  });
  
  factory TicketPassenger.fromJson(Map<String, dynamic> json) {
    return TicketPassenger(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      uniqueQrCode: json['unique_qr_code'],
      uniqueQrData: json['unique_qr_data'],
    );
  }
}

class TicketTrip {
  final int id;
  final String reference;
  final TicketCompany company;
  final TicketRoute route;
  final String departureDatetime;
  final String? departureTime;
  final String meetingPoint;
  
  TicketTrip({
    required this.id,
    required this.reference,
    required this.company,
    required this.route,
    required this.departureDatetime,
    this.departureTime,
    required this.meetingPoint,
  });
  
  factory TicketTrip.fromJson(Map<String, dynamic> json) {
    return TicketTrip(
      id: json['id'] ?? 0,
      reference: json['reference'] ?? '',
      company: TicketCompany.fromJson(json['company'] ?? {}),
      route: TicketRoute.fromJson(json['route'] ?? {}),
      departureDatetime: json['departure_datetime'] ?? '',
      departureTime: json['departure_time'],
      meetingPoint: json['meeting_point'] ?? '',
    );
  }
}

class TicketCompany {
  final int id;
  final String name;
  final String? logo;
  
  TicketCompany({
    required this.id,
    required this.name,
    this.logo,
  });
  
  factory TicketCompany.fromJson(Map<String, dynamic> json) {
    return TicketCompany(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      logo: json['logo'],
    );
  }
}

class TicketRoute {
  final String departureCity;
  final String arrivalCity;
  
  TicketRoute({
    required this.departureCity,
    required this.arrivalCity,
  });
  
  factory TicketRoute.fromJson(Map<String, dynamic> json) {
    return TicketRoute(
      departureCity: json['departure_city']?['name'] ?? '',
      arrivalCity: json['arrival_city']?['name'] ?? '',
    );
  }
  
  String get display => '$departureCity → $arrivalCity';
}

/// Modèle Reçu
class Receipt {
  final String bookingReference;
  final String passengerName;
  final String passengerPhone;
  final ReceiptTrip trip;
  final ReceiptPricing pricing;
  final List<ReceiptPayment> payments;
  final String? paymentDate;
  final String receiptDate;
  
  Receipt({
    required this.bookingReference,
    required this.passengerName,
    required this.passengerPhone,
    required this.trip,
    required this.pricing,
    required this.payments,
    this.paymentDate,
    required this.receiptDate,
  });
  
  factory Receipt.fromJson(Map<String, dynamic> json) {
    return Receipt(
      bookingReference: json['booking_reference'] ?? '',
      passengerName: json['passenger_name'] ?? '',
      passengerPhone: json['passenger_phone'] ?? '',
      trip: ReceiptTrip.fromJson(json['trip'] ?? {}),
      pricing: ReceiptPricing.fromJson(json['pricing'] ?? {}),
      payments: (json['payments'] as List? ?? [])
          .map((p) => ReceiptPayment.fromJson(p))
          .toList(),
      paymentDate: json['payment_date'],
      receiptDate: json['receipt_date'] ?? '',
    );
  }
}

class ReceiptTrip {
  final String reference;
  final String route;
  final String departure;
  final String company;
  
  ReceiptTrip({
    required this.reference,
    required this.route,
    required this.departure,
    required this.company,
  });
  
  factory ReceiptTrip.fromJson(Map<String, dynamic> json) {
    return ReceiptTrip(
      reference: json['reference'] ?? '',
      route: json['route'] ?? '',
      departure: json['departure'] ?? '',
      company: json['company'] ?? '',
    );
  }
}

class ReceiptPricing {
  final double ticketPrice;
  final double luggageExtra;
  final double total;
  final String currency;
  
  ReceiptPricing({
    required this.ticketPrice,
    required this.luggageExtra,
    required this.total,
    required this.currency,
  });
  
  factory ReceiptPricing.fromJson(Map<String, dynamic> json) {
    return ReceiptPricing(
      ticketPrice: (json['ticket_price'] ?? 0).toDouble(),
      luggageExtra: (json['luggage_extra'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'FCFA',
    );
  }
}

class ReceiptPayment {
  final String reference;
  final double amount;
  final String method;
  final String? date;
  final String? transactionId;
  
  ReceiptPayment({
    required this.reference,
    required this.amount,
    required this.method,
    this.date,
    this.transactionId,
  });
  
  factory ReceiptPayment.fromJson(Map<String, dynamic> json) {
    return ReceiptPayment(
      reference: json['reference'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      method: json['method'] ?? '',
      date: json['date'],
      transactionId: json['transaction_id'],
    );
  }
}
