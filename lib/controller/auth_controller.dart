import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
import '../models/admin_access_result.dart';
import 'user_controller.dart';

class AuthController extends GetxController {
  AuthController({
    FirebaseAuth? firebaseAuth,
    UserController? userController,
  })  : _firebaseAuth = AppEnvironmentConfig.visualQaMode
            ? null
            : firebaseAuth ?? FirebaseAuth.instance,
        _userController = userController ?? Get.find<UserController>();

  final FirebaseAuth? _firebaseAuth;
  final UserController _userController;
  final Rx<User?> _firebaseUser = Rx<User?>(null);

  User? get firebaseUser => _firebaseUser.value;
  bool get hasAuthenticatedUser => firebaseUser != null;

  @override
  void onReady() {
    super.onReady();
    if (_firebaseAuth == null) {
      return;
    }

    _firebaseUser.bindStream(_firebaseAuth.authStateChanges());
    ever<User?>(_firebaseUser, _handleAuthStateChanged);
    _handleAuthStateChanged(_firebaseAuth.currentUser);
  }

  void _handleAuthStateChanged(User? firebaseUser) {
    if (firebaseUser == null) {
      _userController.clearSessionState();
      return;
    }

    _userController.refreshAdminClaims(firebaseUser: firebaseUser);
  }

  Future<AdminAccessResult> validateCurrentSession({
    User? firebaseUser,
    bool forceRefresh = false,
    bool signOutOnFailure = false,
  }) async {
    if (_firebaseAuth == null) {
      return const AdminAccessResult.authorized(grantedClaims: ['admin']);
    }

    final user = firebaseUser ?? _firebaseAuth.currentUser;
    final result = await _userController.evaluateAdminAccess(
      firebaseUser: user,
      forceRefresh: forceRefresh,
    );

    if (!result.isAuthorized && signOutOnFailure && user != null) {
      await signOut();
    }

    return result;
  }

  Future<AdminAccessResult> loginAdmin({
    required String email,
    required String password,
  }) async {
    if (_firebaseAuth == null) {
      return const AdminAccessResult.denied(
        'Connexion indisponible pendant la QA visuelle locale.',
      );
    }

    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return validateCurrentSession(
      firebaseUser: userCredential.user,
      forceRefresh: true,
      signOutOnFailure: true,
    );
  }

  Future<void> signOut() async {
    await _firebaseAuth?.signOut();
    _userController.clearSessionState();
  }
}
