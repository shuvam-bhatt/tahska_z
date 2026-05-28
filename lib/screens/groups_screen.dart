import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
import '../models/group.dart';
import 'chat_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupProvider>(context, listen: false).loadUserGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<GroupProvider, AuthProvider>(
      builder: (context, groupProvider, authProvider, child) {
        return Scaffold(
          body: _buildBody(context, groupProvider, authProvider),
          floatingActionButton: authProvider.user?.isAdmin == true
              ? FloatingActionButton.extended(
                  onPressed: () {
                    _showCreateGroupDialog(context);
                  },
                  tooltip: 'Create Squad (Command Only)',
                  icon: const Icon(Icons.add),
                  label: const Text('NEW SQUAD'),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, GroupProvider groupProvider, AuthProvider authProvider) {
    if (groupProvider.isLoading && groupProvider.groups.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00C6AE)),
      );
    }

    if (groupProvider.error != null && groupProvider.groups.isEmpty) {
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
              'CONNECTION FAILED',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Color(0xFFE8ECF2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              groupProvider.error!,
              style: const TextStyle(color: Color(0xFF8A9AB5)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                groupProvider.loadUserGroups();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('RETRY CONNECTION'),
            ),
          ],
        ),
      );
    }

    if (groupProvider.groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_work_outlined,
              size: 80,
              color: const Color(0xFF8A9AB5).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'NO ACTIVE SQUADS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Color(0xFFE8ECF2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                authProvider.user?.isAdmin == true
                    ? 'Establish a new squad or connect via invite code'
                    : 'Awaiting assignment. Connect using a command invite code.',
                style: const TextStyle(color: Color(0xFF8A9AB5), height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            if (authProvider.user?.isAdmin == true)
              ElevatedButton.icon(
                onPressed: () {
                  _showCreateGroupDialog(context);
                },
                icon: const Icon(Icons.add),
                label: const Text('ESTABLISH SQUAD'),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  _showJoinGroupDialog(context);
                },
                icon: const Icon(Icons.login),
                label: const Text('CONNECT TO SQUAD'),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF00C6AE),
      backgroundColor: const Color(0xFF182842),
      onRefresh: () async {
        await groupProvider.loadUserGroups();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupProvider.groups.length,
        itemBuilder: (context, index) {
          final group = groupProvider.groups[index];
          return _GroupCard(
            group: group,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatScreen(group: group),
                ),
              );
            },
            onLeave: () {
              _showLeaveGroupDialog(context, group);
            },
          );
        },
      ),
    );
  }

  void _showJoinGroupDialog(BuildContext context) {
    final inviteCodeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CONNECT TO SQUAD', style: TextStyle(letterSpacing: 1.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the secure access code provided by command:',
              style: TextStyle(color: Color(0xFF8A9AB5), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: inviteCodeController,
              decoration: const InputDecoration(
                labelText: 'Access Code',
                hintText: 'e.g., ALPHA1',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          Consumer<GroupProvider>(
            builder: (context, groupProvider, child) {
              return ElevatedButton(
                onPressed: groupProvider.isLoading ? null : () async {
                  if (inviteCodeController.text.trim().isNotEmpty) {
                    Navigator.of(context).pop();
                    
                    final success = await groupProvider.requestToJoinGroup(inviteCodeController.text.trim());
                    
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Access requested. Awaiting command clearance.'),
                          backgroundColor: Color(0xFFFFB547), // Gold
                        ),
                      );
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(groupProvider.error ?? 'Access denied'),
                          backgroundColor: const Color(0xFFFF5A5F), // Danger
                        ),
                      );
                    }
                  }
                },
                child: groupProvider.isLoading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A1628)),
                      )
                    : const Text('REQUEST ACCESS'),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ESTABLISH SQUAD', style: TextStyle(letterSpacing: 1.5)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Squad Designation',
                  prefixIcon: Icon(Icons.group_work_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Mission Objective',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
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
                      content: Text('Squad established successfully.'),
                      backgroundColor: Color(0xFF00C6AE),
                    ),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(groupProvider.error ?? 'Failed to establish squad'),
                      backgroundColor: const Color(0xFFFF5A5F),
                    ),
                  );
                }
              }
            },
            child: const Text('AUTHORIZE'),
          ),
        ],
      ),
    );
  }

  void _showLeaveGroupDialog(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SEVER CONNECTION', style: TextStyle(color: Color(0xFFFF5A5F), letterSpacing: 1.5)),
        content: Text('Are you sure you want to sever connection with squad "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final groupProvider = Provider.of<GroupProvider>(context, listen: false);
              final success = await groupProvider.leaveGroup(group.id);
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connection severed.'),
                    backgroundColor: Color(0xFF00C6AE),
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(groupProvider.error ?? 'Failed to sever connection'),
                    backgroundColor: const Color(0xFFFF5A5F),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A5F),
              foregroundColor: Colors.white,
            ),
            child: const Text('SEVER'),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  final VoidCallback onLeave;

  const _GroupCard({
    required this.group,
    required this.onTap,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00C6AE).withOpacity(0.5)),
                ),
                child: Center(
                  child: Text(
                    group.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF00C6AE),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFFE8ECF2),
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (group.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8A9AB5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people_outline, size: 14, color: Color(0xFF00C6AE)),
                        const SizedBox(width: 4),
                        Text(
                          '${group.memberCount} OP',
                          style: const TextStyle(color: Color(0xFF8A9AB5), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.vpn_key_outlined, size: 14, color: Color(0xFF00C6AE)),
                        const SizedBox(width: 4),
                        Text(
                          group.inviteCode,
                          style: const TextStyle(
                            color: Color(0xFF8A9AB5),
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF8A9AB5)),
                onSelected: (value) {
                  switch (value) {
                    case 'leave':
                      onLeave();
                      break;
                    case 'invite':
                      _showInviteCodeDialog(context);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'invite',
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 20, color: Color(0xFF00C6AE)),
                        SizedBox(width: 12),
                        Text('Share Access Code'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'leave',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app, size: 20, color: Color(0xFFFF5A5F)),
                        SizedBox(width: 12),
                        Text('Sever Connection', style: TextStyle(color: Color(0xFFFF5A5F))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SECURE ACCESS CODE', style: TextStyle(letterSpacing: 1.2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Distribute this code for operative onboarding:',
              style: TextStyle(color: Color(0xFF8A9AB5), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00C6AE).withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      group.inviteCode,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: Color(0xFF00C6AE),
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
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
}
