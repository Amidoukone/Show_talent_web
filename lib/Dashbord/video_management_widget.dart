import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/screens/video_player.dart';
import '../controller/video_controller.dart';
import '../controller/user_controller.dart';

class VideoManagementWidget extends StatefulWidget {
  const VideoManagementWidget({super.key});

  @override
  _VideoManagementWidgetState createState() => _VideoManagementWidgetState();
}

class _VideoManagementWidgetState extends State<VideoManagementWidget> {
  final VideoController videoController = Get.find<VideoController>();
  final UserController userController = Get.find<UserController>();
  String searchQuery = '';
  int currentPage = 0;
  static const int rowsPerPage = 4;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          width: MediaQuery.of(context).size.width * 0.95, // Élargir le tableau
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 8,
              ),
            ],
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête avec titre
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'Gestion des Vidéos',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              // Champ de recherche stylé
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Rechercher une vidéo',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                      currentPage = 0; // Réinitialise la page lors de la recherche
                    });
                  },
                ),
              ),
              Obx(() {
                final allVideos = videoController.getAllVideos();
                final filteredVideos = allVideos.where((video) {
                  return video.caption.toLowerCase().contains(searchQuery);
                }).toList();

                final totalPages = (filteredVideos.length / rowsPerPage).ceil();
                final startIndex = currentPage * rowsPerPage;
                final endIndex = (startIndex + rowsPerPage).clamp(0, filteredVideos.length);
                final displayedVideos = filteredVideos.sublist(startIndex, endIndex);

                return filteredVideos.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucune vidéo disponible.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : Column(
                        children: [
                          // Tableau stylisé des vidéos
                          DataTable(
                            columnSpacing: 24.0,
                            horizontalMargin: 12.0,
                            columns: const [
                              DataColumn(
                                label: Expanded(
                                  child: Text(
                                    'Aperçu',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Expanded(
                                  child: Text(
                                    'Titre',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Expanded(
                                  child: Text(
                                    'Ajouté par',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Expanded(
                                  child: Text(
                                    'Actions',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                            rows: List<DataRow>.generate(
                              displayedVideos.length,
                              (index) => DataRow(
                                cells: [
                                  DataCell(
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        displayedVideos[index].thumbnail,
                                        width: 80,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(
                                            Icons.video_library,
                                            color: Colors.grey,
                                            size: 50,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(displayedVideos[index].caption)),
                                  DataCell(Text(_getUploaderName(displayedVideos[index].uid))),
                                  DataCell(
                                    Center(
                                      child: PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'view_video') {
                                            Get.to(() => VideoPlayerScreen(
                                                  videoUrl: displayedVideos[index].videoUrl,
                                                  userId: displayedVideos[index].uid,
                                                  videoId: displayedVideos[index].id,
                                                ));
                                          } else if (value == 'delete_video') {
                                            _confirmDelete(context, displayedVideos[index].id);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'view_video',
                                            child: Text('Regarder la vidéo'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete_video',
                                            child: Text('Supprimer la vidéo'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                            dataRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                            dividerThickness: 1,
                            dataRowHeight: 56,
                            headingRowHeight: 56,
                          ),
                          const SizedBox(height: 16),
                          // Pagination stylisée
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Page ${currentPage + 1} sur $totalPages',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: currentPage > 0
                                        ? () {
                                            setState(() {
                                              currentPage--;
                                            });
                                          }
                                        : null,
                                    icon: const Icon(Icons.arrow_back),
                                    label: const Text("Précédent"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700],
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: currentPage < totalPages - 1
                                        ? () {
                                            setState(() {
                                              currentPage++;
                                            });
                                          }
                                        : null,
                                    icon: const Icon(Icons.arrow_forward),
                                    label: const Text("Suivant"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700],
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _getUploaderName(String uid) {
    final uploader = userController.userList.firstWhere(
      (user) => user.uid == uid,
      orElse: () => AppUser(
        nom: 'Inconnu',
        uid: uid,
        email: '',
        role: '',
        photoProfil: '',
        estActif: true,
        followers: 0,
        followings: 0,
        dateInscription: DateTime.now(),
        dernierLogin: DateTime.now(),
        estBloque: false,
      ),
    );
    return uploader.nom;
  }

  void _confirmDelete(BuildContext context, String videoId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Êtes-vous sûr de vouloir supprimer cette vidéo ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Ferme le dialogue avant la suppression
                await videoController.deleteVideo(videoId);
                Get.snackbar(
                  'Succès',
                  'Vidéo supprimée avec succès.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
                setState(() {});
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }
}
