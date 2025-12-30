import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/providers.dart';
import 'screens/splash_screen.dart';
import 'screens/security/security_check_screen.dart';
import 'widgets/tech_background.dart';
import 'utils/logger.dart';

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    Logger.info('Firebase initialized successfully');

    // Verify Firebase is initialized
    final app = Firebase.app();
    Logger.debug('Firebase app name: ${app.name}');
  } catch (e, stackTrace) {
    Logger.error('Error initializing Firebase', error: e, stackTrace: stackTrace);
    // Continue even if Firebase fails - FCM service will handle it
    // This allows the app to run even if Firebase config is missing
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
        ChangeNotifierProvider(create: (_) => BankCardProvider()),
        ChangeNotifierProvider(create: (_) => BillProviderProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) => SavingsGoalProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'E-Wallet',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF00D4FF), // Cyan/Blue tech color
            secondary: const Color(0xFF00FF88), // Green accent
            surface: const Color(0xFF0A0E27), // Dark blue background
            background: const Color(0xFF050810), // Very dark background
            error: const Color(0xFFFF3B5C),
            onPrimary: Colors.black,
            onSecondary: Colors.black,
            onSurface: Colors.white,
            onBackground: Colors.white,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF050810),
          textTheme: GoogleFonts.robotoTextTheme().apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: const Color(0xFF0A0E27),
            foregroundColor: Colors.white,
            titleTextStyle: GoogleFonts.roboto(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF00D4FF),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: Colors.black,
              elevation: 4,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF00D4FF),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF1A1F3A),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
            ),
            filled: true,
            fillColor: const Color(0xFF0A0E27),
            labelStyle: const TextStyle(color: Color(0xFF00D4FF)),
            hintStyle: TextStyle(color: Colors.grey[400]),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF0A0E27),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1A1F3A), width: 1),
            ),
          ),
        ),
        home: TechBackground(
          child: SecurityCheckScreen(
            showWarning: true,
            child: const SplashScreen(),
          ),
        ),
      ),
    );
  }
}
