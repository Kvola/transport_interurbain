import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'src/app.dart';
import 'src/providers/auth_provider.dart';
import 'src/providers/trip_provider.dart';
import 'src/providers/booking_provider.dart';
import 'src/services/api_service.dart';
import 'src/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Hive pour le stockage local
  await Hive.initFlutter();
  
  // Initialiser les services
  final storageService = StorageService();
  await storageService.init();
  
  final apiService = ApiService(storageService: storageService);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            apiService: apiService,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => TripProvider(apiService: apiService),
        ),
        ChangeNotifierProvider(
          create: (_) => BookingProvider(apiService: apiService),
        ),
      ],
      child: const TransportUsagerApp(),
    ),
  );
}
