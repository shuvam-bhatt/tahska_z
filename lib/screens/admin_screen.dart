import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
import '../models/group.dart';
import '../models/group_join_request.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user?.isHqAdmin == true) {
        Provider.of<GroupProvider>(context, listen: false).loadAllGroups();
      } else {
        Provider.of<GroupProvider>(context, listen: false).loadUserGroups();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<GroupProvider, AuthProvider>(
      builder: (context, groupProvider, authProvider, child) {
        final user = authProvider.user!;
        final isHqAdmin = user.isHqAdmin;

        return Scaffold(
          appBar: AppBar(
            title: Text(isHqAdmin ? 'HQ Admin Panel' : 'Group Admin'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  if (isHqAdmin) {
                    groupProvider.loadAllGroups();
                  } else {
                    groupProvider.loadUserGroups();
                  }
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.group), text: 'Groups'),
                Tab(icon: Icon(Icons.person_add), text: 'Join Requests'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Groups Tab
              Column(
                children: [
                  // Admin Stats
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHqAdmin ? 'System Overview' : 'Your Groups',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _StatCard(
                                  title: 'Total Groups',
                                  value: groupProvider.groups.length.toString(),
                                  icon: Icons.group,
                                ),
                                _StatCard(
                                  title: 'Active Groups',
                                  value: groupProvider.groups
                                      .where((g) => g.isActive)
                                      .length
                                      .toString(),
                                  icon: Icons.group_work,
                                ),
                                if (isHqAdmin)
                                  _StatCard(
                                    title: 'Total Members',
                                    value: groupProvider.groups
                                        .fold<int>(0, (sum, g) => sum + g.memberCount)
                                        .toString(),
                                    icon: Icons.people,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Groups List
                  Expanded(
                    child: groupProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : groupProvider.groups.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.admin_panel_settings_outlined,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No groups to manage',
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isHqAdmin
                                          ? 'All groups will appear here'
                                          : 'Create a group to get started',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () async {
                                  if (isHqAdmin) {
                                    await groupProvider.loadAllGroups();
                                  } else {
                                    await groupProvider.loadUserGroups();
                                  }
                                },
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: groupProvider.groups.length,
                                  itemBuilder: (context, index) {
                                    final group = groupProvider.groups[index];
                                    return _AdminGroupCard(
                                      group: group,
                                      isHqAdmin: isHqAdmin,
                                      currentUserId: user.id,
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
              // Join Requests Tab
              _JoinRequestsTab(isHqAdmin: isHqAdmin, currentUserId: user.id),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              _showCreateGroupDialog(context);
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                
                final groupProvider = Provider.of<GroupProvider>(context, listen: false);
                final success = await groupProvider.createGroup(
                  nameController.text.trim(),
                  descriptionController.text.trim(),
                );
                
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Group created successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(groupProvider.error ?? 'Failed to create group'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 32,
          color: const Color(0xFF1B365D),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B365D),
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _AdminGroupCard extends StatelessWidget {
  final Group group;
  final bool isHqAdmin;
  final String currentUserId;

  const _AdminGroupCard({
    required this.group,
    required this.isHqAdmin,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isGroupAdmin = group.isAdmin(currentUserId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1B365D),
                  child: Text(
                    group.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (group.description.isNotEmpty)
                        Text(
                          group.description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                if (group.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Inactive',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${group.memberCount} members',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(width: 16),
                Icon(Icons.vpn_key, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  group.inviteCode,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (isGroupAdmin || isHqAdmin) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      _showGroupDetailsDialog(context);
                    },
                    icon: const Icon(Icons.info, size: 16),
                    label: const Text('Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[100],
                      foregroundColor: Colors.blue[700],
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showInviteCodeDialog(context);
                    },
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Invite'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[100],
                      foregroundColor: Colors.green[700],
                      elevation: 0,
                    ),
                  ),
                ],
                if (isHqAdmin) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showDeactivateDialog(context);
                    },
                    icon: const Icon(Icons.block, size: 16),
                    label: const Text('Deactivate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[100],
                      foregroundColor: Colors.red[700],
                      elevation: 0,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.description.isNotEmpty) ...[
              const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(group.description),
              const SizedBox(height: 16),
            ],
            const Text('Invite Code:', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                group.inviteCode,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text('Members: ${group.memberCount}'),
            Text('Admins: ${group.adminIds.length}'),
            Text('Created: ${_formatDate(group.createdAt)}'),
            Text('Status: ${group.isActive ? 'Active' : 'Inactive'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showInviteCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Group Access'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose how to share group access:'),
              const SizedBox(height: 16),
              
              // Invite Code Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.vpn_key, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Invite Code',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Share this code for users to request joining:'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.inviteCode,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copy is disabled for security'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Join Token Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Join Token',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Generate a secure token for direct group joining:'),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final groupProvider = Provider.of<GroupProvider>(context, listen: false);
                          final token = await groupProvider.generateJoinToken(group.id);
                          
                          if (token != null && context.mounted) {
                            _showTokenDialog(context, token);
                          }
                        },
                        icon: const Icon(Icons.key, size: 18),
                        label: const Text('Generate Token'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Generate New Code Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    
                    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
                    final newCode = await groupProvider.generateNewInviteCode(group.id);
                    
                    if (newCode != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('New invite code generated!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Generate New Invite Code'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTokenDialog(BuildContext context, String token) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Token Generated'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Share this token with users for direct group joining:'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        token,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copy is disabled for security'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This token provides direct access. Share securely and use responsibly.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeactivateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Group'),
        content: Text('Are you sure you want to deactivate "${group.name}"? This will disable the group for all members.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final groupProvider = Provider.of<GroupProvider>(context, listen: false);
              final success = await groupProvider.deactivateGroup(group.id);
              
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Group deactivated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(groupProvider.error ?? 'Failed to deactivate group'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _JoinRequestsTab extends StatefulWidget {
  final bool isHqAdmin;
  final String currentUserId;

  const _JoinRequestsTab({
    required this.isHqAdmin,
    required this.currentUserId,
  });

  @override
  State<_JoinRequestsTab> createState() => _JoinRequestsTabState();
}

class _JoinRequestsTabState extends State<_JoinRequestsTab> {
  List<GroupJoinRequest> _allRequests = [];
  List<GroupJoinRequest> _filteredRequests = [];
  bool _isLoading = false;
  String? _error;
  String _selectedGroupId = 'all';

  @override
  void initState() {
    super.initState();
    _loadJoinRequests();
  }

  Future<void> _loadJoinRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      final allGroups = groupProvider.groups;
      
      List<GroupJoinRequest> allRequests = [];
      
      for (final group in allGroups) {
        // Check if user is admin of this group or is HQ admin
        if (group.isAdmin(widget.currentUserId) || widget.isHqAdmin) {
          try {
            final requests = await groupProvider.getPendingJoinRequests(group.id);
            allRequests.addAll(requests);
          } catch (e) {
            print('Error loading requests for group ${group.id}: $e');
          }
        }
      }
      
      setState(() {
        _allRequests = allRequests;
        _filteredRequests = allRequests;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterRequests(String groupId) {
    setState(() {
      _selectedGroupId = groupId;
      if (groupId == 'all') {
        _filteredRequests = _allRequests;
      } else {
        _filteredRequests = _allRequests.where((r) => r.groupId == groupId).toList();
      }
    });
  }

  Future<void> _approveRequest(GroupJoinRequest request) async {
    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      final success = await groupProvider.approveJoinRequest(request.id);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approved ${request.userName}\'s request'),
            backgroundColor: Colors.green,
          ),
        );
        _loadJoinRequests(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(GroupJoinRequest request) async {
    try {
      final groupProvider = Provider.of<GroupProvider>(context, listen: false);
      final success = await groupProvider.rejectJoinRequest(request.id);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected ${request.userName}\'s request'),
            backgroundColor: Colors.red,
          ),
        );
        _loadJoinRequests(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter dropdown
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Filter by Group:'),
              const SizedBox(width: 16),
              Expanded(
                child: Consumer<GroupProvider>(
                  builder: (context, groupProvider, child) {
                    final groups = groupProvider.groups.where((g) => 
                      g.isAdmin(widget.currentUserId) || widget.isHqAdmin
                    ).toList();
                    
                    return DropdownButton<String>(
                      value: _selectedGroupId,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Groups'),
                        ),
                        ...groups.map((group) => DropdownMenuItem(
                          value: group.id,
                          child: Text(group.name),
                        )),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          _filterRequests(value);
                        }
                      },
                    );
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadJoinRequests,
              ),
            ],
          ),
        ),
        
        // Requests List
        Expanded(
          child: _buildRequestsList(),
        ),
      ],
    );
  }

  Widget _buildRequestsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading requests',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadJoinRequests,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_disabled,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Pending Requests',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _selectedGroupId == 'all' 
                  ? 'No pending join requests across all groups.'
                  : 'No pending join requests for this group.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredRequests.length,
      itemBuilder: (context, index) {
        final request = _filteredRequests[index];
        return _RequestCard(
          request: request,
          onApprove: () => _approveRequest(request),
          onReject: () => _rejectRequest(request),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final GroupJoinRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1B365D),
                  child: Text(
                    request.userName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        request.userEmail,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Role: ${request.userRole}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PENDING',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (request.requestMessage != null && request.requestMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  request.requestMessage!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Requested: ${_formatDate(request.requestedAt)}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
