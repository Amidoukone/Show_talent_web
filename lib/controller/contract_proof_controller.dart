import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
import '../models/admin_action_response.dart';
import '../models/contract_status_proof.dart';
import '../models/user.dart';
import '../services/admin_content_service.dart';

/// La file des pièces de statut contractuel à examiner.
///
/// Un lot entier du dépôt mobile dépend de cet écran : le serveur sait
/// recevoir une pièce, l'examiner et republier un statut, mais sans interface
/// d'examen aucune pièce n'est jamais examinée, donc aucun statut contractuel
/// n'est jamais publié. La capacité existait et n'atteignait personne.
class ContractProofController extends GetxController {
  ContractProofController({
    FirebaseFirestore? firestore,
    AdminContentService? adminContentService,
  }) : _visualQaMode = AppEnvironmentConfig.visualQaMode,
       _firestore = AppEnvironmentConfig.visualQaMode
           ? null
           : firestore ?? FirebaseFirestore.instance,
       _adminContentService = AppEnvironmentConfig.visualQaMode
           ? AdminContentService.visualQa()
           : adminContentService ?? AdminContentService();

  final FirebaseFirestore? _firestore;
  final AdminContentService _adminContentService;
  final bool _visualQaMode;

  /// Champ interrogé, en notation pointée : `contractStatusProof.status`.
  static const String _statusFieldPath = 'contractStatusProof.status';

  // Même plafond + « charger plus » que les autres contrôleurs du portail.
  static const int _initialLoadLimit = 500;
  static const int _loadMoreIncrement = 500;

  int _loadLimit = _initialLoadLimit;

  /// Les joueurs dont une pièce attend un examen, la plus ancienne d'abord.
  final RxList<AppUser> pendingProofs = <AppUser>[].obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;
  final RxBool hasMore = false.obs;
  final unreadableProfiles = 0.obs;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _proofsSubscription;

  /// La requête de la file, et la raison de sa forme.
  ///
  /// **Égalité seule, sans `orderBy` métier.** Trier côté serveur par
  /// `contractStatusProof.submittedAt` demanderait un index composite
  /// (`contractStatusProof.status` + `contractStatusProof.submittedAt`) qui
  /// n'est pas déclaré dans `firestore.indexes.json` du dépôt mobile. Le
  /// déclarer ferait dépendre la mise en production de ce portail d'un
  /// déploiement d'index côté mobile, pour un gain nul : une file d'examen
  /// est bornée par le débit humain qui la traite, pas par la taille de la
  /// collection, et les quelques dizaines de documents qu'elle contient se
  /// trient en mémoire sans que personne ne le remarque.
  ///
  /// L'ordre par identifiant de document n'est donc **pas** l'ordre affiché :
  /// il ne sert qu'à paginer de façon stable. Le tri par date de dépôt est
  /// fait dans [_setPendingProofs], sur l'ensemble des pièces chargées —
  /// c'est ce qui évite le défaut que `OffreController` documente, où un tri
  /// par identifiant écartait silencieusement les documents les plus récents.
  Query<Map<String, dynamic>> _pendingQuery() {
    return _firestore!
        .collection('users')
        .where(_statusFieldPath, isEqualTo: ContractStatusProof.statusPending)
        .orderBy(FieldPath.documentId);
  }

  /// Trie les pièces par date de dépôt, la plus ancienne d'abord.
  ///
  /// Ascendant volontairement, à l'inverse des autres écrans : une file
  /// d'attente se traite par le haut, et la pièce qui attend depuis trois
  /// semaines passe avant celle déposée ce matin. Une pièce sans date de dépôt
  /// lisible est poussée en tête plutôt qu'en queue — un document à moitié
  /// écrit est précisément ce qu'un opérateur doit voir.
  void _setPendingProofs(List<AppUser> users) {
    users.sort((a, b) {
      final left =
          a.contractStatusProof.submittedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final right =
          b.contractStatusProof.submittedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final order = left.compareTo(right);
      return order == 0 ? a.uid.compareTo(b.uid) : order;
    });
    pendingProofs.assignAll(users);
  }

