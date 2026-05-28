import 'package:uuid/uuid.dart';
import '../models/group.dart';
import '../models/group_join_request.dart';
import '../models/user.dart';
import 'supabase_service.dart';
import 'auth_service.dart';
import '../utils/encryption_utils.dart';

class GroupService {
  static final GroupService _instance = GroupService._internal();
  factory GroupService() => _instance;
  GroupService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final AuthService _authService = AuthService();
  final EncryptionUtils _encryptionUtils = EncryptionUtils();
  final Uuid _uuid = const Uuid();
  static const String _masterKeyStorageKey = 'master_key';

  // Get or generate master key for group key encryption
  Future<String> _getMasterKey() async {
    final masterKey = await _encryptionUtils.secureStorage.read(
      key: _masterKeyStorageKey,
    );
    if (masterKey != null) {
      return masterKey;
    }

    // Generate a new master key if none exists
    final newMasterKey = _encryptionUtils
        .generateGroupKey(); // This generates a secure AES-256 key
    await _encryptionUtils.secureStorage.write(
      key: _masterKeyStorageKey,
      value: newMasterKey,
    );
    return newMasterKey;
  }

  // Create a new group
  Future<Group> createGroup(String name, String description) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;
    if (!user.isAdmin) {
      throw Exception('Only admins can create groups');
    }

