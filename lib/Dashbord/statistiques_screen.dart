import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controller/user_controller.dart';
import '../controller/video_controller.dart';

class StatisticsScreen extends StatelessWidget {
  final UserController userController = Get.find<UserController>();
  final VideoController videoController = Get.find<VideoController>();

  StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Center(
              child: Text(
                'Statistiques',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF214D4F), // Couleur vert foncé
                ),
              ),
            ),
            const SizedBox(height: 20), // Espacement sous le titre
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Espacement égal entre les cartes
              children: [
                Expanded(
                  child: _buildStatCard(
                    color: Colors.green,
                    title: 'Utilisateurs',
                    value: userController.userList.length,
                  ),
                ),
                const SizedBox(width: 16), // Espacement entre les cartes
                Expanded(
                  child: _buildStatCard(
                    color: Colors.blue,
                    title: 'Vidéos ajoutées',
                    value: videoController.videoList.length,
                  ),
                ),
                const SizedBox(width: 16), // Espacement entre les cartes
                Expanded(
                  child: _buildStatCard(
                    color: Colors.red,
                    title: 'Vidéos signalées',
                    value: videoController.getReportedVideos().length,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required Color color, required String title, required int value}) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white, // Fond blanc pour les cartes
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}