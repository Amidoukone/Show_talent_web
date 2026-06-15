import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
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
    if (AppEnvironmentConfig.visualQaMode) {
      _seedVisualQaState();
      return;
    }

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
          _handleAuthStateChanged,
        );
    _handleAuthStateChanged(FirebaseAuth.instance.currentUser);
  }

  void fetchUsers() {
    if (AppEnvironmentConfig.visualQaMode) {
      _seedVisualQaState();
      return;
    }

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
    if (AppEnvironmentConfig.visualQaMode) {
      _grantedAdminClaims.assignAll(const ['admin']);
      return const ['admin'];
    }

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
    if (AppEnvironmentConfig.visualQaMode) {
      _seedVisualQaState();
      return const AdminAccessResult.authorized(grantedClaims: ['admin']);
    }

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

  void _seedVisualQaState() {
    final now = DateTime(2026, 6, 14, 12);
    final admin = AppUser(
      uid: 'qa-admin',
      nom: 'Admin Adfoot',
      email: 'admin@adfoot.local',
      role: 'admin',
      photoProfil: '',
      estActif: true,
      emailVerified: true,
      followers: 0,
      followings: 0,
      dateInscription: now.subtract(const Duration(days: 90)),
      dernierLogin: now,
    );

    _user.value = admin;
    _grantedAdminClaims.assignAll(const ['admin']);
    _userList.assignAll([
      admin,
      AppUser(
        uid: 'qa-club',
        nom: 'Académie Abidjan Nord',
        email: 'club@adfoot.local',
        role: 'club',
        photoProfil: '',
        estActif: true,
        emailVerified: true,
        createdByAdmin: true,
        followers: 38,
        followings: 12,
        dateInscription: now.subtract(const Duration(days: 32)),
        dernierLogin: now.subtract(const Duration(hours: 6)),
        phone: '+225 07 00 00 00 01',
        country: "Côte d'Ivoire",
        city: 'Abidjan',
        nomClub: 'Académie Abidjan Nord',
        ligue: 'Formation',
        profileVerified: true,
        profileVerificationStatus: 'verified',
        profileVerifiedAt: now.subtract(const Duration(days: 12)),
        profileVerifiedBy: 'qa-admin',
      ),
      AppUser(
        uid: 'qa-recruiter',
        nom: 'Kone Recrutement Sportif',
        email: 'recruteur@adfoot.local',
        role: 'recruteur',
        photoProfil: '',
        estActif: true,
        emailVerified: true,
        createdByAdmin: true,
        followers: 18,
        followings: 42,
        dateInscription: now.subtract(const Duration(days: 21)),
        dernierLogin: now.subtract(const Duration(days: 1)),
        phone: '+225 07 00 00 00 02',
        country: "Côte d'Ivoire",
        city: 'Bouaké',
        entreprise: 'KRS Talent',
        nombreDeRecrutements: 4,
        profileVerificationStatus: 'pending',
      ),
      AppUser(
        uid: 'qa-agent',
        nom: 'Awa Traoré',
        email: 'agent@adfoot.local',
        role: 'agent',
        photoProfil: '',
        estActif: true,
        emailVerified: true,
        createdByAdmin: true,
        followers: 24,
        followings: 30,
        dateInscription: now.subtract(const Duration(days: 14)),
        dernierLogin: now.subtract(const Duration(hours: 12)),
        phone: '+225 07 00 00 00 03',
        country: "Côte d'Ivoire",
        city: 'Yamoussoukro',
        entreprise: 'TA Sports',
      ),
      AppUser(
        uid: 'qa-player',
        nom: 'Mamadou Diabaté',
        email: 'joueur@adfoot.local',
        role: 'joueur',
        photoProfil: '',
        estActif: true,
        emailVerified: true,
        createdByAdmin: true,
        followers: 126,
        followings: 17,
        dateInscription: now.subtract(const Duration(days: 10)),
        dernierLogin: now.subtract(const Duration(hours: 3)),
        phone: '+225 07 00 00 00 04',
        country: "Côte d'Ivoire",
        city: 'San-Pédro',
        position: 'Milieu',
        clubActuel: 'ST Academy',
        nombreDeMatchs: 18,
        buts: 6,
        assistances: 9,
        profileVerified: true,
        profileVerificationStatus: 'verified',
      ),
      AppUser(
        uid: 'qa-suspended',
        nom: 'Compte à contrôler',
        email: 'suspendu@adfoot.local',
        role: 'club',
        photoProfil: '',
        estActif: true,
        authDisabled: true,
        emailVerified: true,
        createdByAdmin: true,
        followers: 3,
        followings: 1,
        dateInscription: now.subtract(const Duration(days: 8)),
        dernierLogin: now.subtract(const Duration(days: 2)),
        authDisabledReason: 'Revue administrative',
      ),
    ]);
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _usersSubscription?.cancel();
    super.onClose();
  }
}
