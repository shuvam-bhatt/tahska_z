enum MessageType { text, file, image }

class Message {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final bool isEncrypted;

  Message({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.isEncrypted = true,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['\$id'] ?? json['id'],
      groupId: json['group_id'] ?? json['groupId'],
      senderId: json['sender_id'] ?? json['senderId'],
      senderName: json['sender_name'] ?? json['senderName'],
      content: json['content'],
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${json['type']}',
        orElse: () => MessageType.text,
      ),
      timestamp: DateTime.parse(json['created_at'] ?? json['timestamp']),
      fileUrl: json['file_url'] ?? json['fileUrl'],
      fileName: json['file_name'] ?? json['fileName'],
      fileSize: json['file_size'] ?? json['fileSize'],
      isEncrypted: json['is_encrypted'] ?? json['isEncrypted'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'sender_id': senderId,
      'sender_name': senderName,
      'content': content,
      'type': type.toString().split('.').last,
      'created_at': timestamp.toIso8601String(),
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'is_encrypted': isEncrypted,
    };
  }

  Message copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? senderName,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    bool? isEncrypted,
  }) {
    return Message(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      isEncrypted: isEncrypted ?? this.isEncrypted,
    );
  }

  bool get isFile => type == MessageType.file || type == MessageType.image;
  String get displayContent => isEncrypted ? '[Encrypted Message]' : content;
}
