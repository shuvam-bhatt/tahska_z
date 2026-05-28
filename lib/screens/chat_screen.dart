import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../utils/containment_utils.dart';
import '../widgets/message_bubble.dart';
import '../widgets/file_picker_button.dart';

class ChatScreen extends StatefulWidget {
  final Group group;

  const ChatScreen({super.key, required this.group});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    
    ContainmentUtils().activateContainment(
      onScreenshotDetected: () {
        SecurityWarning.showScreenshotWarning(context);
      },
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.setCurrentGroup(widget.group.id);
      chatProvider.loadMessages(widget.group.id);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    ContainmentUtils().deactivateContainment();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text.trim();
    _messageController.clear();
    setState(() {
      _isTyping = false;
    });

    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final success = await chatProvider.sendMessage(content);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chatProvider.error ?? 'Transmission failed'),
          backgroundColor: const Color(0xFFFF5A5F),
        ),
      );
    }
  }

  Future<void> _sendFile(PlatformFile file) async {
    try {
      if (file.size > 10 * 1024 * 1024) { // 10MB limit
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File exceeds 10MB limit'),
              backgroundColor: Color(0xFFFF5A5F),
            ),
          );
        }
        return;
      }

      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.setCurrentGroup(widget.group.id);
      final success = await chatProvider.sendFile(file);

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chatProvider.error ?? 'Transmission failed'),
            backgroundColor: const Color(0xFFFF5A5F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transmission failed: $e'),
            backgroundColor: const Color(0xFFFF5A5F),
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(Message message) async {
    if (message.fileUrl == null) return;

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final fileBytes = await chatProvider.downloadFile(message.fileUrl!);

      if (fileBytes != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payload "${message.fileName}" acquired successfully'),
            backgroundColor: const Color(0xFF00C6AE),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payload acquisition failed: $e'),
            backgroundColor: const Color(0xFFFF5A5F),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.group.name.toUpperCase(),
              style: const TextStyle(letterSpacing: 2, fontSize: 16),
            ),
            Text(
              '${widget.group.memberCount} OPERATIVES ACTIVE',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF00C6AE),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF8A9AB5)),
            onPressed: () {
              _showGroupInfo(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isLoading && chatProvider.messages.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00C6AE)),
                  );
                }

                if (chatProvider.error != null && chatProvider.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 64,
                          color: Color(0xFFFF5A5F),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'COMMUNICATION ERROR',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Color(0xFFE8ECF2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          chatProvider.error!,
                          style: const TextStyle(color: Color(0xFF8A9AB5)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            chatProvider.loadMessages(widget.group.id);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('RE-ESTABLISH LINK'),
                        ),
                      ],
                    ),
                  );
                }

                if (chatProvider.messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.radar,
                          size: 64,
                          color: const Color(0xFF8A9AB5).withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'CHANNEL SECURE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Color(0xFFE8ECF2),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Awaiting initial transmission...',
                          style: TextStyle(color: Color(0xFF8A9AB5)),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  itemCount: chatProvider.messages.length,
                  itemBuilder: (context, index) {
                    final message = chatProvider.messages[index];
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final isMe = message.senderId == authProvider.user?.id;
                    
                    return MessageBubble(
                      message: message,
                      isMe: isMe,
                      onFileTap: message.isFile ? () => _downloadFile(message) : null,
                    );
                  },
                );
              },
            ),
          ),
          
          // Message Input
          Container(
            padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF111D33),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // File picker button
                FilePickerButton(
                  onFileSelected: _sendFile,
                ),
                const SizedBox(width: 8),
                
                // Message input field
                Expanded(
                  child: SecureTextField(
                    controller: _messageController,
                    hintText: 'Transmit message...',
                    maxLines: null,
                    onChanged: (value) {
                      setState(() {
                        _isTyping = value.trim().isNotEmpty;
                      });
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF182842),
                      hintStyle: TextStyle(color: const Color(0xFF8A9AB5).withOpacity(0.5)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Send button
                Consumer<ChatProvider>(
                  builder: (context, chatProvider, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isTyping ? const Color(0xFF00C6AE) : const Color(0xFF182842),
                      ),
                      child: IconButton(
                        onPressed: _isTyping && !chatProvider.isLoading
                            ? _sendMessage
                            : null,
                        icon: chatProvider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0A1628),
                                ),
                              )
                            : Icon(
                                Icons.send,
                                color: _isTyping ? const Color(0xFF0A1628) : const Color(0xFF8A9AB5),
                                size: 20,
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.group.name.toUpperCase(), style: const TextStyle(letterSpacing: 1.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.group.description.isNotEmpty) ...[
              const Text(
                'MISSION OBJECTIVE',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8A9AB5), fontSize: 12, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(widget.group.description, style: const TextStyle(color: Color(0xFFE8ECF2))),
              const SizedBox(height: 24),
            ],
            const Text(
              'SECURE ACCESS CODE',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8A9AB5), fontSize: 12, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00C6AE).withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.group.inviteCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00C6AE),
                        fontSize: 18,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('OPERATIVES', style: TextStyle(color: Color(0xFF8A9AB5))),
                Text('${widget.group.memberCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 24, color: Color(0xFF182842)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ESTABLISHED', style: TextStyle(color: Color(0xFF8A9AB5))),
                Text(_formatDate(widget.group.createdAt), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
  }
}
