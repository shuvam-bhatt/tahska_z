import 'package:flutter/material.dart';
import '../models/message.dart';
import '../utils/containment_utils.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final VoidCallback? onFileTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF182842),
              child: Text(
                message.senderName[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF00C6AE),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF00C6AE).withOpacity(0.15) : const Color(0xFF182842),
                border: Border.all(
                  color: isMe ? const Color(0xFF00C6AE).withOpacity(0.5) : Colors.white.withOpacity(0.05),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        message.senderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF00C6AE),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  
                  // Message content
                  if (message.isFile)
                    _buildFileMessage(context)
                  else
                    SecureText(
                      message.content,
                      style: const TextStyle(
                        color: Color(0xFFE8ECF2),
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  
                  const SizedBox(height: 6),
                  
                  // Timestamp
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: isMe ? const Color(0xFF00C6AE).withOpacity(0.8) : const Color(0xFF8A9AB5),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (message.isEncrypted) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.lock,
                          size: 10,
                          color: isMe ? const Color(0xFF00C6AE).withOpacity(0.8) : const Color(0xFF8A9AB5),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF0A1628),
              child: Icon(
                Icons.person,
                size: 16,
                color: Color(0xFF00C6AE),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileMessage(BuildContext context) {
    return GestureDetector(
      onTap: onFileTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1628).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF00C6AE).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF182842),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFileIcon(message.type),
                color: const Color(0xFF00C6AE),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? 'Unknown Payload',
                    style: const TextStyle(
                      color: Color(0xFFE8ECF2),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (message.fileSize != null)
                    Text(
                      _formatFileSize(message.fileSize!),
                      style: const TextStyle(
                        color: Color(0xFF8A9AB5),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.download_rounded,
              color: Color(0xFF00C6AE),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(MessageType type) {
    switch (type) {
      case MessageType.image:
        return Icons.image_outlined;
      case MessageType.file:
        return Icons.attach_file_rounded;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${timestamp.day.toString().padLeft(2,'0')}/${timestamp.month.toString().padLeft(2,'0')}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}
