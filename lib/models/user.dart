class User {
  final String id;
  final String email;
  final String name;
  final String role; // 'user', 'admin', 'hq_admin'
  final DateTime createdAt;
  final List<String> groupIds;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.groupIds = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['\$id'] ?? json['id'],
      email: json['email'],
      name: json['name'],
      role: json['role'] ?? 'user',
      createdAt: DateTime.parse(
        json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      groupIds: List<String>.from(json['group_ids'] ?? json['groupIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'group_ids': groupIds,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    DateTime? createdAt,
    List<String>? groupIds,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      groupIds: groupIds ?? this.groupIds,
    );
  }

  bool get isAdmin => role == 'admin' || role == 'hq_admin';
  bool get isHqAdmin => role == 'hq_admin';
}
