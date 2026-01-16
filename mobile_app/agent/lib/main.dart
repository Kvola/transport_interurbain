import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'src/app.dart';
import 'src/providers/auth_provider.dart';
import 'src/providers/trip_provider.dart';
import 'src/providers/scan_provider.dart';
import 'src/services/api_service.dart';
import 'src/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  
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
          create: (_) => ScanProvider(apiService: apiService),
        ),
      ],
      child: const TransportAgentApp(),
    ),
  );
}
