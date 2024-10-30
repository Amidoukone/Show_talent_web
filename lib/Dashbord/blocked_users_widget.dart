import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/user_controller.dart';

class BlockedUsersWidget extends StatefulWidget {
  const BlockedUsersWidget({super.key});

  @override
  _BlockedUsersWidgetState createState() => _BlockedUsersWidgetState();
}

class _BlockedUsersWidgetState extends State<BlockedUsersWidget> {
  final UserController userController = Get.find<UserController>();
  int currentPage = 0;
  static const int rowsPerPage = 4;

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  void _fetchBlockedUsers() {
    userController.fetchUsers(); // Assure que la liste est actualisée depuis Firestore
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          width: MediaQuery.of(context).size.width * 0.95,
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  'Utilisateurs Bloqués',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Obx(() {
                final blockedUsers = userController.userList.where((user) => user.estBloque).toList();
                final totalPages = (blockedUsers.length / rowsPerPage).ceil();
                final startIndex = currentPage * rowsPerPage;
                final endIndex = (startIndex + rowsPerPage).clamp(0, blockedUsers.length);
                final displayedUsers = blockedUsers.sublist(startIndex, endIndex);

                return blockedUsers.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun utilisateur bloqué.',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      )
                    : Column(
                        children: [
                          DataTable(
                            columnSpacing: 24.0,
                            horizontalMargin: 12.0,
                            columns: const [
                              DataColumn(
                                label: Expanded(
                                  child: Text(
                                    'Nom',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Expanded(
                                  child: Text(
                                    'Email',
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
                              displayedUsers.length,
                              (index) => DataRow(
                                cells: [
                                  DataCell(Row(
                                    children: [
                                      const Icon(Icons.block, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Text(displayedUsers[index].nom),
                                    ],
                                  )),
                                  DataCell(Text(displayedUsers[index].email)),
                                  DataCell(
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'unblock') {
                                          _unblockUser(displayedUsers[index].uid);
                                        } else if (value == 'delete') {
                                          _confirmDeleteUser(displayedUsers[index].uid);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'unblock',
                                          child: Text('Débloquer'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Supprimer'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                            dataRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                            dividerThickness: 1,
                            dataRowHeight: 56,
                            headingRowHeight: 56,
                          ),
                          const SizedBox(height: 16),
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
                                      backgroundColor: Colors.blueAccent,
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
                                      backgroundColor: Colors.blueAccent,
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

  // Boîte de dialogue de confirmation pour la suppression d'un utilisateur
  Future<void> _confirmDeleteUser(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Êtes-vous sûr de vouloir supprimer cet utilisateur ? Cette action est irréversible.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(false); // Annuler la suppression
              },
            ),
            TextButton(
              child: const Text('Supprimer', style: TextStyle(color: Colors.green)),
              onPressed: () {
                Navigator.of(context).pop(true); // Confirmer la suppression
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _deleteUser(userId); // Appeler la fonction de suppression si confirmé
    }
  }

  void _unblockUser(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'estActif': true,
        'estBloque': false,
      });
      _fetchBlockedUsers(); // Rafraîchit la liste après le déblocage
      Get.snackbar(
        'Succès',
        'Utilisateur débloqué avec succès.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (error) {
      Get.snackbar(
        'Erreur',
        'Impossible de débloquer l\'utilisateur.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _deleteUser(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      _fetchBlockedUsers(); // Rafraîchit la liste après la suppression
      Get.snackbar(
        'Succès',
        'Utilisateur supprimé avec succès.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (error) {
      Get.snackbar(
        'Erreur',
        'Impossible de supprimer l\'utilisateur.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
