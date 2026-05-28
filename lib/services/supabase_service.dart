import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Supabase Configuration
  static const String supabaseUrl = 'https://upmbtwigrvpzvhuybias.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVwbWJ0d2lncnZwenZodXliaWFzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk5ODYwNDYsImV4cCI6MjA5NTU2MjA0Nn0.7YuzqGc5u3_6Q1UhLr2cV84bUctzb-7A-lQsiH-PL80';

  // Table names
  static const String usersTable = 'users';
  static const String groupsTable = 'groups';
  static const String messagesTable = 'messages';
  static const String filesBucket = 'files';

  SupabaseClient get client => Supabase.instance.client;

  Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  // Database setup methods
  Future<void> setupDatabase() async {
    try {
      // Create tables if they don't exist
      await _createUsersTable();
      await _createGroupsTable();
      await _createMessagesTable();
      print('Database setup completed');
    } catch (e) {
      print('Database setup error: $e');
    }
  }

  Future<void> _createUsersTable() async {
    // Users table will be created via SQL in Supabase dashboard
    print('Users table setup - use Supabase dashboard');
  }

  Future<void> _createGroupsTable() async {
    // Groups table will be created via SQL in Supabase dashboard
    print('Groups table setup - use Supabase dashboard');
  }

  Future<void> _createMessagesTable() async {
    // Messages table will be created via SQL in Supabase dashboard
    print('Messages table setup - use Supabase dashboard');
  }

  Future<void> setupStorage() async {
    try {
      // Storage bucket will be created in Supabase dashboard
      print('Storage setup - use Supabase dashboard');
    } catch (e) {
      print('Storage setup error: $e');
    }
  }

  Future<void> initializeSupabase() async {
    await initialize();
    await setupDatabase();
    await setupStorage();
    await verifyDatabaseSetup();
  }

  Future<void> verifyDatabaseSetup() async {
    try {
      // Test if we can access the users table
      await client.from(usersTable).select('count').limit(1);
      print('Database verification successful');
    } catch (e) {
      print('Database verification failed: $e');
      print(
        'Please make sure you have run the SQL setup script in your Supabase dashboard',
      );
    }
  }

  // Helper methods for database operations
  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await client.from(usersTable).select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getGroups() async {
    final response = await client.from(groupsTable).select();
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> getGroup(
    String groupId, {
    String? withInviteCodeCheck,
  }) async {
    final query = client.from(groupsTable).select();

    if (withInviteCodeCheck != null) {
      final response = await query.match({
        'id': groupId,
        'invite_code': withInviteCodeCheck,
        'is_active': true,
      }).single();
      return response;
    }

    final response = await query.eq('id', groupId).single();
    return response;
  }

  Future<List<Map<String, dynamic>>> getMessages(String groupId) async {
    final response = await client
        .from(messagesTable)
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> insertUser(Map<String, dynamic> userData) async {
    final response = await client
        .from(usersTable)
        .insert(userData)
        .select()
        .single();
    return response;
  }

  Future<Map<String, dynamic>> insertGroup(
    Map<String, dynamic> groupData,
  ) async {
    final response = await client
        .from(groupsTable)
        .insert(groupData)
        .select()
        .single();
    return response;
  }

  Future<Map<String, dynamic>> insertMessage(
    Map<String, dynamic> messageData,
  ) async {
    final response = await client
        .from(messagesTable)
        .insert(messageData)
        .select()
        .single();
    return response;
  }

  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    await client.from(usersTable).update(updates).eq('id', userId);
  }

  Future<void> updateGroup(String groupId, Map<String, dynamic> updates) async {
    await client.from(groupsTable).update(updates).eq('id', groupId);
  }

  Future<void> deleteMessage(String messageId) async {
    await client.from(messagesTable).delete().eq('id', messageId);
  }

  // Realtime subscriptions
  RealtimeChannel subscribeToMessages(
    String groupId,
    Function(Map<String, dynamic>) onMessage,
  ) {
    return client
        .channel('messages:$groupId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: messagesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: groupId,
          ),
          callback: (payload) => onMessage(payload.newRecord),
        )
        .subscribe();
  }

  // File upload
  Future<String> uploadFile(
    String bucketName,
    String fileName,
    List<int> fileBytes,
  ) async {
    final response = await client.storage
        .from(bucketName)
        .uploadBinary(fileName, Uint8List.fromList(fileBytes));
    return response;
  }

  // File download
  Future<List<int>> downloadFile(String bucketName, String fileName) async {
    final response = await client.storage.from(bucketName).download(fileName);
    return response;
  }

  // Get public URL for file
  String getPublicUrl(String bucketName, String fileName) {
    return client.storage.from(bucketName).getPublicUrl(fileName);
  }
}
