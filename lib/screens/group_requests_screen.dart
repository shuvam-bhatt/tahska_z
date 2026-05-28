import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../models/group.dart';

class GroupRequestsScreen extends StatefulWidget {
  final Group group;

  const GroupRequestsScreen({super.key, required this.group});

  @override
  State<GroupRequestsScreen> createState() => _GroupRequestsScreenState();
}

class _GroupRequestsScreenState extends State<GroupRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupProvider>(context, listen: false).loadPendingRequests(widget.group.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'ACCESS REQUESTS',
              style: const TextStyle(letterSpacing: 1.5, fontSize: 16),
            ),
            Text(
              widget.group.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF00C6AE),
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
      body: Consumer<GroupProvider>(
        builder: (context, groupProvider, child) {
          if (groupProvider.isLoading && groupProvider.pendingRequests.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00C6AE)));
          }

          if (groupProvider.pendingRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: const Color(0xFF8A9AB5).withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'NO PENDING REQUESTS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'All access requests have been processed.',
                    style: TextStyle(color: Color(0xFF8A9AB5)),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(0xFF00C6AE),
            backgroundColor: const Color(0xFF182842),
            onRefresh: () async {
              await groupProvider.loadPendingRequests(widget.group.id);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: groupProvider.pendingRequests.length,
              itemBuilder: (context, index) {
                final request = groupProvider.pendingRequests[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1628),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF00C6AE).withOpacity(0.3)),
                          ),
                          child: const Icon(Icons.person_outline, color: Color(0xFF00C6AE)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.userName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Requested access: ${_formatDate(request.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8A9AB5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Color(0xFFFF5A5F)),
                              onPressed: () => _handleRequest(context, request, false),
                              tooltip: 'Deny Access',
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: Color(0xFF00C6AE)),
                              onPressed: () => _handleRequest(context, request, true),
                              tooltip: 'Approve Access',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleRequest(BuildContext context, GroupRequest request, bool approve) async {
    final groupProvider = Provider.of<GroupProvider>(context, listen: false);
    final success = await groupProvider.handleJoinRequest(
      request.id,
      request.groupId,
      request.userId,
      approve,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Access approved.' : 'Access denied.'),
          backgroundColor: approve ? const Color(0xFF00C6AE) : const Color(0xFFFF5A5F),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(groupProvider.error ?? 'Failed to process request.'),
          backgroundColor: const Color(0xFFFF5A5F),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
  }
}
