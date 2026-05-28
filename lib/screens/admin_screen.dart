import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../providers/auth_provider.dart';
import '../models/group.dart';
import 'group_requests_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    return Consumer2<GroupProvider, AuthProvider>(
      builder: (context, groupProvider, authProvider, child) {
        final user = authProvider.user!;
        final isHqAdmin = user.isHqAdmin;

        return Scaffold(
          body: Column(
            children: [
              // Admin Stats
              Container(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.admin_panel_settings, color: Color(0xFF00C6AE)),
                            const SizedBox(width: 8),
                            Text(
                              isHqAdmin ? 'HQ COMMAND OVERVIEW' : 'SQUAD COMMAND OVERVIEW',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: Color(0xFFE8ECF2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatCard(
                              title: 'SQUADS',
                              value: groupProvider.groups.length.toString(),
                              icon: Icons.group_work_outlined,
                            ),
                            _StatCard(
                              title: 'ACTIVE',
                              value: groupProvider.groups
                                  .where((g) => g.isActive)
                                  .length
                                  .toString(),
                              icon: Icons.radar,
                            ),
                            if (isHqAdmin)
                              _StatCard(
                                title: 'OPERATIVES',
                                value: groupProvider.groups
                                    .fold<int>(0, (sum, g) => sum + g.memberCount)
                                    .toString(),
                                icon: Icons.people_outline,
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
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C6AE)))
                    : groupProvider.groups.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 64,
                                  color: const Color(0xFF8A9AB5).withOpacity(0.3),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'NO COMMANDS ASSIGNED',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  isHqAdmin
                                      ? 'System squads will appear here'
                                      : 'Establish a squad to begin command',
                                  style: const TextStyle(color: Color(0xFF8A9AB5)),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF00C6AE),
                            backgroundColor: const Color(0xFF182842),
                            onRefresh: () async {
                              if (isHqAdmin) {
                                await groupProvider.loadAllGroups();
                              } else {
                                await groupProvider.loadUserGroups();
                              }
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        title: const Text('ESTABLISH NEW SQUAD', style: TextStyle(letterSpacing: 1.2)),
        content: Column(
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
          size: 28,
          color: const Color(0xFF00C6AE),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFFE8ECF2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8A9AB5),
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
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1628),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00C6AE).withOpacity(0.3)),
                  ),
                  child: Text(
                    group.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF00C6AE),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
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
                            fontSize: 12,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
                if (group.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C6AE).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF00C6AE).withOpacity(0.3)),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Color(0xFF00C6AE),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5A5F).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
                    ),
                    child: const Text(
                      'INACTIVE',
                      style: TextStyle(
                        color: Color(0xFFFF5A5F),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_outline, size: 16, color: Color(0xFF00C6AE)),
                  const SizedBox(width: 8),
                  Text(
                    '${group.memberCount} OPs',
                    style: const TextStyle(color: Color(0xFFE8ECF2), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const Icon(Icons.vpn_key_outlined, size: 16, color: Color(0xFF00C6AE)),
                  const SizedBox(width: 8),
                  Text(
                    group.inviteCode,
                    style: const TextStyle(
                      color: Color(0xFFE8ECF2),
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isGroupAdmin || isHqAdmin) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      _showGroupDetailsDialog(context);
                    },
                    icon: const Icon(Icons.info_outline, size: 16),
                    label: const Text('DOSSIER'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111D33),
                      foregroundColor: const Color(0xFF00C6AE),
                      elevation: 0,
                      side: BorderSide(color: const Color(0xFF00C6AE).withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => GroupRequestsScreen(group: group),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add_alt, size: 16),
                    label: const Text('REQUESTS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111D33),
                      foregroundColor: const Color(0xFF00C6AE),
                      elevation: 0,
                      side: BorderSide(color: const Color(0xFF00C6AE).withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showInviteCodeDialog(context);
                    },
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('ACCESS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111D33),
                      foregroundColor: const Color(0xFF00C6AE),
                      elevation: 0,
                      side: BorderSide(color: const Color(0xFF00C6AE).withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
                if (isHqAdmin) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      _showDeactivateDialog(context);
                    },
                    icon: const Icon(Icons.block, size: 16),
                    label: const Text('DEACTIVATE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5A5F).withOpacity(0.15),
                      foregroundColor: const Color(0xFFFF5A5F),
                      elevation: 0,
                      side: BorderSide(color: const Color(0xFFFF5A5F).withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
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
        title: Text(group.name.toUpperCase(), style: const TextStyle(letterSpacing: 1.5)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (group.description.isNotEmpty) ...[
              const Text('MISSION OBJECTIVE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8A9AB5), letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(group.description),
              const SizedBox(height: 16),
            ],
            const Text('ACCESS CODE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8A9AB5), letterSpacing: 1)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00C6AE).withOpacity(0.3)),
              ),
              child: Text(
                group.inviteCode,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF00C6AE), fontSize: 16, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('OPERATIVES', style: TextStyle(color: Color(0xFF8A9AB5))),
                Text('${group.memberCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('COMMANDERS', style: TextStyle(color: Color(0xFF8A9AB5))),
                Text('${group.adminIds.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ESTABLISHED', style: TextStyle(color: Color(0xFF8A9AB5))),
                Text(_formatDate(group.createdAt), style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _showInviteCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SECURE ACCESS', style: TextStyle(letterSpacing: 1.2)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Provide this code to personnel needing squad access:'),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00C6AE).withOpacity(0.5)),
                ),
                child: Text(
                  group.inviteCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 4,
                    color: Color(0xFF00C6AE),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    
                    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
                    final newCode = await groupProvider.generateNewInviteCode(group.id);
                    
                    if (newCode != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Access code rotated successfully.'),
                          backgroundColor: Color(0xFF00C6AE),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.autorenew),
                  label: const Text('ROTATE ACCESS CODE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB547),
                    foregroundColor: const Color(0xFF0A1628),
                  ),
                ),
              ),
            ],
          ),
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

  void _showDeactivateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DEACTIVATE SQUAD', style: TextStyle(color: Color(0xFFFF5A5F), letterSpacing: 1.2)),
        content: Text('Are you sure you want to deactivate "${group.name}"? This action will freeze all comms.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final groupProvider = Provider.of<GroupProvider>(context, listen: false);
              final success = await groupProvider.deactivateGroup(group.id);
              
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Squad deactivated successfully'),
                    backgroundColor: Color(0xFF00C6AE),
                  ),
                );
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(groupProvider.error ?? 'Failed to deactivate squad'),
                    backgroundColor: const Color(0xFFFF5A5F),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5A5F),
              foregroundColor: Colors.white,
            ),
            child: const Text('DEACTIVATE'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
  }
}
