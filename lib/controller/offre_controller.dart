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
  })  : _visualQaMode = AppEnvironmentConfig.visualQaMode,
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
  // Tri par documentId (et non une date) car c'est le seul champ garanti
  // présent sur chaque document — trier par une date potentiellement
  // absente exclurait silencieusement les offres qui ne l'ont pas.
  static const int _initialLoadLimit = 500;
  static const int _loadMoreIncrement = 500;
  int _currentLimit = _initialLoadLimit;

  final RxList<Offre> offres = <Offre>[].obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;
  final RxBool hasMore = false.obs;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _offresSubscription;

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

    _offresSubscription = _firestore!
        .collection('offres')
        .orderBy(FieldPath.documentId)
        .limit(_currentLimit)
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

        parsed.sort((a, b) => b.dateDebut.compareTo(a.dateDebut));
        offres.assignAll(parsed);
        hasMore.value = snapshot.docs.length >= _currentLimit;
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

  /// Agrandit la fenêtre chargée de [_loadMoreIncrement] offres et
  /// réabonne le flux — [hasMore] repasse à false tout seul si ce lot
  /// couvrait déjà toute la collection.
  void loadMoreOffres() {
    if (!hasMore.value) return;
    _currentLimit += _loadMoreIncrement;
    _listenOffres();
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
      _currentLimit = _initialLoadLimit;
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
