class Group {
  final String id;
  final String name;
  final String description;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;
  final List<String> memberIds;
  final List<String> adminIds;
  final bool isActive;
  final String? encryptedKey;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.memberIds = const [],
    this.adminIds = const [],
    this.isActive = true,
    this.encryptedKey,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['\$id'] ?? json['id'],
      name: json['name'],
      description: json['description'],
      inviteCode: json['invite_code'] ?? json['inviteCode'],
      createdBy: json['created_by'] ?? json['createdBy'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      memberIds: List<String>.from(
        json['member_ids'] ?? json['memberIds'] ?? [],
      ),
      adminIds: List<String>.from(json['admin_ids'] ?? json['adminIds'] ?? []),
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      encryptedKey: json['encrypted_key'] ?? json['encryptedKey'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'invite_code': inviteCode,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'member_ids': memberIds,
      'admin_ids': adminIds,
      'is_active': isActive,
      'encrypted_key': encryptedKey,
    };
  }

  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? inviteCode,
    String? createdBy,
    DateTime? createdAt,
    List<String>? memberIds,
    List<String>? adminIds,
    bool? isActive,
    String? encryptedKey,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      inviteCode: inviteCode ?? this.inviteCode,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      memberIds: memberIds ?? this.memberIds,
      adminIds: adminIds ?? this.adminIds,
      isActive: isActive ?? this.isActive,
      encryptedKey: encryptedKey ?? this.encryptedKey,
    );
  }

  bool isMember(String userId) => memberIds.contains(userId);
  bool isAdmin(String userId) =>
      adminIds.contains(userId) || createdBy == userId;
  int get memberCount => memberIds.length;
}
