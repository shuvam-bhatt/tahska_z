import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../utils/containment_utils.dart';
import 'groups_screen.dart';
import 'admin_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Activate containment
    ContainmentUtils().activateContainment(
      onScreenshotDetected: () {
        SecurityWarning.showScreenshotWarning(context);
      },
    );
    
    // Load user groups
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<GroupProvider>(context, listen: false).loadUserGroups();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    ContainmentUtils().deactivateContainment();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isAuthenticated) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = authProvider.user!;
        final isAdmin = user.isAdmin;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sentinel'),
            actions: [
              // Security info button
              IconButton(
                icon: const Icon(Icons.security),
                onPressed: () {
                  SecurityWarning.showSecurityInfo(context);
                },
                tooltip: 'Security Features',
              ),
              // Profile button
              IconButton(
                icon: const Icon(Icons.person),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                tooltip: 'Profile',
              ),
            ],
          ),
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: isAdmin ? [
              // Groups Tab
              const GroupsScreen(),
              // Admin Tab
              const AdminScreen(),
            ] : [
              // Groups Tab
              const GroupsScreen(),
              // Info Tab
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info, size: 64, color: Color(0xFF1B365D)),
                    SizedBox(height: 16),
                    Text(
                      'Sentinel Security Platform',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B365D),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Secure Communication for Defense Personnel',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF1B365D),
            unselectedItemColor: Colors.grey,
            items: isAdmin ? [
              const BottomNavigationBarItem(
                icon: Icon(Icons.group),
                label: 'Groups',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.admin_panel_settings),
                label: 'Admin',
              ),
            ] : [
              const BottomNavigationBarItem(
                icon: Icon(Icons.group),
                label: 'Groups',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.info),
                label: 'Info',
              ),
            ],
          ),
          floatingActionButton: _currentIndex == 0
              ? FloatingActionButton(
                  onPressed: () {
                    _showJoinGroupDialog(context);
                  },
                  backgroundColor: const Color(0xFF1B365D),
                  child: const Icon(Icons.add, color: Colors.white),
                )
              : null,
        );
      },
    );
  }

  void _showJoinGroupDialog(BuildContext context) {
    final inviteCodeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the invite code to join a group:'),
              const SizedBox(height: 16),
              SecureTextField(
                controller: inviteCodeController,
                hintText: 'Invite Code',
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.vpn_key),
                  labelText: 'Invite Code',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          Consumer<GroupProvider>(
            builder: (context, groupProvider, child) {
              return ElevatedButton(
                onPressed: groupProvider.isLoading ? null : () async {
                  if (inviteCodeController.text.trim().isNotEmpty) {
                    Navigator.of(context).pop();
                    
                    final success = await groupProvider.joinGroup(inviteCodeController.text.trim());
                    
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Successfully joined the group!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(groupProvider.error ?? 'Failed to join group'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: groupProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Join'),
              );
            },
          ),
        ],
      ),
    );
  }
}
