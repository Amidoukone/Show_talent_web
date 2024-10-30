
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:show_talent/Dashbord/admin_dashboard_screen.dart';
import 'package:show_talent/Dashbord/admin_login.dart';
import '../models/user.dart';

class AuthController extends GetxController {
  static AuthController instance = Get.find();

  late Rx<User?> _firebaseUser;  // Firebase User
  final Rx<AppUser?> _user = Rx<AppUser?>(null);  // Utilisation de Rx<AppUser?> ici pour suivre les changements utilisateur

  AppUser? get user => _user.value;  // Getter sécurisé pour accéder à l'utilisateur

  @override
  void onReady() {
    super.onReady();
    _firebaseUser = Rx<User?>(FirebaseAuth.instance.currentUser);
    _firebaseUser.bindStream(FirebaseAuth.instance.authStateChanges());
    ever(_firebaseUser, _setInitialScreen);
  }

  // Définir l'écran initial en fonction de l'état de connexion
  _setInitialScreen(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user.value = null;  // Réinitialiser l'utilisateur local
      Get.offAll(() => const AdminLoginScreen());  // Rediriger vers la page de login admin
    } else {
      AppUser? appUser = await getAppUserFromFirestore(firebaseUser.uid);
      if (appUser != null && appUser.role == 'admin') {  // Vérifier si l'utilisateur est un admin
        _user.value = appUser;  // Stocker l'utilisateur récupéré
        Get.offAll(() =>  AdminDashboardScreen());  // Rediriger vers le dashboard admin
      } else {
        Get.snackbar('Accès refusé', 'Vous n\'êtes pas un administrateur.');
        FirebaseAuth.instance.signOut();  // Déconnexion immédiate si non-admin
        Get.offAll(() => const AdminLoginScreen());  // Retourner au login admin
      }
    }
  }

  // Récupérer les informations de l'utilisateur depuis Firestore
  Future<AppUser?> getAppUserFromFirestore(String uid) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de récupérer les informations utilisateur : $e');
    }
    return null;
  }

  // Connexion des utilisateurs (admins dans ce cas)
  void loginAdmin(String email, String password) async {
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Vérification du rôle après connexion
        AppUser? appUser = await getAppUserFromFirestore(userCredential.user!.uid);
        if (appUser != null && appUser.role == 'admin') {
          _user.value = appUser;
          Get.offAll(() =>  AdminDashboardScreen());  // Rediriger vers le dashboard admin
        } else {
          Get.snackbar('Accès refusé', 'Vous n\'êtes pas un administrateur.');
          FirebaseAuth.instance.signOut();  // Déconnexion immédiate
        }
      } else {
        Get.snackbar('Erreur', 'Veuillez remplir toutes les informations.');
      }
    } catch (e) {
      Get.snackbar('Erreur de connexion', 'Erreur : $e');
    }
  }

  // Déconnexion de l'administrateur
  void signOut() async {
    await FirebaseAuth.instance.signOut();
    _user.value = null;  // Réinitialiser l'utilisateur lors de la déconnexion
    Get.offAll(() => const AdminLoginScreen());  // Rediriger vers la page de login admin
  }
}