  @override
  void onInit() {
    super.onInit();
    if (_visualQaMode) {
      pendingProofs.clear();
      lastError.value = '';
      isLoading.value = false;
      return;
    }

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthStateChanged,
    );
    _handleAuthStateChanged(FirebaseAuth.instance.currentUser);
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _proofsSubscription?.cancel();
    super.onClose();
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    if (user == null) {
      await _stopStream(clearData: true);
      return;
    }

    _listenPendingProofs();
  }

  Future<void> _stopStream({bool clearData = false}) async {
    final subscription = _proofsSubscription;
    _proofsSubscription = null;

    if (clearData) {
      pendingProofs.clear();
      lastError.value = '';
      isLoading.value = false;
      hasMore.value = false;
      unreadableProfiles.value = 0;
      _loadLimit = _initialLoadLimit;
    }
    await subscription?.cancel();
  }

  void _listenPendingProofs({int limit = _initialLoadLimit}) {
    if (FirebaseAuth.instance.currentUser == null) {
      pendingProofs.clear();
      lastError.value = '';
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    _proofsSubscription?.cancel();
    _loadLimit = limit;
    hasMore.value = false;

    _proofsSubscription = _pendingQuery()
        .limit(limit + 1)
        .snapshots()
        .listen(
          (snapshot) {
            final docs = snapshot.docs.take(limit).toList();
            final users = _parse(docs);
            unreadableProfiles.value = docs.length - users.length;
            _setPendingProofs(users);
            hasMore.value = snapshot.docs.length > limit;
            lastError.value = '';
            isLoading.value = false;
          },
          onError: (Object error) {
            debugPrint('Flux Firestore des pieces indisponible : $error');
            pendingProofs.clear();
            lastError.value =
                'Impossible de charger les pièces à examiner. Vérifiez votre '
                'connexion puis réessayez.';
            isLoading.value = false;
          },
        );
  }

  List<AppUser> _parse(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final parsed = <AppUser>[];
    for (final doc in docs) {
      try {
        final data = {...doc.data(), 'uid': doc.id};
        parsed.add(AppUser.fromMap(data));
      } catch (error) {
        debugPrint('Piece ignoree (parsing) : ${doc.id} -> $error');
      }
    }
    return parsed;
  }

  /// Étend la fenêtre suivie pour que les verdicts des autres opérateurs
  /// et les dépôts de remplacement soient visibles sur toutes ses pages.
  Future<void> loadMoreProofs() async {
    if (hasMore.value) {
      _listenPendingProofs(limit: _loadLimit + _loadMoreIncrement);
    }
  }

  /// Relance la file, pour le bouton « Recharger ».
  Future<void> refreshProofs() async {
    if (_visualQaMode) return;
    if (FirebaseAuth.instance.currentUser == null) {
      await _stopStream(clearData: true);
      return;
    }

    _listenPendingProofs();
  }

  /// Rend un verdict, et retire la pièce de la file en cas de succès.
  ///
  /// Le retrait local n'est pas un raccourci d'affichage : la file est un flux
  /// temps réel, donc le serveur l'aurait retirée de lui-même. Il la retire
  /// **tout de suite**, pour que l'opérateur qui enchaîne vingt examens ne
  /// rende pas deux fois le verdict sur la même pièce pendant l'aller-retour.
  Future<AdminActionResponse> reviewProof({
    required String uid,
    required String expectedFileUrl,
    required String status,
    String? contractStatus,
    DateTime? contractEndDate,
    String? note,
  }) async {
    final response = await _adminContentService.reviewContractStatusProof(
      uid: uid,
      expectedFileUrl: expectedFileUrl,
      status: status,
      contractStatus: contractStatus,
      contractEndDate: contractEndDate,
      note: note,
    );

    if (response.success) {
      pendingProofs.removeWhere(
        (user) =>
            user.uid == uid &&
            user.contractStatusProof.fileUrl == expectedFileUrl,
      );
    }

    return response;
  }
}
