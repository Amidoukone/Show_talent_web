import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controller/user_controller.dart';

class UserManagementWidget extends StatefulWidget {
  final String selectedRole;
  final bool showBlockedUsers; // Ajout d'un flag pour afficher les utilisateurs bloqués

  const UserManagementWidget({required this.selectedRole, this.showBlockedUsers = false, super.key});

  @override
  _UserManagementWidgetState createState() => _UserManagementWidgetState();
}

class _UserManagementWidgetState extends State<UserManagementWidget> {
  final UserController userController = Get.find<UserController>();
  String searchQuery = '';
  String? selectedRole;
  int currentPage = 0;
  static const int rowsPerPage = 4;

  @override
  void initState() {
    super.initState();
    selectedRole = widget.selectedRole;
    _fetchUsers(); // Charge les utilisateurs au lancement
  }

  // Méthode pour recharger les utilisateurs après modification
  void _fetchUsers() {
    userController.fetchUsers(); // Assume que cette méthode recharge la liste des utilisateurs dans Firestore
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gestion des Utilisateurs',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  DropdownButton<String>(
                    value: selectedRole,
                    items: <String>['Tous', 'joueur', 'club', 'recruteur', 'fan']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedRole = newValue;
                        currentPage = 0;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Rechercher un utilisateur',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                      currentPage = 0;
                    });
                  },
                ),
              ),
              Obx(() {
                final filteredUsers = userController.userList.where((user) {
                  final isBlocked = user.estBloque == true;
                  final matchesRole = selectedRole == 'Tous' || user.role == selectedRole;
                  final matchesSearch = user.nom.toLowerCase().contains(searchQuery.toLowerCase()) ||
                      user.email.toLowerCase().contains(searchQuery.toLowerCase());
                  return matchesRole && matchesSearch && (widget.showBlockedUsers ? isBlocked : !isBlocked);
                }).toList();

                final totalPages = (filteredUsers.length / rowsPerPage).ceil();
                final startIndex = currentPage * rowsPerPage;
                final endIndex = (startIndex + rowsPerPage).clamp(0, filteredUsers.length);
                final displayedUsers = filteredUsers.sublist(startIndex, endIndex);

                return filteredUsers.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun utilisateur trouvé.',
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
                                      const Icon(Icons.person, color: Colors.blueAccent),
                                      const SizedBox(width: 8),
                                      Text(displayedUsers[index].nom),
                                    ],
                                  )),
                                  DataCell(Text(displayedUsers[index].email)),
                                  DataCell(
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'block') {
                                          _blockUser(displayedUsers[index].uid);
                                        } else if (value == 'delete') {
                                          _deleteUser(displayedUsers[index].uid);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'block',
                                          child: Text('Bloquer'),
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
                            headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                            dataRowColor: WidgetStateProperty.all(Colors.grey.shade50),
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

  Future<void> _blockUser(String userId) async {
    final confirmed = await _showConfirmationDialog('Bloquer l\'utilisateur', 'Êtes-vous sûr de vouloir bloquer cet utilisateur ?');
    if (confirmed) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'estActif': false,
          'estBloque': true,
        });
        _fetchUsers();
        Get.snackbar(
          'Succès',
          'Utilisateur bloqué avec succès.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[700],
          colorText: Colors.white,
        );
      } catch (error) {
        Get.snackbar(
          'Erreur',
          'Impossible de bloquer l\'utilisateur.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[700],
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _deleteUser(String userId) async {
    final confirmed = await _showConfirmationDialog('Supprimer l\'utilisateur', 'Êtes-vous sûr de vouloir supprimer cet utilisateur ?');
    if (confirmed) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).delete();
        _fetchUsers();
        Get.snackbar(
          'Succès',
          'Utilisateur supprimé avec succès.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green[700],
          colorText: Colors.white,
        );
      } catch (error) {
        Get.snackbar(
          'Erreur',
          'Impossible de supprimer l\'utilisateur.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[700],
          colorText: Colors.white,
        );
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(color: Colors.black)),
          content: Text(content, style: const TextStyle(color: Colors.black)),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Confirmer', style: TextStyle(color: Colors.green)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;
  }
}
