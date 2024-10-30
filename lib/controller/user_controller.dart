import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';

class UserController extends GetxController {
  final Rx<AppUser?> _user = Rx<AppUser?>(null);  
  AppUser? get user => _user.value;

  final RxList<AppUser> _userList = <AppUser>[].obs;
  List<AppUser> get userList => _userList;

  @override
  void onInit() {
    super.onInit();
    fetchUsers();  // Appel de la méthode publique pour récupérer les utilisateurs
  }

  // Méthode publique pour récupérer tous les utilisateurs depuis Firestore
  void fetchUsers() {
    FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
          _userList.value = snapshot.docs.map((doc) {
            final data = doc.data();
            return AppUser.fromMap(data);
          }).toList();
        });
  }

  // Stocker l'utilisateur connecté depuis Firestore
  void setUserFromFirestore(Map<String, dynamic> userData) {
    _user.value = AppUser.fromMap(userData);
  }

  // Déconnexion de l'utilisateur
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    _user.value = null;
    Get.offAllNamed('/admin-login');  
  }
}
