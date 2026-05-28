import 'package:flutter/foundation.dart';
import '../models/group.dart';
import '../models/group_join_request.dart';
import '../services/group_service.dart';

class GroupProvider with ChangeNotifier {
  final GroupService _groupService = GroupService();
  
  List<Group> _groups = [];
  bool _isLoading = false;
  String? _error;

  List<Group> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUserGroups() async {
    _setLoading(true);
    _clearError();
    
    try {
      final groups = await _groupService.getUserGroups();
      _groups = groups;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load groups: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAllGroups() async {
    _setLoading(true);
    _clearError();
    
    try {
      final groups = await _groupService.getAllGroups();
      _groups = groups;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load all groups: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createGroup(String name, String description) async {
    _setLoading(true);
    _clearError();
    
    try {
      final group = await _groupService.createGroup(name, description);
      _groups.add(group);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to create group: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> requestToJoinGroup(String inviteCode) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Clean the input
      final cleanCode = inviteCode.trim().toUpperCase();
      
      if (cleanCode.isEmpty) {
        _setError('Please enter a valid invite code');
        return false;
      }
      
      await _groupService.requestToJoinGroup(cleanCode);
      notifyListeners();
      return true;
    } catch (e) {
      print('Request to join group error: $e');
      // Provide more specific error messages
      if (e.toString().contains('Invalid invite code')) {
        _setError('Invalid invite code. Please check with your commanding officer.');
      } else if (e.toString().contains('already a member')) {
        _setError('You are already a member of this group.');
      } else if (e.toString().contains('pending request')) {
        _setError('You already have a pending request for this group.');
      } else if (e.toString().contains('not authenticated')) {
        _setError('Please log in again to continue.');
      } else {
        _setError('Failed to send join request. Please try again.');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> joinGroup(String inviteCode) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Clean the input
      final cleanCode = inviteCode.trim().toUpperCase();
      
      if (cleanCode.isEmpty) {
        _setError('Please enter a valid invite code');
        return false;
      }
      
      // First try to join directly with the invite code as a join token
      try {
        await _groupService.joinGroupWithToken(cleanCode);
        await loadUserGroups(); // Refresh groups list
        return true;
      } catch (e) {
        print('Token join failed, trying invite code: $e');
        // If that fails, treat it as a regular invite code and request to join
        try {
          await _groupService.requestToJoinGroup(cleanCode);
          return true;
        } catch (e2) {
          print('Invite code join failed: $e2');
          // If both fail, provide a more helpful error message
          if (e2.toString().contains('Invalid invite code')) {
            _setError('Invalid invite code. Please check with your commanding officer.');
          } else if (e2.toString().contains('already a member')) {
            _setError('You are already a member of this group.');
          } else if (e2.toString().contains('pending request')) {
            _setError('You already have a pending request for this group.');
          } else {
            _setError('Failed to join group. Please check the invite code and try again.');
          }
          return false;
        }
      }
    } catch (e) {
      print('Unexpected error in joinGroup: $e');
      _setError('An unexpected error occurred. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> leaveGroup(String groupId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _groupService.leaveGroup(groupId);
      _groups.removeWhere((group) => group.id == groupId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to leave group: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Admin functions for managing join requests
  Future<List<GroupJoinRequest>> getPendingJoinRequests(String groupId) async {
    try {
      return await _groupService.getPendingJoinRequests(groupId);
    } catch (e) {
      _setError('Failed to get join requests: $e');
      return [];
    }
  }

  Future<bool> approveJoinRequest(String requestId, {String? reviewNotes}) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _groupService.approveJoinRequest(requestId, reviewNotes: reviewNotes);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to approve request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> rejectJoinRequest(String requestId, {String? reviewNotes}) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _groupService.rejectJoinRequest(requestId, reviewNotes: reviewNotes);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to reject request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<Group?> getGroup(String groupId) async {
    try {
      return await _groupService.getGroup(groupId);
    } catch (e) {
      _setError('Failed to get group: $e');
      return null;
    }
  }

  Future<bool> updateGroup(String groupId, {String? name, String? description}) async {
    _setLoading(true);
    _clearError();
    
    try {
      final updatedGroup = await _groupService.updateGroup(
        groupId,
        name: name,
        description: description,
      );
      
      final index = _groups.indexWhere((group) => group.id == groupId);
      if (index >= 0) {
        _groups[index] = updatedGroup;
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      _setError('Failed to update group: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addGroupAdmin(String groupId, String userId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _groupService.addGroupAdmin(groupId, userId);
      
      // Reload groups to get updated data
      await loadUserGroups();
      
      return true;
    } catch (e) {
      _setError('Failed to add group admin: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> removeGroupAdmin(String groupId, String userId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _groupService.removeGroupAdmin(groupId, userId);
      
      // Reload groups to get updated data
      await loadUserGroups();
      
      return true;
    } catch (e) {
      _setError('Failed to remove group admin: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deactivateGroup(String groupId) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _groupService.deactivateGroup(groupId);
      _groups.removeWhere((group) => group.id == groupId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to deactivate group: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> generateNewInviteCode(String groupId) async {
    _setLoading(true);
    _clearError();
    
    try {
      final newInviteCode = await _groupService.generateNewInviteCode(groupId);
      
      // Update the group in the list
      final index = _groups.indexWhere((group) => group.id == groupId);
      if (index >= 0) {
        _groups[index] = _groups[index].copyWith(inviteCode: newInviteCode);
        notifyListeners();
      }
      
      return newInviteCode;
    } catch (e) {
      _setError('Failed to generate new invite code: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> generateJoinToken(String groupId) async {
    _setLoading(true);
    _clearError();
    
    try {
      final joinToken = await _groupService.generateJoinToken(groupId);
      return joinToken;
    } catch (e) {
      _setError('Failed to generate join token: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> joinGroupWithToken(String token) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _groupService.joinGroupWithToken(token);
      
      // Reload groups to get updated data
      await loadUserGroups();
      
      return true;
    } catch (e) {
      _setError('Failed to join group with token: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearGroups() {
    _groups.clear();
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
}
