import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/message.dart';
import '../services/chat_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _chatService = ChatService();
  
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<Message>>? _messagesSubscription;
  String? _currentGroupId;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentGroupId => _currentGroupId;

  void setCurrentGroup(String groupId) {
    _currentGroupId = groupId;
    notifyListeners();
  }

  Future<void> initialize() async {
    try {
      await _chatService.initialize();
    } catch (e) {
      _setError('Failed to initialize chat service: $e');
    }
  }

  Future<void> loadMessages(String groupId) async {
    if (_currentGroupId == groupId && _messages.isNotEmpty) {
      return; // Already loaded
    }

    _setLoading(true);
    _clearError();
    _currentGroupId = groupId;
    
    try {
      // Unsubscribe from previous group
      _messagesSubscription?.cancel();
      
      // Load messages
      final messages = await _chatService.getMessages(groupId);
      _messages = messages;
      
      // Subscribe to real-time updates
      _chatService.subscribeToMessages(groupId);
      _messagesSubscription = _chatService.messagesStream.listen(
        (newMessages) {
          _messages = newMessages;
          notifyListeners();
        },
        onError: (error) {
          _setError('Real-time message error: $error');
        },
      );
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to load messages: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendMessage(String content) async {
    if (_currentGroupId == null) return false;
    
    _clearError();
    
    try {
      await _chatService.sendMessage(_currentGroupId!, content);
      // Message will be added via real-time subscription
      return true;
    } catch (e) {
      _setError('Failed to send message: $e');
      return false;
    }
  }

  Future<bool> sendFile(PlatformFile file) async {
    if (_currentGroupId == null) return false;
    
    _clearError();
    
    try {
      await _chatService.sendFile(_currentGroupId!, file);
      // Message will be added via real-time subscription
      return true;
    } catch (e) {
      _setError('Failed to send file: $e');
      return false;
    }
  }

  Future<Uint8List?> downloadFile(String fileUrl) async {
    try {
      return await _chatService.downloadFile(fileUrl);
    } catch (e) {
      _setError('Failed to download file: $e');
      return null;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    _clearError();
    
    try {
      await _chatService.deleteMessage(messageId);
      // Message will be removed via real-time subscription
      return true;
    } catch (e) {
      _setError('Failed to delete message: $e');
      return false;
    }
  }

  Future<bool> editMessage(String messageId, String newContent) async {
    _clearError();
    
    try {
      await _chatService.editMessage(messageId, newContent);
      // Message will be updated via real-time subscription
      return true;
    } catch (e) {
      _setError('Failed to edit message: $e');
      return false;
    }
  }

  void clearMessages() {
    _messages.clear();
    _currentGroupId = null;
    _messagesSubscription?.cancel();
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _chatService.dispose();
    super.dispose();
  }
}
