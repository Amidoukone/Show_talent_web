import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../Dashbord/admin_dashboard_screen.dart';
import '../Dashbord/admin_login.dart';
import '../models/user.dart';
import '../utils/admin_access_messages.dart';
import '../utils/account_role_policy.dart';

class AuthController extends GetxController {
  static AuthController instance = Get.find();

  late Rx<User?> _firebaseUser;
  final Rx<AppUser?> _user = Rx<AppUser?>(null);

  AppUser? get user => _user.value;

  @override
  void onReady() {
    super.onReady();
    _firebaseUser = Rx<User?>(FirebaseAuth.instance.currentUser);
    _firebaseUser.bindStream(FirebaseAuth.instance.authStateChanges());
    ever(_firebaseUser, _setInitialScreen);
  }

  Future<void> _setInitialScreen(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user.value = null;
      Get.offAll(() => const AdminLoginScreen());
      return;
    }

    final appUser = await getAppUserFromFirestore(firebaseUser.uid);
    final grantedClaims = await _extractAdminClaims(firebaseUser);

    if (appUser != null &&
        isAdminPortalOnlyRole(appUser.role) &&
        !appUser.hasActiveAppBlock &&
        appUser.authDisabled != true &&
        grantedClaims.isNotEmpty) {
      _user.value = appUser;
      Get.offAll(() => AdminDashboardScreen());
      return;
    }

    Get.snackbar(
      'Accès refusé',
      AdminAccessMessages.deniedForUser(
        appUser,
        hasClaims: grantedClaims.isNotEmpty,
      ),
    );
    await FirebaseAuth.instance.signOut();
    _user.value = null;
    Get.offAll(() => const AdminLoginScreen());
  }

  Future<AppUser?> getAppUserFromFirestore(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (error) {
      Get.snackbar(
        'Erreur',
        'Impossible de récupérer les informations utilisateur : $error',
      );
    }

    return null;
  }

  Future<List<String>> _extractAdminClaims(User firebaseUser) async {
    final tokenResult = await firebaseUser.getIdTokenResult(true);
    final claims = Map<String, dynamic>.from(tokenResult.claims ?? const {});
    return extractGrantedAdminClaims(claims);
  }

  Future<void> loginAdmin(String email, String password) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        Get.snackbar('Erreur', 'Veuillez remplir tous les champs requis.');
        return;
      }

      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final appUser = await getAppUserFromFirestore(userCredential.user!.uid);
      final grantedClaims = await _extractAdminClaims(userCredential.user!);

      if (appUser != null &&
          isAdminPortalOnlyRole(appUser.role) &&
          !appUser.hasActiveAppBlock &&
          appUser.authDisabled != true &&
          grantedClaims.isNotEmpty) {
        _user.value = appUser;
        Get.offAll(() => AdminDashboardScreen());
        return;
      }

      Get.snackbar(
        'Accès refusé',
        AdminAccessMessages.deniedForUser(
          appUser,
          hasClaims: grantedClaims.isNotEmpty,
        ),
      );
      await FirebaseAuth.instance.signOut();
      _user.value = null;
    } catch (error) {
      Get.snackbar('Erreur de connexion', 'Connexion impossible : $error');
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    _user.value = null;
    Get.offAll(() => const AdminLoginScreen());
  }
}
