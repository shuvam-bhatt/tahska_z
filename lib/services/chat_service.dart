import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message.dart';
import 'supabase_service.dart';
import 'auth_service.dart';
import '../utils/encryption_utils.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final AuthService _authService = AuthService();
  final EncryptionUtils _encryptionUtils = EncryptionUtils();
  final Uuid _uuid = const Uuid();

  RealtimeChannel? _messageSubscription;
  final StreamController<List<Message>> _messagesController = StreamController<List<Message>>.broadcast();
  final Map<String, List<Message>> _messagesCache = {};

  Stream<List<Message>> get messagesStream => _messagesController.stream;

  Future<void> initialize() async {
    await _encryptionUtils.initialize();
  }

  // Send a text message
  Future<Message> sendMessage(String groupId, String content) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    try {
      final user = _authService.currentUser!;
      final messageId = _uuid.v4();
      
      // Initialize group encryption if not already done
      if (!_encryptionUtils.isGroupReady(groupId)) {
        await _encryptionUtils.initializeGroupEncryption(groupId);
      }
      
      // Encrypt the message content using group-specific encryption
      final encryptedContent = _encryptionUtils.encryptForGroup(groupId, content);
      
      final messageData = {
        'id': messageId,
        'group_id': groupId,
        'sender_id': user.id,
        'sender_name': user.name,
        'content': encryptedContent,
        'type': MessageType.text.toString().split('.').last,
        'created_at': DateTime.now().toIso8601String(),
        'is_encrypted': true,
      };

      final response = await _supabaseService.insertMessage(messageData);
      final message = Message.fromJson(response);
      
      _addMessageToCache(groupId, message);
      
      return message;
    } catch (e) {
      print('Send message error: $e');
      throw Exception('Failed to send message');
    }
  }

  // Send a file message
  Future<Message> sendFile(String groupId, PlatformFile file) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    if (file.size > 10 * 1024 * 1024) { // 10MB limit
      throw Exception('File size exceeds 10MB limit');
    }

    try {
      final user = _authService.currentUser!;
      final messageId = _uuid.v4();
      final fileId = _uuid.v4();
      
      // Encrypt file content
      final encryptedFileBytes = _encryptionUtils.encryptFile(file.bytes!);
      
      // Upload encrypted file to Supabase Storage
      final fileUrl = await _supabaseService.uploadFile(
        SupabaseService.filesBucket,
        fileId,
        encryptedFileBytes,
      );

      // Create message with file reference
      final messageData = {
        'id': messageId,
        'group_id': groupId,
        'sender_id': user.id,
        'sender_name': user.name,
        'content': '[File: ${file.name}]',
        'type': _getFileMessageType(file.extension),
        'created_at': DateTime.now().toIso8601String(),
        'file_url': fileUrl,
        'file_name': file.name,
        'file_size': file.size,
        'is_encrypted': true,
      };

      final response = await _supabaseService.insertMessage(messageData);
      final message = Message.fromJson(response);
      
      _addMessageToCache(groupId, message);
      
      return message;
    } catch (e) {
      print('Send file error: $e');
      throw Exception('Failed to send file');
    }
  }

  // Get messages for a group
  Future<List<Message>> getMessages(String groupId, {int limit = 50}) async {
    try {
      // Initialize group encryption if not already done
      if (!_encryptionUtils.isGroupReady(groupId)) {
        await _encryptionUtils.initializeGroupEncryption(groupId);
      }
      
      final response = await _supabaseService.getMessages(groupId);
      final messages = response.map((data) => Message.fromJson(data)).toList();

      // Decrypt messages using group-specific encryption
      final decryptedMessages = messages.map((message) {
        if (message.isEncrypted && message.type == MessageType.text) {
          try {
            final decryptedContent = _encryptionUtils.decryptForGroup(groupId, message.content);
            return message.copyWith(
              content: decryptedContent,
              isEncrypted: false,
            );
          } catch (e) {
            print('Group decryption error: $e');
            return message;
          }
        }
        return message;
      }).toList();

      _messagesCache[groupId] = decryptedMessages;
      _messagesController.add(decryptedMessages);
      
      return decryptedMessages;
    } catch (e) {
      print('Get messages error: $e');
      throw Exception('Failed to load messages');
    }
  }

  // Download and decrypt a file
  Future<Uint8List> downloadFile(String fileUrl) async {
    try {
      final fileBytes = await _supabaseService.downloadFile(
        SupabaseService.filesBucket,
        fileUrl,
      );

      // Decrypt file content
      return Uint8List.fromList(_encryptionUtils.decryptFile(fileBytes));
    } catch (e) {
      print('Download file error: $e');
      throw Exception('Failed to download file');
    }
  }

  // Subscribe to real-time messages for a group
  void subscribeToMessages(String groupId) {
    _messageSubscription?.unsubscribe();
    
    // Initialize group encryption if not already done
    if (!_encryptionUtils.isGroupReady(groupId)) {
      _encryptionUtils.initializeGroupEncryption(groupId);
    }
    
    _messageSubscription = _supabaseService.subscribeToMessages(
      groupId,
      (messageData) {
        try {
          final message = Message.fromJson(messageData);
          
          // Decrypt if it's a text message using group-specific encryption
          if (message.isEncrypted && message.type == MessageType.text) {
            try {
              final decryptedContent = _encryptionUtils.decryptForGroup(groupId, message.content);
              final decryptedMessage = message.copyWith(
                content: decryptedContent,
                isEncrypted: false,
              );
              _addMessageToCache(groupId, decryptedMessage);
            } catch (e) {
              print('Real-time group decryption error: $e');
              _addMessageToCache(groupId, message);
            }
          } else {
            _addMessageToCache(groupId, message);
          }
        } catch (e) {
          print('Real-time message parsing error: $e');
        }
      },
    );
  }

  // Unsubscribe from real-time messages
  void unsubscribeFromMessages() {
    _messageSubscription?.unsubscribe();
    _messageSubscription = null;
  }

  // Delete a message
  Future<void> deleteMessage(String messageId) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabaseService.deleteMessage(messageId);
      
      // Remove from cache
      for (final groupId in _messagesCache.keys) {
        _messagesCache[groupId]?.removeWhere((m) => m.id == messageId);
      }
    } catch (e) {
      print('Delete message error: $e');
      throw Exception('Failed to delete message');
    }
  }

  // Edit a message
  Future<Message> editMessage(String messageId, String newContent) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    try {
      final encryptedContent = _encryptionUtils.encrypt(newContent);
      
      final response = await _supabaseService.client
          .from(SupabaseService.messagesTable)
          .update({'content': encryptedContent})
          .eq('id', messageId)
          .select()
          .single();

      return Message.fromJson(response);
    } catch (e) {
      print('Edit message error: $e');
      throw Exception('Failed to edit message');
    }
  }

  // Get cached messages for a group
  List<Message> getCachedMessages(String groupId) {
    return _messagesCache[groupId] ?? [];
  }

  // Clear messages cache
  void clearMessagesCache() {
    _messagesCache.clear();
  }

  // Add message to cache and notify listeners
  void _addMessageToCache(String groupId, Message message) {
    if (_messagesCache[groupId] == null) {
      _messagesCache[groupId] = [];
    }
    
    // Check if message already exists (avoid duplicates)
    final existingIndex = _messagesCache[groupId]!.indexWhere(
      (m) => m.id == message.id,
    );
    
    if (existingIndex >= 0) {
      _messagesCache[groupId]![existingIndex] = message;
    } else {
      _messagesCache[groupId]!.add(message);
    }
    
    // Sort by timestamp
    _messagesCache[groupId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Notify listeners
    _messagesController.add(_messagesCache[groupId]!);
  }

  // Get file message type based on extension
  String _getFileMessageType(String? extension) {
    if (extension == null) return MessageType.file.toString().split('.').last;
    
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    if (imageExtensions.contains(extension.toLowerCase())) {
      return MessageType.image.toString().split('.').last;
    }
    
    return MessageType.file.toString().split('.').last;
  }

  void dispose() {
    _messageSubscription?.unsubscribe();
    _messagesController.close();
  }
}