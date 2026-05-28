import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/group_provider.dart';
import 'providers/chat_provider.dart';
import 'services/supabase_service.dart';
import 'utils/containment_utils.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    print('Flutter Error: ${details.exception}');
    print('Stack trace: ${details.stack}');
  };

  try {
    final supabaseService = SupabaseService();
    await supabaseService.initializeSupabase();
    ContainmentUtils().initialize();
    await _initializeEncryption();
    runApp(const AegisApp());
  } catch (e) {
    print('Initialization error: $e');
    runApp(const AegisApp());
  }
}

Future<void> _initializeEncryption() async {
  try {
    print('Encryption initialization prepared');
  } catch (e) {
    print('Encryption initialization error: $e');
  }
}

class AegisApp extends StatelessWidget {
  const AegisApp({super.key});

  // ─── Design Tokens ───
  static const Color kNavy      = Color(0xFF0A1628);
  static const Color kSurface   = Color(0xFF111D33);
  static const Color kCard      = Color(0xFF182842);
  static const Color kAccent    = Color(0xFF00C6AE); // teal-cyan
  static const Color kGold      = Color(0xFFFFB547);
  static const Color kTextPri   = Color(0xFFE8ECF2);
  static const Color kTextSec   = Color(0xFF8A9AB5);
  static const Color kDanger    = Color(0xFFFF5A5F);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'Aegis',
        debugShowCheckedModeBanner: false,
        routes: {
          '/login': (context) => const LoginScreen(),
        },
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kNavy,
          colorScheme: ColorScheme.dark(
            primary: kAccent,
            secondary: kGold,
            surface: kSurface,
            error: kDanger,
            onPrimary: kNavy,
            onSurface: kTextPri,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: kSurface,
            foregroundColor: kTextPri,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: kTextPri,
            ),
          ),
          cardTheme: CardThemeData(
            color: kCard,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: kNavy,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: kAccent),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: kSurface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kAccent, width: 1.5),
            ),
            labelStyle: const TextStyle(color: kTextSec),
            hintStyle: TextStyle(color: kTextSec.withOpacity(0.5)),
            prefixIconColor: kTextSec,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: kSurface,
            selectedItemColor: kAccent,
            unselectedItemColor: kTextSec,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: kAccent,
            foregroundColor: kNavy,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: kCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titleTextStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: kTextPri,
            ),
          ),
          popupMenuTheme: PopupMenuThemeData(
            color: kCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          tabBarTheme: TabBarThemeData(
            indicatorColor: kAccent,
            labelColor: kAccent,
            unselectedLabelColor: kTextSec,
          ),
          dividerColor: Colors.white.withOpacity(0.06),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
