import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/group_provider.dart';
import 'providers/chat_provider.dart';
import 'services/supabase_service.dart';
import 'utils/containment_utils.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    print('Flutter Error: ${details.exception}');
    print('Stack trace: ${details.stack}');
  };
  
  // Set up platform error handling
  // PlatformDispatcher.instance.onError = (error, stack) {
  //   print('Platform Error: $error');
  //   print('Stack trace: $stack');
  //   return true;
  // };
  
  try {
    // Initialize Supabase with error handling
    final supabaseService = SupabaseService();
    await supabaseService.initializeSupabase();
    
    // Initialize containment
    ContainmentUtils().initialize();
    
    // Initialize encryption
    await _initializeEncryption();
    
    runApp(const SentinelApp());
  } catch (e) {
    print('Initialization error: $e');
    // Run app anyway with error handling
    runApp(const SentinelApp());
  }
}

Future<void> _initializeEncryption() async {
  try {
    // This will be handled by the ChatService when needed
    print('Encryption initialization prepared');
  } catch (e) {
    print('Encryption initialization error: $e');
  }
}

class SentinelApp extends StatelessWidget {
  const SentinelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'Sentinel',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B365D), // Military blue
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1B365D),
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B365D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1B365D), width: 2),
            ),
          ),
        ),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
