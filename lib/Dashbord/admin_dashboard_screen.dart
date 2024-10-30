import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:show_talent/Dashbord/statistiques_screen.dart';
import 'package:show_talent/Dashbord/user_management_widget.dart';
import 'package:show_talent/Dashbord/video_added_widget.dart';
import 'package:show_talent/Dashbord/blocked_users_widget.dart';
import 'package:show_talent/Dashbord/video_reported_widget.dart';
import '../controller/user_controller.dart';
import '../controller/video_controller.dart';

class AdminDashboardScreen extends StatefulWidget {
  final UserController userController = Get.find<UserController>();
  final VideoController videoController = Get.find<VideoController>();

  AdminDashboardScreen({super.key});

  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  // Liste des widgets correspondant aux pages
  List<Widget> _widgetOptions() {
    return [
      UserManagementWidget(selectedRole: 'Tous'), // Gestion des utilisateurs
      VideoAddedWidget(), // Vidéos ajoutées
      VideoReportedWidget(), // Vidéos signalées
      BlockedUsersWidget(), // Utilisateurs bloqués
      StatisticsScreen(), // Page des statistiques
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Met à jour l'index sélectionné
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 40,
            ),
            const SizedBox(width: 8),
            const Text('AD.FOOT'),
          ],
        ),
        backgroundColor: const Color(0xFF214D4F),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () {
              widget.userController.signOut();
              Get.offAllNamed('/admin-login');
            },
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            labelType: NavigationRailLabelType.all, // Texte visible au survol
            backgroundColor: Colors.white,
            selectedIconTheme: const IconThemeData(color: Colors.white), // Icône blanche lorsque sélectionnée
            unselectedIconTheme: const IconThemeData(color: Colors.black54), // Icône grise lorsqu'elle n'est pas sélectionnée
            selectedLabelTextStyle: const TextStyle(color: Color.fromARGB(255, 14, 47, 43)), // Texte blanc pour l'option sélectionnée
            unselectedLabelTextStyle: const TextStyle(color: Colors.black54), // Texte gris pour l'option non sélectionnée
            leading: Container(), // Option pour personnaliser l'espace en haut
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.people),
                selectedIcon: Container(
                  color: const Color(0xFF1A3D3B), // Arrière-plan vert foncé pour l'option sélectionnée
                  child: const Icon(Icons.people, color: Colors.white), // Icône blanche
                ),
                label: const Text('Utilisateurs'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.video_library),
                selectedIcon: Container(
                  color: const Color(0xFF1A3D3B), // Arrière-plan vert foncé
                  child: const Icon(Icons.video_library, color: Colors.white), // Icône blanche
                ),
                label: const Text('Vidéos ajoutées'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.report),
                selectedIcon: Container(
                  color: const Color(0xFF1A3D3B), // Arrière-plan vert foncé
                  child: const Icon(Icons.report, color: Colors.white), // Icône blanche
                ),
                label: const Text('Vidéos signalées'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.block),
                selectedIcon: Container(
                  color: const Color(0xFF1A3D3B), // Arrière-plan vert foncé
                  child: const Icon(Icons.block, color: Colors.white), // Icône blanche
                ),
                label: const Text('Utilisateurs bloqués'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.bar_chart),
                selectedIcon: Container(
                  color: const Color(0xFF1A3D3B), // Arrière-plan vert foncé
                  child: const Icon(Icons.bar_chart, color: Colors.white), // Icône blanche
                ),
                label: const Text('Statistiques'), // Texte pour l'icône de statistiques
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
