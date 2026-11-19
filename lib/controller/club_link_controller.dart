import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
import '../models/admin_action_response.dart';
import '../models/player_club_link.dart';
import '../services/admin_content_service.dart';

/// Les rattachements joueur-club encore en cours, et les exceptions qu'ils
/// portent.
///
/// Une contestation gèle l'état public et attend une décision humaine. Sans
/// écran, elle attend indéfiniment et le joueur n'a aucune réponse — même
/// chose pour deux clubs qui déclarent le même joueur, et pour les
/// rattachements à réexaminer après une révocation d'habilitation.
///
/// **Un seul flux pour les trois files.** La collection est interrogée une
/// fois sur `status in (declared, confirmed, contested)` et les trois vues se
/// déduisent de cette liste : la contestation est un état, le réexamen est un
/// champ, et un doublon est une propriété *entre* documents que de toute façon
/// aucune requête Firestore ne sait exprimer. Trois requêtes auraient coûté
/// trois fois les lectures pour relire largement les mêmes documents.
///
/// L'index composite employé — `status` + `updatedAt` — est déjà déclaré dans
/// `firestore.indexes.json` du dépôt mobile : rien à déployer avant ce portail.
class ClubLinkController extends GetxController {
  ClubLinkController({
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

  static const String collectionPath = 'player_club_links';

  // Même plafond + « charger plus » que les autres contrôleurs du portail.
  static const int _initialLoadLimit = 500;
  static const int _loadMoreIncrement = 500;

  /// Voir `OffreController` pour le détail : première page en temps réel, les
  /// suivantes en lots statiques ajoutés par curseur.
  List<PlayerClubLink> _firstPage = <PlayerClubLink>[];
  List<PlayerClubLink> _extraPages = <PlayerClubLink>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _isLoadingMore = false;

  /// Tous les rattachements en cours de la fenêtre chargée.
  final RxList<PlayerClubLink> openLinks = <PlayerClubLink>[].obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;
  final RxBool hasMore = false.obs;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _linksSubscription;

  Query<Map<String, dynamic>> _openLinksQuery() {
    return _firestore!
        .collection(collectionPath)
        .where('status', whereIn: PlayerClubLink.openStatuses)
        .orderBy('updatedAt');
  }

  /// Fusionne les pages et trie par ancienneté de l'exception.
  ///
  /// Ascendant, à l'inverse des listes de contenu : une file d'arbitrage se
  /// traite par le haut, et la contestation qui dort depuis trois semaines
  /// passe avant celle déposée ce matin. Le tri porte sur
  /// [PlayerClubLink.exceptionRaisedAt] et non sur `updatedAt` — ce dernier
  /// bouge à chaque passage de la cascade de révocation, y compris sur des
  /// dossiers que personne n'a touchés, et les ferait remonter comme s'ils
  /// venaient d'arriver.
  void _recomputeLinks() {
    final byId = <String, PlayerClubLink>{};
    for (final link in _extraPages) {
      byId[link.id] = link;
    }
    for (final link in _firstPage) {
      byId[link.id] = link;
    }

    final merged = byId.values.toList()
      ..sort((a, b) {
        final left =
            a.exceptionRaisedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right =
            b.exceptionRaisedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return left.compareTo(right);
      });
    openLinks.assignAll(merged);
  }

  /// Les joueurs portant plus d'un rattachement en cours.
  ///
  /// C'est le litige que l'administration doit trancher : un joueur n'a qu'un
  /// club à la fois. `assertNoOpenLink` le refuse en amont, donc un doublon
  /// vient d'une course entre deux déclarations simultanées, ou d'un état
  /// antérieur à ce contrôle.
  ///
  /// **Détecté sur la fenêtre chargée seulement.** Aucune requête Firestore ne
  /// sait exprimer « deux documents partagent une valeur » : cela se voit en
  /// lisant la collection. Si les rattachements en cours dépassent la fenêtre,
  /// deux liens d'un même joueur peuvent tomber dans deux pages — d'où le
  /// « charger plus » du pied de liste, et l'avertissement que l'écran affiche
  /// tant que [hasMore] est vrai.
  Set<String> get duplicatedPlayerUids {
    final seen = <String>{};
    final duplicated = <String>{};
    for (final link in openLinks) {
      if (link.playerUid.isEmpty) continue;
      if (!seen.add(link.playerUid)) duplicated.add(link.playerUid);
    }
    return duplicated;
  }

  @override
  void onInit() {
    super.onInit();
    if (_visualQaMode) {
      openLinks.clear();
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
    _linksSubscription?.cancel();
    super.onClose();
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    if (user == null) {
      await _stopStream(clearData: true);
      return;
    }

    _listenOpenLinks();
  }

  Future<void> _stopStream({bool clearData = false}) async {
    await _linksSubscription?.cancel();
    _linksSubscription = null;

    if (clearData) {
      openLinks.clear();
      lastError.value = '';
      isLoading.value = false;
      hasMore.value = false;
      _firstPage = <PlayerClubLink>[];
      _extraPages = <PlayerClubLink>[];
      _lastDocument = null;
    }
  }

  void _listenOpenLinks() {
    if (FirebaseAuth.instance.currentUser == null) {
      openLinks.clear();
      lastError.value = '';
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    _linksSubscription?.cancel();
    _extraPages = <PlayerClubLink>[];
    _lastDocument = null;

    _linksSubscription = _openLinksQuery()
        .limit(_initialLoadLimit)
        .snapshots()
        .listen(
          (snapshot) {
            _firstPage = _parse(snapshot.docs);
            if (snapshot.docs.isNotEmpty) {
              _lastDocument = snapshot.docs.last;
            }
            _recomputeLinks();
            hasMore.value = snapshot.docs.length >= _initialLoadLimit;
            lastError.value = '';
            isLoading.value = false;
          },
          onError: (Object error) {
            debugPrint(
              'Flux Firestore des rattachements indisponible : $error',
            );
            openLinks.clear();
            lastError.value =
                'Impossible de charger les rattachements. Vérifiez votre '
                'connexion puis réessayez.';
            isLoading.value = false;
          },
        );
  }

  List<PlayerClubLink> _parse(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final parsed = <PlayerClubLink>[];
    for (final doc in docs) {
      try {
        parsed.add(PlayerClubLink.fromDoc(doc));
      } catch (error) {
        debugPrint('Rattachement ignore (parsing) : ${doc.id} -> $error');
      }
    }
    return parsed;
  }

  /// Ajoute un lot après le dernier document chargé, par curseur.
  Future<void> loadMoreLinks() async {
    if (!hasMore.value || _isLoadingMore) return;
    final cursor = _lastDocument;
    if (cursor == null) return;

    _isLoadingMore = true;
    try {
      final snapshot = await _openLinksQuery()
          .startAfterDocument(cursor)
          .limit(_loadMoreIncrement)
          .get();

      _extraPages = <PlayerClubLink>[..._extraPages, ..._parse(snapshot.docs)];
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      hasMore.value = snapshot.docs.length >= _loadMoreIncrement;
      _recomputeLinks();
    } catch (error) {
      debugPrint(
        'Chargement supplementaire des rattachements impossible : $error',
      );
      lastError.value =
          'Impossible de charger plus de rattachements. Vérifiez votre '
          'connexion puis réessayez.';
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Relance le flux, pour le bouton « Recharger ».
  Future<void> refreshLinks() async {
    if (_visualQaMode) return;
    if (FirebaseAuth.instance.currentUser == null) {
      await _stopStream(clearData: true);
      return;
    }

    _listenOpenLinks();
  }

  /// Clôt un rattachement, et le retire de la fenêtre en cas de succès.
  ///
  /// Le retrait local n'est pas un raccourci d'affichage — le flux temps réel
  /// l'aurait retiré de lui-même, le rattachement quittant les états ouverts.
  /// Il le retire **tout de suite**, pour qu'un opérateur qui arbitre un
  /// doublon ne close pas les deux rattachements pendant l'aller-retour.
  Future<AdminActionResponse> endLink(String linkId) async {
    final response = await _adminContentService.endClubLink(linkId: linkId);

    if (response.success) {
      _firstPage = _firstPage.where((link) => link.id != linkId).toList();
      _extraPages = _extraPages.where((link) => link.id != linkId).toList();
      _recomputeLinks();
    }

    return response;
  }
}