    final groupId = _uuid.v4();
    try {
      // 1. Set up encryption
      final inviteCode = _encryptionUtils.generateGroupInviteCode(groupId);
      final masterKey = await _getMasterKey();
      final groupKey = _encryptionUtils.generateGroupKey();

      // Encrypt and store the group key
      final encryptedGroupKey = _encryptionUtils.encryptData(
        groupKey,
        masterKey,
      );

      // Store the decrypted key locally for the creator
      await _encryptionUtils.storeGroupKey(groupId, groupKey);

      // 2. Create the group in the database
      final data = await _supabaseService.insertGroup({
        'id': groupId,
        'name': name,
        'description': description,
        'created_by': user.id,
        'admin_ids': [user.id],
        'member_ids': [user.id],
        'invite_code': inviteCode,
        'encrypted_key': encryptedGroupKey,
        'created_at': DateTime.now().toIso8601String(),
        'is_active': true,
        'created_by_name': user.name,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 3. Initialize group encryption system
      // This ensures all encryption utilities are ready
      await _encryptionUtils.initializeGroupEncryption(groupId);

      return Group.fromJson(data);
    } catch (e) {
      print('Error creating group: $e');
      // Clean up any stored keys if the creation fails
      await _encryptionUtils.clearGroupKeys(groupId);
      throw Exception('Failed to create group: ${e.toString()}');
    }
  }

  // Join a group using invite code
  Future<void> joinGroup(String groupId, String inviteCode) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;

    try {
      // Verify the group and invite code
      final groupData = await _supabaseService.getGroup(
        groupId,
        withInviteCodeCheck: inviteCode,
      );
      final group = Group.fromJson(groupData);

      if (!group.isActive) {
        throw Exception('This group is no longer active');
      }

      if (group.memberIds.contains(user.id)) {
        throw Exception('You are already a member of this group');
      }

      // For SIH demo: Decrypt the group key using master key
      // In production: Use proper key exchange protocol
      final masterKey = await _getMasterKey();
      if (group.encryptedKey == null) {
        throw Exception('Group encryption key not found');
      }

      final decryptedGroupKey = _encryptionUtils.decryptData(
        group.encryptedKey!,
        masterKey,
      );

      // Update group members in database
      final updatedMemberIds = List<String>.from(group.memberIds)..add(user.id);
      await _supabaseService.updateGroup(groupId, {
        'member_ids': updatedMemberIds,
        'last_joined_at': DateTime.now().toIso8601String(),
      });

      // Update user's group list and store group key only after database updates succeed
      await _supabaseService.client
          .from(SupabaseService.usersTable)
          .update({
            'group_ids': [...user.groupIds, groupId],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      // Store the decrypted group key locally
      await _encryptionUtils.storeGroupKey(groupId, decryptedGroupKey);
    } catch (e) {
      print('Error joining group: $e');
      await _encryptionUtils.clearGroupKeys(groupId);
      if (e.toString().contains('No rows returned')) {
        throw Exception('Invalid group ID or invite code');
      } else if (e.toString().contains('not found')) {
        throw Exception('Group not found');
      } else if (e.toString().contains('already a member')) {
        throw Exception('You are already a member of this group');
      } else if (e.toString().contains('not active')) {
        throw Exception('This group is no longer active');
      } else if (e.toString().contains('key not found')) {
        throw Exception('Group encryption key not found');
      }
      throw Exception('Failed to join group: ${e.toString()}');
    }
  }

  // Request to join a group using invite code
  Future<GroupJoinRequest> requestToJoinGroup(
    String inviteCode, {
    String? requestMessage,
  }) async {
    if (!_authService.isAuthenticated) {
      print('ERROR: User not authenticated in requestToJoinGroup');
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;
    print('DEBUG: Attempting to join group with invite code: $inviteCode');
    print('DEBUG: User: ${user.id}, role: ${user.role}');

    // Retry mechanism for network issues
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        print(
          'DEBUG: Attempt ${attempt + 1} - Looking for group with invite code: $inviteCode',
        );

        // Find group by invite code
        final response = await _supabaseService.client
            .from(SupabaseService.groupsTable)
            .select()
            .eq('invite_code', inviteCode)
            .eq('is_active', true)
            .single();

        print('DEBUG: Found group: ${response['name']} (${response['id']})');
        final group = Group.fromJson(response);

        if (group.isMember(user.id)) {
          throw Exception('You are already a member of this group');
        }

        // Check if there's already a pending request
        try {
          final existingRequest = await _supabaseService.client
              .from('group_join_requests')
              .select()
              .eq('group_id', group.id)
              .eq('user_id', user.id)
              .eq('status', 'pending')
              .maybeSingle();

          if (existingRequest != null) {
            throw Exception(
              'You already have a pending request for this group',
            );
          }
        } catch (e) {
          print('Error checking existing request: $e');
          // Continue if table doesn't exist or permission issue
        }

        // Create join request
        final requestData = {
          'group_id': group.id,
          'user_id': user.id,
          'user_name': user.name,
          'user_email': user.email,
          'user_role': user.role,
          'request_message': requestMessage,
          'status': 'pending',
          'requested_at': DateTime.now().toIso8601String(),
        };

        try {
          final requestResponse = await _supabaseService.client
              .from('group_join_requests')
              .insert(requestData)
              .select()
              .single();

          return GroupJoinRequest.fromJson(requestResponse);
        } catch (e) {
          print('Error creating join request: $e');
          // If join requests table doesn't exist, just add user directly to group
          if (e.toString().contains(
                'relation "group_join_requests" does not exist',
              ) ||
              e.toString().contains('permission denied')) {
            // Add user directly to group as fallback
            final updatedMemberIds = List<String>.from(group.memberIds)
              ..add(user.id);

            await _supabaseService.updateGroup(group.id, {
              'member_ids': updatedMemberIds,
            });

            // Update user's group list
            await _supabaseService.client
                .from(SupabaseService.usersTable)
                .update({
                  'group_ids': [...user.groupIds, group.id],
                })
                .eq('id', user.id);

            // Return a mock join request for compatibility
            return GroupJoinRequest(
              id: 'direct_join_${DateTime.now().millisecondsSinceEpoch}',
              groupId: group.id,
              userId: user.id,
              userName: user.name,
              userEmail: user.email,
              userRole: user.role,
              requestMessage: requestMessage,
              status: 'approved',
              requestedAt: DateTime.now(),
            );
          } else {
            rethrow;
          }
        }
      } catch (e) {
        print(
          'ERROR: Request to join group error (attempt ${attempt + 1}): $e',
        );
        print('ERROR: Invite code: $inviteCode');
        print('ERROR: User: ${user.id}');

        if (attempt == 2) {
          // Last attempt
          if (e.toString().contains('No rows returned')) {
            print('ERROR: No group found with invite code: $inviteCode');
            throw Exception('Invalid invite code: $inviteCode');
          } else if (e.toString().contains('already a member')) {
            throw Exception('You are already a member of this group');
          } else if (e.toString().contains('pending request')) {
            throw Exception(
              'You already have a pending request for this group',
            );
          } else {
            print('ERROR: Generic error - ${e.toString()}');
            throw Exception(
              'Failed to request joining group. Error: ${e.toString()}',
            );
          }
        }

        // Wait before retry
        print('DEBUG: Waiting ${(attempt + 1) * 2} seconds before retry...');
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
      }
    }

    throw Exception('Failed to request joining group after multiple attempts');
  }

  // Approve a group join request (admin only)
  Future<void> approveJoinRequest(
    String requestId, {
    String? reviewNotes,
  }) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;

    try {
      // Get the request
      final requestResponse = await _supabaseService.client
          .from('group_join_requests')
          .select('*, groups(*)')
          .eq('id', requestId)
          .single();

      final request = GroupJoinRequest.fromJson(requestResponse);
      final group = Group.fromJson(requestResponse['groups']);

      // Check if user is admin of the group
      if (!group.isAdmin(user.id)) {
        throw Exception('Only group admins can approve requests');
      }

      if (request.status != 'pending') {
        throw Exception('Request has already been processed');
      }

      // Update request status
      await _supabaseService.client
          .from('group_join_requests')
          .update({
            'status': 'approved',
            'reviewed_by': user.id,
            'reviewed_at': DateTime.now().toIso8601String(),
            'review_notes': reviewNotes,
          })
          .eq('id', requestId);

      // Add user to group
      final updatedMemberIds = List<String>.from(group.memberIds)
        ..add(request.userId);

      await _supabaseService.updateGroup(group.id, {
        'member_ids': updatedMemberIds,
      });

      // Update user's group list
      await _supabaseService.client
          .from(SupabaseService.usersTable)
          .update({
            'group_ids': [...user.groupIds, group.id],
          })
          .eq('id', request.userId);
    } catch (e) {
      print('Approve join request error: $e');
      throw Exception('Failed to approve join request');
    }
  }

