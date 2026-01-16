import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/theme/app_theme.dart';
import 'src/providers/auth_provider.dart';
import 'src/providers/trip_provider.dart';
import 'src/providers/scan_provider.dart';
import 'src/screens/splash/splash_screen.dart';
import 'src/screens/auth/login_screen.dart';
import 'src/screens/home/home_screen.dart';
import 'src/screens/trips/trip_detail_screen.dart';
import 'src/screens/scan/scan_screen.dart';
import 'src/screens/boarding/boarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Forcer l'orientation portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Configuration de la barre de statut
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const TransportAgentApp());
}

class TransportAgentApp extends StatelessWidget {
  const TransportAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => ScanProvider()),
      ],
      child: MaterialApp(
        title: 'Transport Agent',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        
        // Localisation
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'FR'),
        ],
        locale: const Locale('fr', 'FR'),
        
        // Routes
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/scan': (context) => const ScanScreen(),
        },
        
        // Routes avec arguments
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/trip':
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (context) => TripDetailScreen(
                  tripId: args['tripId'] as int,
                ),
              );
            case '/boarding':
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (context) => BoardingScreen(
                  bookingId: args['bookingId'] as int,
                  passengerName: args['passengerName'] as String,
                ),
              );
            default:
              return null;
          }
        },
      ),
    );
  }
}
