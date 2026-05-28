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
            leading: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Icon(Icons.shield_outlined, color: Color(0xFF00C6AE)),
            ),
            title: const Text('AEGIS'),
            actions: [
              // Security info button
              IconButton(
                icon: const Icon(Icons.security, color: Color(0xFF00C6AE)),
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
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF182842),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF00C6AE).withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00C6AE).withOpacity(0.1),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.shield_outlined, size: 50, color: Color(0xFF00C6AE)),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'AEGIS PROTOCOL',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE8ECF2),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'SECURE COMMUNICATION MATRIX',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF00C6AE),
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
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
            items: isAdmin ? [
              const BottomNavigationBarItem(
                icon: Icon(Icons.group_work_outlined),
                activeIcon: Icon(Icons.group_work),
                label: 'Squads',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.admin_panel_settings_outlined),
                activeIcon: Icon(Icons.admin_panel_settings),
                label: 'Command',
              ),
            ] : [
              const BottomNavigationBarItem(
                icon: Icon(Icons.group_work_outlined),
                activeIcon: Icon(Icons.group_work),
                label: 'Squads',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.info_outline),
                activeIcon: Icon(Icons.info),
                label: 'Protocol',
              ),
            ],
          ),
        );
      },
    );
  }
}
