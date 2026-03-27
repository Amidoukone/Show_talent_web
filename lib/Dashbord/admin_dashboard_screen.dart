import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/user_controller.dart';
import '../controller/video_controller.dart';
import 'blocked_users_widget.dart';
import 'managed_accounts_widget.dart';
import 'statistiques_screen.dart';
import 'user_management_widget.dart';
import 'video_added_widget.dart';
import 'video_reported_widget.dart';

class AdminDashboardScreen extends StatefulWidget {
  AdminDashboardScreen({super.key});

  final UserController userController = Get.find<UserController>();
  final VideoController videoController = Get.find<VideoController>();

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isAuthorizing = true;

  @override
  void initState() {
    super.initState();
    _guardDashboardAccess();
  }

  List<Widget> _widgetOptions() {
    return [
      const UserManagementWidget(selectedRole: 'Tous'),
      const ManagedAccountsWidget(),
      const VideoAddedWidget(),
      const VideoReportedWidget(),
      const BlockedUsersWidget(),
      StatisticsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _guardDashboardAccess() async {
    final accessResult = await widget.userController.evaluateAdminAccess(
      forceRefresh: true,
    );

    if (!mounted) {
      return;
    }

    if (!accessResult.isAuthorized) {
      Get.snackbar('Acces refuse', accessResult.message ?? 'Acces refuse.');
      await widget.userController.signOut();
      return;
    }

    setState(() {
      _isAuthorizing = false;
    });
  }

  Widget _buildSelectedIcon(IconData icon) {
    return Container(
      color: const Color(0xFF1A3D3B),
      child: Icon(icon, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthorizing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 40),
            const SizedBox(width: 8),
            const Text('AD.FOOT'),
          ],
        ),
        backgroundColor: const Color(0xFF214D4F),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () => widget.userController.signOut(),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedIconTheme: const IconThemeData(color: Colors.black54),
            selectedLabelTextStyle:
                const TextStyle(color: Color.fromARGB(255, 14, 47, 43)),
            unselectedLabelTextStyle: const TextStyle(color: Colors.black54),
            leading: Container(),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.people),
                selectedIcon: _buildSelectedIcon(Icons.people),
                label: const Text('Utilisateurs'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.person_add_alt_1),
                selectedIcon: _buildSelectedIcon(Icons.person_add_alt_1),
                label: const Text('Comptes geres'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.video_library),
                selectedIcon: _buildSelectedIcon(Icons.video_library),
                label: const Text('Videos ajoutees'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.report),
                selectedIcon: _buildSelectedIcon(Icons.report),
                label: const Text('Videos signalees'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.block),
                selectedIcon: _buildSelectedIcon(Icons.block),
                label: const Text('Utilisateurs bloques'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.bar_chart),
                selectedIcon: _buildSelectedIcon(Icons.bar_chart),
                label: const Text('Statistiques'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _widgetOptions()[_selectedIndex],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
