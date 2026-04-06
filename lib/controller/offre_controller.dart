import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/admin_action_response.dart';
import '../models/offre.dart';
import '../services/admin_content_service.dart';

class OffreController extends GetxController {
  OffreController({
    FirebaseFirestore? firestore,
    AdminContentService? adminContentService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _adminContentService = adminContentService ?? AdminContentService();

  final FirebaseFirestore _firestore;
  final AdminContentService _adminContentService;

  static const List<String> moderationStatuses = <String>[
    'brouillon',
    'ouverte',
    'fermee',
    'archivee',
  ];

  final RxList<Offre> offres = <Offre>[].obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _offresSubscription;

  @override
  void onInit() {
    super.onInit();
    _listenOffres();
  }

  @override
  void onClose() {
    _offresSubscription?.cancel();
    super.onClose();
  }

  void _listenOffres() {
    isLoading.value = true;
    _offresSubscription?.cancel();

    _offresSubscription = _firestore.collection('offres').snapshots().listen(
      (snapshot) {
        final parsed = <Offre>[];

        for (final doc in snapshot.docs) {
          try {
            parsed.add(Offre.fromDoc(doc));
          } catch (error) {
            debugPrint('Offre ignoree (parsing): ${doc.id} -> $error');
          }
        }

        parsed.sort((a, b) => b.dateDebut.compareTo(a.dateDebut));
        offres.assignAll(parsed);
        lastError.value = '';
        isLoading.value = false;
      },
      onError: (Object error) {
        debugPrint('Flux Firestore offres indisponible: $error');
        offres.clear();
        lastError.value = 'offres_stream_failed';
        isLoading.value = false;
      },
    );
  }

  Future<void> getAllOffres() async {
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
        message: 'Statut offre invalide.',
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
