import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../models/admin_access_result.dart';
import '../models/user.dart';
import '../utils/account_role_policy.dart';

class UserController extends GetxController {
  final Rx<AppUser?> _user = Rx<AppUser?>(null);
  AppUser? get user => _user.value;

  final RxList<AppUser> _userList = <AppUser>[].obs;
  List<AppUser> get userList => _userList;

  final RxList<String> _grantedAdminClaims = <String>[].obs;
  List<String> get grantedAdminClaims => _grantedAdminClaims;
  bool get hasRequiredAdminClaims => _grantedAdminClaims.isNotEmpty;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSubscription;

  @override
  void onInit() {
    super.onInit();
    fetchUsers();
  }

  void fetchUsers() {
    if (_usersSubscription != null) {
      return;
    }

    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      _userList.value = snapshot.docs.map((doc) {
        final data = doc.data();
        return AppUser.fromMap(data);
      }).toList();
    });
  }

  void setUserFromFirestore(Map<String, dynamic> userData) {
    _user.value = AppUser.fromMap(userData);
  }

  void clearSessionState() {
    _user.value = null;
    _grantedAdminClaims.clear();
  }

  Future<List<String>> refreshAdminClaims({
    User? firebaseUser,
    bool forceRefresh = false,
  }) async {
    final user = firebaseUser ?? FirebaseAuth.instance.currentUser;
    if (user == null) {
      _grantedAdminClaims.clear();
      return const [];
    }

    final tokenResult = await user.getIdTokenResult(forceRefresh);
    final claims = Map<String, dynamic>.from(tokenResult.claims ?? const {});
    final grantedClaims = extractGrantedAdminClaims(claims);
    _grantedAdminClaims.assignAll(grantedClaims);
    return grantedClaims;
  }

  Future<AdminAccessResult> evaluateAdminAccess({
    User? firebaseUser,
    bool forceRefresh = false,
  }) async {
    final user = firebaseUser ?? FirebaseAuth.instance.currentUser;
    if (user == null) {
      clearSessionState();
      return const AdminAccessResult.denied('Session expiree.');
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        clearSessionState();
        return const AdminAccessResult.denied(
          'Utilisateur introuvable dans /users.',
        );
      }

      final userData = Map<String, dynamic>.from(
        userDoc.data() as Map<String, dynamic>,
      );
      final appUser = AppUser.fromMap(userData);

      final grantedClaims = await refreshAdminClaims(
        firebaseUser: user,
        forceRefresh: forceRefresh,
      );

      if (grantedClaims.isEmpty) {
        clearSessionState();
        return const AdminAccessResult.denied(
          'Les custom claims admin sont requis pour acceder au dashboard.',
        );
      }

      if (appUser.role != 'admin') {
        clearSessionState();
        return const AdminAccessResult.denied(
          'Votre compte n est pas autorise sur le portail admin.',
        );
      }

      if (appUser.estBloque) {
        clearSessionState();
        return const AdminAccessResult.denied('Votre compte est bloque.');
      }

      if (appUser.authDisabled) {
        clearSessionState();
        return const AdminAccessResult.denied(
          'Firebase Auth est desactive pour ce compte.',
        );
      }

      _user.value = appUser;
      return AdminAccessResult.authorized(grantedClaims: grantedClaims);
    } catch (error) {
      clearSessionState();
      return AdminAccessResult.denied(
        'Impossible de verifier la session admin : $error',
      );
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    clearSessionState();
    Get.offAllNamed('/admin-login');
  }

  @override
  void onClose() {
    _usersSubscription?.cancel();
    super.onClose();
  }
}
