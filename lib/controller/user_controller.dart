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
import '../utils/user_contact_projection.dart';

class UserController extends GetxController {
  final Rx<AppUser?> _user = Rx<AppUser?>(null);
  AppUser? get user => _user.value;

  final RxList<AppUser> _userList = <AppUser>[].obs;
  List<AppUser> get userList => _userList;

  final RxBool isLoading = true.obs;
  final RxnString usersLoadError = RxnString();
  final RxnString privateContactLoadError = RxnString();
  bool _hasContactSnapshot = false;
  bool _retryingUsers = false;

  // Plafond + "charger plus" sur la collection users elle-même (voir
  // OffreController pour le détail du choix : tri par documentId pour
  // n'exclure aucun document en silence). La lecture collectionGroup
  // private ci-dessous reste volontairement non plafonnée : chaque document
  // y est minuscule (contact uniquement) et lui ajouter un orderBy/limit
  // nécessiterait un index COLLECTION_GROUP côté dépôt mobile qui n'existe
  // pas encore (voir le commentaire sur _privateContactSubscription).
  static const int _initialLoadLimit = 500;
  static const int _loadMoreIncrement = 500;
  int _currentUsersLimit = _initialLoadLimit;
  final RxBool hasMoreUsers = false.obs;

  /// Nombre total de comptes, indépendant de la fenêtre chargée ci-dessus.
  ///
  /// Une agrégation `count()` plutôt que `userList.length` : l'écran
  /// Statistiques affichait silencieusement un total tronqué à
  /// [_initialLoadLimit] dès que la plateforme dépassait 500 comptes. Null
  /// tant que la première lecture n'a pas répondu, ou si elle a échoué —
  /// l'appelant retombe alors sur `userList.length` avec un bandeau
  /// d'avertissement (voir StatisticsOverviewPanel).
  final Rxn<int> totalUsersCount = Rxn<int>();

