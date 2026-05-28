class GroupJoinRequest {
  final String id;
  final String groupId;
  final String userId;
  final String userName;
  final String userEmail;
  final String userRole;
  final String? requestMessage;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime requestedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;

  GroupJoinRequest({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
    this.requestMessage,
    this.status = 'pending',
    required this.requestedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
  });

  factory GroupJoinRequest.fromJson(Map<String, dynamic> json) {
    return GroupJoinRequest(
      id: json['\$id'] ?? json['id'],
      groupId: json['group_id'] ?? json['groupId'],
      userId: json['user_id'] ?? json['userId'],
      userName: json['user_name'] ?? json['userName'],
      userEmail: json['user_email'] ?? json['userEmail'],
      userRole: json['user_role'] ?? json['userRole'],
      requestMessage: json['request_message'] ?? json['requestMessage'],
      status: json['status'] ?? 'pending',
      requestedAt: DateTime.parse(json['requested_at'] ?? json['requestedAt']),
      reviewedBy: json['reviewed_by'] ?? json['reviewedBy'],
      reviewedAt: json['reviewed_at'] != null 
          ? DateTime.parse(json['reviewed_at']) 
          : json['reviewedAt'] != null 
              ? DateTime.parse(json['reviewedAt']) 
              : null,
      reviewNotes: json['review_notes'] ?? json['reviewNotes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'user_role': userRole,
      'request_message': requestMessage,
      'status': status,
      'requested_at': requestedAt.toIso8601String(),
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'review_notes': reviewNotes,
    };
  }

  GroupJoinRequest copyWith({
    String? id,
    String? groupId,
    String? userId,
    String? userName,
    String? userEmail,
    String? userRole,
    String? requestMessage,
    String? status,
    DateTime? requestedAt,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? reviewNotes,
  }) {
    return GroupJoinRequest(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userRole: userRole ?? this.userRole,
      requestMessage: requestMessage ?? this.requestMessage,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
