class Booking {
  final int id;
  final String reference;
  final String state;
  final String? stateLabel;
  final String companyName;
  final String tripRoute;
  final String tripDate;
  final String tripTime;
  final String? seat;
  final List<String> seats;
  final double ticketPrice;
  final double totalAmount;
  final double amountPaid;
  final double amountDue;
  final String currency;
  final String? qrCode;
  final bool isForOther;
  final String? passengerName;
  final String? passengerPhone;
  
  Booking({
    required this.id,
    required this.reference,
    required this.state,
    this.stateLabel,
    required this.companyName,
    required this.tripRoute,
    required this.tripDate,
    required this.tripTime,
    this.seat,
    this.seats = const [],
    required this.ticketPrice,
    required this.totalAmount,
    required this.amountPaid,
    required this.amountDue,
    this.currency = 'FCFA',
    this.qrCode,
    this.isForOther = false,
    this.passengerName,
    this.passengerPhone,
  });
  
  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] ?? 0,
      reference: json['reference'] ?? '',
      state: json['state'] ?? 'draft',
      stateLabel: json['state_label'],
      companyName: json['company_name'] ?? json['trip']?['company'] ?? '',
      tripRoute: json['trip_route'] ?? json['trip']?['route'] ?? '',
      tripDate: json['trip_date'] ?? json['trip']?['departure']?.split(' ')[0] ?? '',
      tripTime: json['trip_time'] ?? json['trip']?['departure']?.split(' ')[1] ?? '',
      seat: json['seat'],
      seats: List<String>.from(json['seats'] ?? []),
      ticketPrice: (json['ticket_price'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      amountPaid: (json['amount_paid'] ?? 0).toDouble(),
      amountDue: (json['amount_due'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'FCFA',
      qrCode: json['qr_code'],
      isForOther: json['is_for_other'] ?? false,
      passengerName: json['passenger']?['name'],
      passengerPhone: json['passenger']?['phone'],
    );
  }
  
  String get formattedTotal => '${totalAmount.toInt()} $currency';
  String get formattedAmountDue => '${amountDue.toInt()} $currency';
  
  bool get isPaid => amountDue <= 0;
  bool get canPay => !isPaid && !['cancelled', 'refunded'].contains(state);
  bool get canCancel => !['checked_in', 'completed', 'cancelled', 'refunded'].contains(state);
  
  String get statusLabel {
    if (stateLabel != null) return stateLabel!;
    switch (state) {
      case 'draft': return 'Brouillon';
      case 'reserved': return 'Réservé';
      case 'confirmed': return 'Confirmé';
      case 'checked_in': return 'Embarqué';
      case 'completed': return 'Terminé';
      case 'cancelled': return 'Annulé';
      case 'refunded': return 'Remboursé';
      default: return state;
    }
  }
  
  Color get statusColor {
    switch (state) {
      case 'confirmed':
      case 'completed': return const Color(0xFF4CAF50);
      case 'reserved':
      case 'checked_in': return const Color(0xFF2196F3);
      case 'cancelled':
      case 'refunded': return const Color(0xFFF44336);
      default: return const Color(0xFF9E9E9E);
    }
  }
}

class Color {
  final int value;
  const Color(this.value);
}