  // Reject a group join request (admin only)
  Future<void> rejectJoinRequest(
    String requestId, {
    String? reviewNotes,
  }) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;

    try {
      // Get the request
      final requestResponse = await _supabaseService.client
          .from('group_join_requests')
          .select('*, groups(*)')
          .eq('id', requestId)
          .single();

      final request = GroupJoinRequest.fromJson(requestResponse);
      final group = Group.fromJson(requestResponse['groups']);

      // Check if user is admin of the group
      if (!group.isAdmin(user.id)) {
        throw Exception('Only group admins can reject requests');
      }

      if (request.status != 'pending') {
        throw Exception('Request has already been processed');
      }

      // Update request status
      await _supabaseService.client
          .from('group_join_requests')
          .update({
            'status': 'rejected',
            'reviewed_by': user.id,
            'reviewed_at': DateTime.now().toIso8601String(),
            'review_notes': reviewNotes,
          })
          .eq('id', requestId);
    } catch (e) {
      print('Reject join request error: $e');
      throw Exception('Failed to reject join request');
    }
  }

  // Get pending join requests for a group (admin only)
  Future<List<GroupJoinRequest>> getPendingJoinRequests(String groupId) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;

    try {
      // Check if user is admin of the group
      final groupResponse = await _supabaseService.client
          .from(SupabaseService.groupsTable)
          .select()
          .eq('id', groupId)
          .single();

      final group = Group.fromJson(groupResponse);

      if (!group.isAdmin(user.id)) {
        throw Exception('Only group admins can view join requests');
      }

      // Get pending requests
      final response = await _supabaseService.client
          .from('group_join_requests')
          .select()
          .eq('group_id', groupId)
          .eq('status', 'pending')
          .order('requested_at', ascending: false);

      return response
          .map<GroupJoinRequest>((data) => GroupJoinRequest.fromJson(data))
          .toList();
    } catch (e) {
      print('Get pending join requests error: $e');
      throw Exception('Failed to get pending join requests');
    }
  }

  // Leave a group
  Future<void> leaveGroup(String groupId) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;

    try {
      // Get group details
      final response = await _supabaseService.client
          .from(SupabaseService.groupsTable)
          .select()
          .eq('id', groupId)
          .single();

      final group = Group.fromJson(response);

      // Check if user is a member
      if (!group.isMember(user.id)) {
        throw Exception('You are not a member of this group');
      }

      // Remove user from group
      final updatedMemberIds = List<String>.from(group.memberIds)
        ..remove(user.id);
      final updatedAdminIds = List<String>.from(group.adminIds)
        ..remove(user.id);

      await _supabaseService.updateGroup(groupId, {
        'member_ids': updatedMemberIds,
        'admin_ids': updatedAdminIds,
      });
    } catch (e) {
      print('Leave group error: $e');
      throw Exception('Failed to leave group');
    }
  }

  // Get user's groups
  Future<List<Group>> getUserGroups() async {
    if (!_authService.isAuthenticated) {
      print('ERROR: User not authenticated in getUserGroups');
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;
    print('DEBUG: Getting groups for user: ${user.id}, role: ${user.role}');

    try {
      final response = await _supabaseService.client
          .from(SupabaseService.groupsTable)
          .select()
          .contains('member_ids', [user.id])
          .eq('is_active', true);

      print('DEBUG: Found ${response.length} groups for user');
      return response.map((data) => Group.fromJson(data)).toList();
    } catch (e) {
      print('ERROR: Get user groups failed: $e');
      print('ERROR: User ID: ${user.id}');
      print('ERROR: User role: ${user.role}');
      throw Exception('Failed to load groups: ${e.toString()}');
    }
  }

  // Get all groups (admin only)
  Future<List<Group>> getAllGroups() async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;
    if (!user.isHqAdmin) {
      throw Exception('Only HQ admins can view all groups');
    }

    try {
      final response = await _supabaseService.getGroups();
      return response.map((data) => Group.fromJson(data)).toList();
    } catch (e) {
      print('Error getting all groups: $e');
      if (e.toString().contains('permission denied')) {
        throw Exception('You do not have permission to view all groups');
      }
      throw Exception('Failed to load groups: ${e.toString()}');
    }
  }

  // Get group details
  Future<Group> getGroup(String groupId) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _supabaseService.client
          .from(SupabaseService.groupsTable)
          .select()
          .eq('id', groupId)
          .single();

      return Group.fromJson(response);
    } catch (e) {
      print('Error getting group: $e');
      if (e.toString().contains('No rows returned')) {
        throw Exception('Group not found');
      } else if (e.toString().contains('permission denied')) {
        throw Exception('You do not have permission to view this group');
      }
      throw Exception('Failed to load group: ${e.toString()}');
    }
  }

  // Update group details
  Future<Group> updateGroup(
    String groupId, {
    String? name,
    String? description,
  }) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;

    try {
      // Get group to check permissions
      final group = await getGroup(groupId);

      if (!group.isAdmin(user.id)) {
        throw Exception('Only group admins can update group details');
      }

      // Validate update data
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': user.id,
      };

      if (name != null) {
        if (name.trim().isEmpty) {
          throw Exception('Group name cannot be empty');
        }
        updateData['name'] = name.trim();
      }

      if (description != null) {
        updateData['description'] = description.trim();
      }

      // Perform update
      final response = await _supabaseService.client
          .from(SupabaseService.groupsTable)
          .update(updateData)
          .eq('id', groupId)
          .select()
          .single();

      return Group.fromJson(response);
    } catch (e) {
      print('Error updating group: $e');
      if (e.toString().contains('No rows returned')) {
        throw Exception('Group not found');
      } else if (e.toString().contains('permission denied')) {
        throw Exception('You do not have permission to update this group');
      } else if (e.toString().contains('empty')) {
        throw Exception(e.toString());
      } else if (e.toString().contains('not an admin')) {
        throw Exception('Only group admins can update group details');
      }
      throw Exception('Failed to update group: ${e.toString()}');
    }
  }

  // Debug method to check if invite code exists
  Future<void> debugInviteCode(String inviteCode) async {
    try {
      print('DEBUG: Checking invite code: $inviteCode');

      // Check all groups to see what invite codes exist
      final allGroups = await _supabaseService.client
          .from(SupabaseService.groupsTable)
          .select('id, name, invite_code, is_active');

      print('DEBUG: Found ${allGroups.length} total groups in database');
      for (var group in allGroups) {
        print(
          'DEBUG: Group: ${group['name']} - Code: ${group['invite_code']} - Active: ${group['is_active']}',
        );
      }

      // Try to find the specific invite code
      final specificGroup = await _supabaseService.client
          .from(SupabaseService.groupsTable)
          .select()
          .eq('invite_code', inviteCode)
          .maybeSingle();

      if (specificGroup != null) {
        print(
          'DEBUG: Found group with invite code $inviteCode: ${specificGroup['name']}',
        );
      } else {
        print('DEBUG: No group found with invite code: $inviteCode');
      }
    } catch (e) {
      print('DEBUG: Error checking invite code: $e');
      // Debug method, no need to throw
    }
  }

  // Add admin to group
  Future<void> addGroupAdmin(String groupId, String userId) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;

    try {
      final group = await getGroup(groupId);

      if (!group.isAdmin(user.id)) {
        throw Exception('Only group admins can add other admins');
      }

      if (!group.isMember(userId)) {
        throw Exception('User must be a member before becoming an admin');
      }

      final updatedAdminIds = List<String>.from(group.adminIds)..add(userId);

      await _supabaseService.updateGroup(groupId, {
        'admin_ids': updatedAdminIds,
      });
    } catch (e) {
      print('Add group admin error: $e');
      throw Exception('Failed to add group admin');
    }
  }

  // Remove admin from group
  Future<void> removeGroupAdmin(String groupId, String userId) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;

    try {
      final group = await getGroup(groupId);

      if (!group.isAdmin(user.id)) {
        throw Exception('Only group admins can remove other admins');
      }

      if (group.createdBy == userId) {
        throw Exception('Cannot remove group creator from admin role');
      }

      final updatedAdminIds = List<String>.from(group.adminIds)..remove(userId);

      await _supabaseService.updateGroup(groupId, {
        'admin_ids': updatedAdminIds,
      });
    } catch (e) {
      print('Remove group admin error: $e');
      throw Exception('Failed to remove group admin');
    }
  }

  // Deactivate group
  Future<void> deactivateGroup(String groupId) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;

    try {
      final group = await getGroup(groupId);

      if (!group.isAdmin(user.id) && !user.isHqAdmin) {
        throw Exception('Only group admins or HQ admins can deactivate groups');
      }

      await _supabaseService.updateGroup(groupId, {'is_active': false});
    } catch (e) {
      print('Deactivate group error: $e');
      throw Exception('Failed to deactivate group');
    }
  }

  // Generate new invite code
  Future<String> generateNewInviteCode(String groupId) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;

    try {
      final group = await getGroup(groupId);

      if (!group.isAdmin(user.id)) {
        throw Exception('Only group admins can generate new invite codes');
      }

      final newInviteCode = _encryptionUtils.generateGroupInviteCode(groupId);

      await _supabaseService.updateGroup(groupId, {
        'invite_code': newInviteCode,
      });

      return newInviteCode;
    } catch (e) {
      print('Generate invite code error: $e');
      throw Exception('Failed to generate new invite code');
    }
  }

  // Generate join token for a group
  Future<String> generateJoinToken(String groupId) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;

    try {
      final group = await getGroup(groupId);

      if (!group.isAdmin(user.id)) {
        throw Exception('Only group admins can generate join tokens');
      }

      final joinToken = _encryptionUtils.generateJoinToken(groupId, user.id);
      return joinToken;
    } catch (e) {
      print('Error generating join token: $e');
      if (e.toString().contains('No rows returned')) {
        throw Exception('Group not found');
      } else if (e.toString().contains('not an admin')) {
        throw Exception('Only group admins can generate join tokens');
      }
      throw Exception('Failed to generate join token: ${e.toString()}');
    }
  }

  // Join group using token
  Future<void> joinGroupWithToken(String token) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;
    String? groupId;

    try {
      // Verify the token first
      final tokenData = _encryptionUtils.verifyJoinToken(token);
      if (tokenData == null) {
        throw Exception('Invalid join token');
      }
      groupId = tokenData['groupId']!;

      // Get the group details
      final groupData = await _supabaseService.getGroup(groupId);
      final group = Group.fromJson(groupData);

      if (!group.isActive) {
        throw Exception('Group is not active');
      }

      if (group.memberIds.contains(user.id)) {
        throw Exception('You are already a member of this group');
      }

      // For SIH demo: Decrypt the group key using master key
      // In production: Use proper key exchange protocol
      final masterKey = await _getMasterKey();
      if (group.encryptedKey == null) {
        throw Exception('Group encryption key not found');
      }

      final decryptedGroupKey = _encryptionUtils.decryptData(
        group.encryptedKey!,
        masterKey,
      );

      // Add user to group
      final updatedMemberIds = List<String>.from(group.memberIds)..add(user.id);
      await _supabaseService.updateGroup(groupId, {
        'member_ids': updatedMemberIds,
        'last_joined_at': DateTime.now().toIso8601String(),
      });

      // Update user's group list
      await _supabaseService.client
          .from(SupabaseService.usersTable)
          .update({
            'group_ids': [...user.groupIds, groupId],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      // Store the group key locally only after all updates succeed
      await _encryptionUtils.storeGroupKey(groupId, decryptedGroupKey);
    } catch (e) {
      print('Error joining group with token: $e');
      if (groupId != null) {
        await _encryptionUtils.clearGroupKeys(groupId);
      }

      if (e.toString().contains('Invalid join token')) {
        throw Exception('Invalid or expired join token');
      } else if (e.toString().contains('No rows returned')) {
        throw Exception('Group not found');
      } else if (e.toString().contains('already a member')) {
        throw Exception('You are already a member of this group');
      } else if (e.toString().contains('not active')) {
        throw Exception('This group is no longer active');
      } else if (e.toString().contains('key not found')) {
        throw Exception('Group encryption key not found');
      }
      throw Exception('Failed to join group: ${e.toString()}');
    }
  }

  // Check if a user can read messages in a group
  Future<bool> canReadMessages(String groupId, {String? userId}) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final targetUserId = userId ?? _authService.currentUser!.id;

    try {
      // Get group details
      final groupData = await _supabaseService.getGroup(groupId);
      final group = Group.fromJson(groupData);

      // Check if group is active
      if (!group.isActive) {
        return false;
      }

      // Check banned users
      final bannedUsers = await _supabaseService.client
          .from('group_bans')
          .select('user_id')
          .eq('group_id', groupId)
          .eq('user_id', targetUserId)
          .eq('is_active', true)
          .maybeSingle();

      if (bannedUsers != null) {
        return false;
      }

      // Check if user is a member
      return group.isMember(targetUserId);
    } catch (e) {
      print('Error checking message read access: $e');
      return false;
    }
  }

  // Check if a user can send messages in a group
  Future<bool> canSendMessages(String groupId, {String? userId}) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final targetUserId = userId ?? _authService.currentUser!.id;

    try {
      final canRead = await canReadMessages(groupId, userId: targetUserId);
      if (!canRead) {
        return false;
      }

      // Check if user is muted
      final mutedUser = await _supabaseService.client
          .from('group_mutes')
          .select('user_id')
          .eq('group_id', groupId)
          .eq('user_id', targetUserId)
          .eq('is_active', true)
          .maybeSingle();

      return mutedUser == null;
    } catch (e) {
      print('Error checking message send access: $e');
      return false;
    }
  }

  // Ban a user from a group
  Future<void> banUser(String groupId, String userId, {String? reason}) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final adminUser = _authService.currentUser!;

    try {
      final group = await getGroup(groupId);

      // Check admin permissions
      if (!group.isAdmin(adminUser.id)) {
        throw Exception('Only group admins can ban users');
      }

      // Check if user is a member
      if (!group.isMember(userId)) {
        throw Exception('User is not a member of this group');
      }

      // Cannot ban group admins
      if (group.isAdmin(userId)) {
        throw Exception('Cannot ban group administrators');
      }

      // Create ban record
      await _supabaseService.client.from('group_bans').insert({
        'id': _uuid.v4(),
        'group_id': groupId,
        'user_id': userId,
        'banned_by': adminUser.id,
        'banned_at': DateTime.now().toIso8601String(),
        'reason': reason,
        'is_active': true,
      });

      // Remove user from group
      final updatedMemberIds = List<String>.from(group.memberIds)
        ..remove(userId);
      await _supabaseService.updateGroup(groupId, {
        'member_ids': updatedMemberIds,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': adminUser.id,
      });

      // Remove group from user's list
      final userData = await _supabaseService.client
          .from(SupabaseService.usersTable)
          .select('group_ids')
          .eq('id', userId)
          .single();

      final userGroupIds = List<String>.from(userData['group_ids'] ?? []);
      userGroupIds.remove(groupId);

      await _supabaseService.client
          .from(SupabaseService.usersTable)
          .update({
            'group_ids': userGroupIds,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      print('Error banning user: $e');
      if (e.toString().contains('not a member')) {
        throw Exception('User is not a member of this group');
      } else if (e.toString().contains('not an admin')) {
        throw Exception('Only group admins can ban users');
      } else if (e.toString().contains('cannot ban admins')) {
        throw Exception('Cannot ban group administrators');
      }
      throw Exception('Failed to ban user: ${e.toString()}');
    }
  }

  // Unban a user from a group
  Future<void> unbanUser(String groupId, String userId) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final adminUser = _authService.currentUser!;

    try {
      final group = await getGroup(groupId);

      // Check admin permissions
      if (!group.isAdmin(adminUser.id)) {
        throw Exception('Only group admins can unban users');
      }

      // Check if user is actually banned
      final banRecord = await _supabaseService.client
          .from('group_bans')
          .select()
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (banRecord == null) {
        throw Exception('User is not banned from this group');
      }

      // Update ban record
      await _supabaseService.client
          .from('group_bans')
          .update({
            'is_active': false,
            'unbanned_by': adminUser.id,
            'unbanned_at': DateTime.now().toIso8601String(),
          })
          .eq('id', banRecord['id']);
    } catch (e) {
      print('Error unbanning user: $e');
      if (e.toString().contains('not banned')) {
        throw Exception('User is not banned from this group');
      } else if (e.toString().contains('not an admin')) {
        throw Exception('Only group admins can unban users');
      }
      throw Exception('Failed to unban user: ${e.toString()}');
    }
  }

  // Mute a user in a group
  Future<void> muteUser(
    String groupId,
    String userId, {
    String? reason,
    Duration duration = const Duration(hours: 24),
  }) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final adminUser = _authService.currentUser!;

    try {
      final group = await getGroup(groupId);

      // Check admin permissions
      if (!group.isAdmin(adminUser.id)) {
        throw Exception('Only group admins can mute users');
      }

      // Check if user is a member
      if (!group.isMember(userId)) {
        throw Exception('User is not a member of this group');
      }

      // Cannot mute group admins
      if (group.isAdmin(userId)) {
        throw Exception('Cannot mute group administrators');
      }

      // Create mute record
      final muteExpiresAt = DateTime.now().add(duration);
      await _supabaseService.client.from('group_mutes').insert({
        'id': _uuid.v4(),
        'group_id': groupId,
        'user_id': userId,
        'muted_by': adminUser.id,
        'muted_at': DateTime.now().toIso8601String(),
        'expires_at': muteExpiresAt.toIso8601String(),
        'reason': reason,
        'is_active': true,
      });
    } catch (e) {
      print('Error muting user: $e');
      if (e.toString().contains('not a member')) {
        throw Exception('User is not a member of this group');
      } else if (e.toString().contains('not an admin')) {
        throw Exception('Only group admins can mute users');
      } else if (e.toString().contains('cannot mute admins')) {
        throw Exception('Cannot mute group administrators');
      }
      throw Exception('Failed to mute user: ${e.toString()}');
    }
  }

  // Get group key for decryption
  Future<String> _getGroupKey(String groupId) async {
    try {
      // First try to get from local storage
      final storedKey = await _encryptionUtils.getGroupKey(groupId);
      if (storedKey != null) {
        return storedKey;
      }

      // If not found locally, try to decrypt using master key
      final group = await getGroup(groupId);
      if (group.encryptedKey == null) {
        throw Exception('Group encryption key not found');
      }

      final masterKey = await _getMasterKey();
      final decryptedKey = _encryptionUtils.decryptData(
        group.encryptedKey!,
        masterKey,
      );

      // Store for future use
      await _encryptionUtils.storeGroupKey(groupId, decryptedKey);
      return decryptedKey;
    } catch (e) {
      print('Error getting group key: $e');
      throw Exception('Could not get group key: ${e.toString()}');
    }
  }

  // Decrypt a message with access check
  Future<String> decryptMessage(String groupId, String encryptedMessage) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;

    try {
      // Check if user can read messages
      final hasAccess = await canReadMessages(groupId);
      if (!hasAccess) {
        throw Exception(
          'You do not have permission to read messages in this group',
        );
      }

      // Get the group key
      final groupKey = await _getGroupKey(groupId);

      // Record the read access
      await _supabaseService.client
          .from('message_reads')
          .insert({
            'id': _uuid.v4(),
            'message_id':
                encryptedMessage, // Using encrypted message as ID for demo
            'group_id': groupId,
            'user_id': user.id,
            'read_at': DateTime.now().toIso8601String(),
          })
          .onError((error, stackTrace) {
            // Ignore duplicate read records
            print('Warning: Could not record message read: $error');
            return null;
          });

      // Decrypt and return the message
      return _encryptionUtils.decryptData(encryptedMessage, groupKey);
    } catch (e) {
      print('Error decrypting message: $e');
      if (e.toString().contains('not authenticated')) {
        throw Exception('You must be logged in to read messages');
      } else if (e.toString().contains('permission')) {
        throw Exception(
          'You do not have permission to read messages in this group',
        );
      } else if (e.toString().contains('key not found')) {
        throw Exception('Could not decrypt message: Group key not found');
      }
      throw Exception('Could not decrypt message: ${e.toString()}');
    }
  }

  // Get message read receipts
  Future<List<Map<String, dynamic>>> getMessageReadReceipts(
    String groupId,
    String messageId,
  ) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final user = _authService.currentUser!;

    try {
      final group = await getGroup(groupId);
      if (!group.isMember(user.id)) {
        throw Exception('You are not a member of this group');
      }

      final response = await _supabaseService.client
          .from('message_reads')
          .select('user_id, read_at')
          .eq('message_id', messageId)
          .eq('group_id', groupId)
          .order('read_at');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting read receipts: $e');
      throw Exception('Could not get read receipts: ${e.toString()}');
    }
  }

  // Unmute a user in a group
  Future<void> unmuteUser(String groupId, String userId) async {
    if (!_authService.isAuthenticated) {
      throw Exception('User not authenticated');
    }

    final adminUser = _authService.currentUser!;

    try {
      final group = await getGroup(groupId);

      // Check admin permissions
      if (!group.isAdmin(adminUser.id)) {
        throw Exception('Only group admins can unmute users');
      }

      // Check if user is actually muted
      final muteRecord = await _supabaseService.client
          .from('group_mutes')
          .select()
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (muteRecord == null) {
        throw Exception('User is not muted in this group');
      }

      // Update mute record
      await _supabaseService.client
          .from('group_mutes')
          .update({
            'is_active': false,
            'unmuted_by': adminUser.id,
            'unmuted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', muteRecord['id']);
    } catch (e) {
      print('Error unmuting user: $e');
      if (e.toString().contains('not muted')) {
        throw Exception('User is not muted in this group');
      } else if (e.toString().contains('not an admin')) {
        throw Exception('Only group admins can unmute users');
      }
      throw Exception('Failed to unmute user: ${e.toString()}');
    }
  }
}