  Future<void> _refreshTotalUsersCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();
      totalUsersCount.value = snapshot.count;
    } catch (error) {
      debugPrint('Comptage total des utilisateurs indisponible : $error');
    }
  }

  Future<void> retryUsers() async {
    if (_retryingUsers) return;
    _retryingUsers = true;
    isLoading.value = true;
    try {
      await _stopUsersStream();
      usersLoadError.value = null;
      privateContactLoadError.value = null;
      fetchUsers();
    } finally {
      _retryingUsers = false;
    }
  }

  /// Agrandit la fenêtre chargée de [_loadMoreIncrement] utilisateurs.
  /// Contourne volontairement la garde "déjà abonné" de [fetchUsers] en
  /// coupant d'abord le flux existant, comme le fait déjà [retryUsers].
  Future<void> loadMoreUsers() async {
    if (!hasMoreUsers.value) return;
    _currentUsersLimit += _loadMoreIncrement;
    await _stopUsersStream();
    fetchUsers();
  }

  final RxList<String> _grantedAdminClaims = <String>[].obs;
  List<String> get grantedAdminClaims => _grantedAdminClaims;
  bool get hasRequiredAdminClaims => _grantedAdminClaims.isNotEmpty;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _privateContactSubscription;
  final Map<String, Map<String, dynamic>> _privateContactByUid =
      <String, Map<String, dynamic>>{};

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
      isLoading.value = false;
      return;
    }

    if (_usersSubscription != null) {
      return;
    }

    unawaited(_refreshTotalUsersCount());

    isLoading.value = true;
    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .orderBy(FieldPath.documentId)
        .limit(_currentUsersLimit)
        .snapshots()
        .listen(
          (snapshot) {
            final parsedUsers = <AppUser>[];
            var invalidProfiles = 0;

            for (final doc in snapshot.docs) {
              try {
                parsedUsers.add(
                  _parseUserData(doc.data(), fallbackUid: doc.id),
                );
              } catch (error, stackTrace) {
                invalidProfiles++;
                debugPrint(
                  'Document utilisateur ignoré (${doc.id}) car invalide : $error',
                );
                debugPrintStack(stackTrace: stackTrace);
              }
            }

            usersLoadError.value = invalidProfiles == 0
                ? null
                : 'Certains profils sont illisibles. La liste ne peut pas être affichée intégralement.';
            _userList.assignAll(parsedUsers);
            hasMoreUsers.value = snapshot.docs.length >= _currentUsersLimit;
            _applyPrivateContactCache();
            isLoading.value = false;
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Flux Firestore users indisponible : $error');
            debugPrintStack(stackTrace: stackTrace);
            usersLoadError.value =
                'Impossible de charger les utilisateurs. Vérifiez votre connexion puis réessayez.';
            isLoading.value = false;
          },
          onDone: () {
            _usersSubscription = null;
          },
        );

    // email/phone moved out of the main users doc (see AppUser.fromMap
    // comment) — the list view still needs them for the email column and
    // search, so mirror users/{uid}/private/contact via a collectionGroup
    // query. Admin claims grant read access to every doc it returns (see
    // firestore.rules); non-admins can't reach this code path at all.
    //
    // This query has no where()/orderBy() on purpose: firestore.indexes.json
    // (mobile repo) has no COLLECTION_GROUP entry for `private`. Adding a
    // filter or sort here WILL be rejected by Firestore in production until
    // a matching COLLECTION_GROUP index is added there first.
    _privateContactSubscription ??= FirebaseFirestore.instance
        .collectionGroup('private')
        .snapshots()
        .listen(
          (snapshot) {
            _hasContactSnapshot = true;
            privateContactLoadError.value = null;
            for (final change in snapshot.docChanges) {
              if (change.doc.id != 'contact') {
                continue;
              }
              final uid = change.doc.reference.parent.parent?.id;
              if (uid == null) {
                continue;
              }
              if (change.type == DocumentChangeType.removed) {
                _privateContactByUid.remove(uid);
              } else {
                _privateContactByUid[uid] =
                    change.doc.data() ?? <String, dynamic>{};
              }
            }
            _applyPrivateContactCache();
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Flux Firestore private/contact indisponible : $error');
            debugPrintStack(stackTrace: stackTrace);
            privateContactLoadError.value =
                'Impossible de charger les coordonnées des comptes. Réessayez.';
          },
          onDone: () {
            _privateContactSubscription = null;
          },
        );
  }

  void _applyPrivateContactCache() {
    if (!_hasContactSnapshot || _userList.isEmpty) return;
    for (final user in _userList) {
      applyPrivateContact(user, _privateContactByUid[user.uid]);
    }
    _userList.refresh();
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
    await _privateContactSubscription?.cancel();
    _privateContactSubscription = null;
    _privateContactByUid.clear();
    _hasContactSnapshot = false;

    if (clearUsers) {
      usersLoadError.value = null;
      privateContactLoadError.value = null;
      _userList.clear();
      isLoading.value = false;
      hasMoreUsers.value = false;
      _currentUsersLimit = _initialLoadLimit;
      totalUsersCount.value = null;
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
        return const AdminAccessResult.denied(AdminAccessMessages.userNotFound);
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
        return const AdminAccessResult.denied(AdminAccessMessages.roleDenied);
      }

      if (appUser.authDisabled) {
        clearSessionState();
        return const AdminAccessResult.denied(AdminAccessMessages.authDisabled);
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

  AppUser _parseUserData(Map<String, dynamic> userData, {String? fallbackUid}) {
    final normalized = Map<String, dynamic>.from(userData);
    final existingUid = normalized['uid']?.toString().trim() ?? '';
    if (existingUid.isEmpty && fallbackUid != null && fallbackUid.isNotEmpty) {
      normalized['uid'] = fallbackUid;
    }

    return AppUser.fromMap(normalized);
  }

  /// Fetches phone/email/authDisabledReason (users/{uid}/private/contact)
  /// and profileVerificationNote (users/{uid}/private/adminNotes) for a
  /// single user and returns a copy of [baseUser] enriched with them. Only
  /// call this for the profile review dialog — the bulk [userList] from
  /// [fetchUsers] deliberately doesn't include these fields anymore, and an
  /// admin session is required to read either doc (see firestore.rules).
  Future<AppUser> fetchUserWithPrivateFields(AppUser baseUser) async {
    final usersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(baseUser.uid);
    final results = await Future.wait([
      usersRef.collection('private').doc('contact').get(),
      usersRef.collection('private').doc('adminNotes').get(),
    ]);

    return AppUser.fromMap(
      baseUser.toMap(),
      privateContact: results[0].data(),
      adminNotes: results[1].data(),
    );
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
    isLoading.value = false;
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _usersSubscription?.cancel();
    _privateContactSubscription?.cancel();
    super.onClose();
  }
}
