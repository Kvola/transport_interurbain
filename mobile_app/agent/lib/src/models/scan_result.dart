class ScanResult {
  final bool success;
  final String message;
  final String? passengerName;
  final String? seat;
  final String? tripInfo;
  final String? state;
  final int? bookingId;
  final String? errorCode;
  
  ScanResult({
    required this.success,
    required this.message,
    this.passengerName,
    this.seat,
    this.tripInfo,
    this.state,
    this.bookingId,
    this.errorCode,
  });
  
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      success: json['success'] ?? json['valid'] ?? false,
      message: json['message'] ?? '',
      passengerName: json['passenger_name'] ?? json['passenger']?['name'],
      seat: json['seat'],
      tripInfo: json['trip_info'],
      state: json['state'],
      bookingId: json['booking_id'],
      errorCode: json['error_code'],
    );
  }
  
  bool get isValid => success;
  bool get isAlreadyCheckedIn => errorCode == 'already_checked_in';
  bool get isWrongTrip => errorCode == 'wrong_trip';
  bool get isExpired => errorCode == 'expired';
  bool get isCancelled => errorCode == 'cancelled';
}
