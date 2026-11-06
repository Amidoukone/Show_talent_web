import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
import '../models/admin_action_response.dart';
import '../models/offre.dart';
import '../services/admin_content_service.dart';

class OffreController extends GetxController {
  OffreController({
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

  static const List<String> moderationStatuses = <String>[
    'brouillon',
    'ouverte',
    'fermee',
    'archivee',
  ];

  // Plafond + "charger plus" plutôt qu'une collection entière en mémoire :
  // voir le même mécanisme sur event/video/contact_intake controllers.
  //
  // Tri par dateCreation (champ de création, distinct de dateDebut qui est
  // la date métier du poste proposé) plutôt que par documentId. Vérifié,
  // pas supposé : le mobile pose ce champ sans condition au seul point de
  // création d'une offre (offer_repository.dart:182-184) et l'utilise déjà
  // lui-même comme tri de référence (offer_repository.dart:446). Un ancien
  // document pourrait en théorie en être dépourvu (champ ajouté le
  // 2025-03-18, commit a484641), mais la purge totale des offres du
  // 2026-09-28 (docs/checklists/test-data-reset-and-migration-2026-09-28.md,
  // côté mobile) a effacé tout document antérieur à cet ajout : aucune
  // offre actuellement en base n'en est dépourvue. Un orderBy(documentId)
  // excluait au contraire silencieusement les offres les plus RÉCENTES dès
  // que la collection dépassait la fenêtre chargée (un ID auto-généré n'a
  // aucune corrélation avec la date de création) — l'inverse de
  // l'intention.
  static const int _initialLoadLimit = 500;
  static const int _loadMoreIncrement = 500;

  // La première page reste un flux temps réel (un changement sur une offre
  // déjà chargée s'y reflète tout seul). "Charger plus" ajoute des pages
  // par curseur (startAfterDocument) plutôt qu'en relisant tout depuis le
  // début avec une limite grandissante : l'ancien schéma facturait
  // 500+1000+1500 lectures pour afficher 1500 offres au lieu de
  // 500+500+500. Ces pages supplémentaires ne sont PAS temps réel — un
  // changement sur une offre qui s'y trouve n'apparaît qu'au prochain
  // rechargement complet (retry/reconnexion), pas tout seul.
  List<Offre> _firstPage = <Offre>[];
  List<Offre> _extraPages = <Offre>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _isLoadingMore = false;

  final RxList<Offre> offres = <Offre>[].obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;
  final RxBool hasMore = false.obs;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _offresSubscription;

  /// Fusionne la page temps réel et les pages par curseur, en dédoublonnant
  /// par id (la page temps réel l'emporte en cas de conflit, étant la plus
  /// fraîche) : un document ne doit jamais apparaître deux fois si son
  /// curseur de frontière a bougé entre deux "charger plus".
  void _recomputeOffres() {
    final byId = <String, Offre>{};
    for (final offre in _extraPages) {
      byId[offre.id] = offre;
    }
    for (final offre in _firstPage) {
      byId[offre.id] = offre;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    offres.assignAll(merged);
  }

  @override
  void onInit() {
    super.onInit();
    if (_visualQaMode) {
      offres.clear();
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
    _offresSubscription?.cancel();
    super.onClose();
  }

  void _listenOffres() {
    if (FirebaseAuth.instance.currentUser == null) {
      offres.clear();
      lastError.value = '';
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    _offresSubscription?.cancel();
    _extraPages = <Offre>[];
    _lastDocument = null;

    _offresSubscription = _firestore!
        .collection('offres')
        .orderBy('dateCreation', descending: true)
        .limit(_initialLoadLimit)
        .snapshots()
        .listen(
          (snapshot) {
            final parsed = <Offre>[];

            for (final doc in snapshot.docs) {
              try {
                parsed.add(Offre.fromDoc(doc));
              } catch (error) {
                debugPrint('Offre ignorée (parsing) : ${doc.id} -> $error');
              }
            }

            _firstPage = parsed;
            if (snapshot.docs.isNotEmpty) {
              _lastDocument = snapshot.docs.last;
            }
            _recomputeOffres();
            hasMore.value = snapshot.docs.length >= _initialLoadLimit;
            lastError.value = '';
            isLoading.value = false;
          },
          onError: (Object error) {
            debugPrint('Flux Firestore offres indisponible : $error');
            offres.clear();
            lastError.value =
                'Impossible de charger les offres. Vérifiez votre connexion puis réessayez.';
            isLoading.value = false;
          },
        );
  }

  /// Ajoute un lot de [_loadMoreIncrement] offres après le dernier document
  /// déjà chargé, par curseur plutôt qu'en relisant tout depuis le début.
  Future<void> loadMoreOffres() async {
    if (!hasMore.value || _isLoadingMore) return;
    final cursor = _lastDocument;
    if (cursor == null) return;

    _isLoadingMore = true;
    try {
      final snapshot = await _firestore!
          .collection('offres')
          .orderBy('dateCreation', descending: true)
          .startAfterDocument(cursor)
          .limit(_loadMoreIncrement)
          .get();

      final parsed = <Offre>[];
      for (final doc in snapshot.docs) {
        try {
          parsed.add(Offre.fromDoc(doc));
        } catch (error) {
          debugPrint('Offre ignorée (parsing) : ${doc.id} -> $error');
        }
      }

      _extraPages = <Offre>[..._extraPages, ...parsed];
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      hasMore.value = snapshot.docs.length >= _loadMoreIncrement;
      _recomputeOffres();
    } catch (error) {
      debugPrint('Chargement supplémentaire des offres impossible : $error');
      lastError.value =
          'Impossible de charger plus d’offres. Vérifiez votre connexion puis réessayez.';
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    if (user == null) {
      await _stopOffresStream(clearData: true);
      return;
    }

    _listenOffres();
  }

  Future<void> _stopOffresStream({bool clearData = false}) async {
    await _offresSubscription?.cancel();
    _offresSubscription = null;

    if (clearData) {
      offres.clear();
      lastError.value = '';
      isLoading.value = false;
      hasMore.value = false;
      _firstPage = <Offre>[];
      _extraPages = <Offre>[];
      _lastDocument = null;
    }
  }

  Future<void> getAllOffres() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await _stopOffresStream(clearData: true);
      return;
    }

    _listenOffres();
  }

  Future<AdminActionResponse> setOfferStatus({
    required String offerId,
    required String status,
  }) async {
    final normalized = Offre.normalizeStatus(status);
    if (!moderationStatuses.contains(normalized)) {
      return AdminActionResponse.failure(
        code: 'invalid_status',
        message: "Statut d’offre invalide.",
      );
    }

    final response = await _adminContentService.setOfferStatus(
      offerId: offerId,
      status: normalized,
    );

    if (response.success) {
      final index = offres.indexWhere((offre) => offre.id == offerId);
      if (index != -1) {
        offres[index].statut = normalized;
        offres.refresh();
      }
    }

    return response;
  }

  Future<AdminActionResponse> deleteOffer(String offerId) async {
    final response = await _adminContentService.deleteOffer(offerId: offerId);
    if (response.success) {
      offres.removeWhere((offre) => offre.id == offerId);
    }
    return response;
  }

  Future<AdminActionResponse> supprimerOffre(String id) => deleteOffer(id);
}
