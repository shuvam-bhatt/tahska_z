import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as models;
import 'supabase_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  
  models.User? _currentUser;
  bool _isInitialized = false;

  models.User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;

  SupabaseClient get client => _supabaseService.client;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check if user is already logged in
      final session = client.auth.currentSession;
      print('Current session: ${session?.user?.id}');
      if (session != null) {
        await _loadCurrentUser();
      }
    } catch (e) {
      print('Auth initialization error: $e');
      await _clearSession();
    }
    
    _isInitialized = true;
  }

  Future<models.User?> login(String email, String password) async {
    try {
      // Login with Supabase
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _loadCurrentUser();
        return _currentUser;
      }
      
      throw Exception('Login failed');
    } catch (e) {
      print('Login error: $e');
      throw _handleAuthError(e);
    }
  }

  Future<models.User?> register(String email, String password, String name, {String role = 'user'}) async {
    try {
      // Create account with Supabase
      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role,
        },
      );

      if (response.user != null) {
        // Create user document in database
        final userData = {
          'id': response.user!.id,
          'email': email,
          'name': name,
          'role': role,
          'created_at': DateTime.now().toIso8601String(),
          'group_ids': [],
        };

        try {
          await _supabaseService.insertUser(userData);
          print('User data inserted successfully');
        } catch (e) {
          print('Error inserting user data: $e');
          // Continue anyway, user is created in Auth
        }
        
        // Check if email confirmation is required
        if (response.session == null) {
          throw Exception('Registration successful! Please check your email and click the confirmation link before signing in. For demo purposes, you can disable email confirmation in Supabase settings.');
        }
        
        await _loadCurrentUser();
        
        return _currentUser;
      }
      
      throw Exception('Registration failed');
    } catch (e) {
      print('Registration error: $e');
      throw _handleAuthError(e);
    }
  }

  Future<void> logout() async {
    try {
      await client.auth.signOut();
      await _clearSession();
    } catch (e) {
      print('Logout error: $e');
      await _clearSession();
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final session = client.auth.currentSession;
      if (session?.user != null) {
        try {
          // Try to get user document from database
          final response = await client
              .from(SupabaseService.usersTable)
              .select()
              .eq('id', session!.user!.id)
              .single();

          _currentUser = models.User.fromJson(response);
          print('User loaded from database');
        } catch (e) {
          print('User not found in database, creating from auth data: $e');
          // If user doesn't exist in our table, create it from auth data
          final userData = {
            'id': session!.user!.id,
            'email': session.user!.email ?? '',
            'name': session.user!.userMetadata?['name'] ?? 'User',
            'role': session.user!.userMetadata?['role'] ?? 'user',
            'created_at': DateTime.now().toIso8601String(),
            'group_ids': [],
          };

          try {
            await _supabaseService.insertUser(userData);
            _currentUser = models.User.fromJson(userData);
            print('User created in database from auth data');
          } catch (insertError) {
            print('Failed to create user in database: $insertError');
            // Create user object from auth data anyway - this is a fallback
            _currentUser = models.User(
              id: userData['id'],
              email: userData['email'],
              name: userData['name'],
              role: userData['role'],
              createdAt: DateTime.parse(userData['created_at']),
              groupIds: List<String>.from(userData['group_ids']),
            );
          }
        }
      }
    } catch (e) {
      print('Load user error: $e');
      _currentUser = null;
      await _clearSession();
    }
  }

  Future<void> _clearSession() async {
    _currentUser = null;
  }

  Future<void> updateUserProfile(String name) async {
    if (_currentUser == null) throw Exception('User not authenticated');

    try {
      // Update in Supabase auth
      await client.auth.updateUser(
        UserAttributes(data: {'name': name}),
      );

      // Update in database
      await _supabaseService.updateUser(_currentUser!.id, {
        'name': name,
      });

      // Update local user
      _currentUser = _currentUser!.copyWith(name: name);
    } catch (e) {
      print('Update profile error: $e');
      throw _handleAuthError(e);
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      await client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      print('Change password error: $e');
      throw _handleAuthError(e);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email);
    } catch (e) {
      print('Reset password error: $e');
      throw _handleAuthError(e);
    }
  }

  String _handleAuthError(dynamic error) {
    if (error is AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return 'Invalid email or password';
        case 'User already registered':
          return 'User already exists';
        case 'Email not confirmed':
          return 'Please check your email and click the confirmation link before signing in. For demo purposes, you can disable email confirmation in Supabase settings.';
        default:
          return error.message;
      }
    }
    return 'Authentication failed';
  }

  Future<bool> isEmailAvailable(String email) async {
    try {
      // Check if email exists in database
      final response = await client
          .from(SupabaseService.usersTable)
          .select('id')
          .eq('email', email)
          .maybeSingle();
      
      return response == null;
    } catch (e) {
      return true; // Assume available on error
    }
  }

  // Listen to auth state changes
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}