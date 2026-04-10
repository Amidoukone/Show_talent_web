import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/admin_access_result.dart';
import '../models/user.dart';
import '../utils/admin_access_messages.dart';
import '../utils/account_role_policy.dart';

class UserController extends GetxController {
  final Rx<AppUser?> _user = Rx<AppUser?>(null);
  AppUser? get user => _user.value;

  final RxList<AppUser> _userList = <AppUser>[].obs;
  List<AppUser> get userList => _userList;

  final RxList<String> _grantedAdminClaims = <String>[].obs;
  List<String> get grantedAdminClaims => _grantedAdminClaims;
  bool get hasRequiredAdminClaims => _grantedAdminClaims.isNotEmpty;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSubscription;

  @override
  void onInit() {
    super.onInit();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
          _handleAuthStateChanged,
        );
    _handleAuthStateChanged(FirebaseAuth.instance.currentUser);
  }

  void fetchUsers() {
    if (FirebaseAuth.instance.currentUser == null) {
      return;
    }

    if (_usersSubscription != null) {
      return;
    }

    _usersSubscription =
        FirebaseFirestore.instance.collection('users').snapshots().listen(
      (snapshot) {
        final parsedUsers = <AppUser>[];

        for (final doc in snapshot.docs) {
          try {
            parsedUsers.add(
              _parseUserData(
                doc.data(),
                fallbackUid: doc.id,
              ),
            );
          } catch (error, stackTrace) {
            debugPrint(
              'Document utilisateur ignoré (${doc.id}) car invalide : $error',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
        }

        _userList.assignAll(parsedUsers);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Flux Firestore users indisponible : $error');
        debugPrintStack(stackTrace: stackTrace);
        _userList.clear();
        _usersSubscription = null;
      },
      onDone: () {
        _usersSubscription = null;
      },
    );
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    if (user == null) {
      await _stopUsersStream(clearUsers: true);
      clearSessionState();
      return;
    }

    fetchUsers();
  }

  Future<void> _stopUsersStream({bool clearUsers = false}) async {
    await _usersSubscription?.cancel();
    _usersSubscription = null;

    if (clearUsers) {
      _userList.clear();
    }
  }

  void setUserFromFirestore(Map<String, dynamic> userData) {
    _user.value = _parseUserData(userData);
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
      return const AdminAccessResult.denied(AdminAccessMessages.sessionExpired);
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        clearSessionState();
        return const AdminAccessResult.denied(
          AdminAccessMessages.userNotFound,
        );
      }

      final appUser = _parseUserData(
        userDoc.data() as Map<String, dynamic>,
        fallbackUid: userDoc.id,
      );

      final grantedClaims = await refreshAdminClaims(
        firebaseUser: user,
        forceRefresh: forceRefresh,
      );

      if (grantedClaims.isEmpty) {
        clearSessionState();
        return const AdminAccessResult.denied(
          AdminAccessMessages.missingClaims,
        );
      }

      if (!isAdminPortalOnlyRole(appUser.role)) {
        clearSessionState();
        return const AdminAccessResult.denied(
          AdminAccessMessages.roleDenied,
        );
      }

      if (appUser.hasActiveAppBlock) {
        clearSessionState();
        return AdminAccessResult.denied(
          appUser.hasTemporaryBlock
              ? AdminAccessMessages.temporaryBlocked
              : AdminAccessMessages.blocked,
        );
      }

      if (appUser.authDisabled) {
        clearSessionState();
        return const AdminAccessResult.denied(
          AdminAccessMessages.authDisabled,
        );
      }

      _user.value = appUser;
      return AdminAccessResult.authorized(grantedClaims: grantedClaims);
    } catch (error) {
      clearSessionState();
      return AdminAccessResult.denied(
        'Impossible de vérifier la session admin : $error',
      );
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    clearSessionState();
    Get.offAllNamed('/admin-login');
  }

  AppUser _parseUserData(
    Map<String, dynamic> userData, {
    String? fallbackUid,
  }) {
    final normalized = Map<String, dynamic>.from(userData);
    final existingUid = normalized['uid']?.toString().trim() ?? '';
    if (existingUid.isEmpty && fallbackUid != null && fallbackUid.isNotEmpty) {
      normalized['uid'] = fallbackUid;
    }

    return AppUser.fromMap(normalized);
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _usersSubscription?.cancel();
    super.onClose();
  }
}
