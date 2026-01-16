import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/booking.dart';

class BookingProvider extends ChangeNotifier {
  final ApiService apiService;
  
  bool _isLoading = false;
  String? _error;
  List<Booking> _bookings = [];
  Booking? _currentBooking;
  List<String> _selectedSeats = [];
  
  BookingProvider({required this.apiService});
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Booking> get bookings => _bookings;
  Booking? get currentBooking => _currentBooking;
  List<String> get selectedSeats => _selectedSeats;
  
  Future<void> loadBookings() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _bookings = await apiService.getMyBookings();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<bool> createBooking({
    required int tripId,
    String ticketType = 'adult',
    bool isForOther = false,
    Map<String, dynamic>? passenger,
  }) async {
    if (_selectedSeats.isEmpty) {
      _error = 'Veuillez sélectionner au moins un siège';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _currentBooking = await apiService.createBooking(
        tripId: tripId,
        seats: _selectedSeats,
        ticketType: ticketType,
        isForOther: isForOther,
        passenger: passenger,
      );
      await loadBookings();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> cancelBooking(int bookingId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await apiService.cancelBooking(bookingId);
      await loadBookings();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> initiatePayment({
    required int bookingId,
    required String paymentMethod,
    required String phone,
  }) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await apiService.initiatePayment(
        bookingId: bookingId,
        paymentMethod: paymentMethod,
        phone: phone,
      );
      await loadBookings();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  void toggleSeat(String seatNumber) {
    if (_selectedSeats.contains(seatNumber)) {
      _selectedSeats.remove(seatNumber);
    } else {
      _selectedSeats.add(seatNumber);
    }
    notifyListeners();
  }
  
  void clearSelectedSeats() {
    _selectedSeats = [];
    notifyListeners();
  }
  
  void setCurrentBooking(Booking booking) {
    _currentBooking = booking;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
