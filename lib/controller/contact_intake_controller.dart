import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
import '../models/admin_action_response.dart';
import '../models/contact_intake.dart';
import '../services/admin_content_service.dart';

class ContactIntakeController extends GetxController {
  ContactIntakeController({
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

  static const List<String> followUpStatuses = AgencyFollowUpStatus.values;

  // Voir OffreController pour le détail du choix (plafond + "charger plus",
  // tri par createdAt). Vérifié comme pour les offres/événements :
  // createdAt est posé sans condition aux deux seuls points de création
  // d'une prise de contact (chat_repository.dart), collection introduite en
  // un seul commit qui l'a toujours eu — aucune fenêtre historique sans ce
  // champ.
  static const int _initialLoadLimit = 500;
  static const int _loadMoreIncrement = 500;

  // Voir OffreController._recomputeOffres/_firstPage/_extraPages pour le
  // détail : page 1 temps réel, pages suivantes par curseur et statiques.
  List<ContactIntake> _firstPage = <ContactIntake>[];
  List<ContactIntake> _extraPages = <ContactIntake>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _isLoadingMore = false;

  final RxList<ContactIntake> contactIntakes = <ContactIntake>[].obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;
  final RxBool hasMore = false.obs;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _contactIntakesSubscription;

  void _recomputeContactIntakes() {
    final byId = <String, ContactIntake>{};
    for (final intake in _extraPages) {
      byId[intake.id] = intake;
    }
    for (final intake in _firstPage) {
      byId[intake.id] = intake;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    contactIntakes.assignAll(merged);
  }

  @override
  void onInit() {
    super.onInit();
    if (_visualQaMode) {
      contactIntakes.clear();
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
    _contactIntakesSubscription?.cancel();
    super.onClose();
  }

  void _listenContactIntakes() {
    if (FirebaseAuth.instance.currentUser == null) {
      contactIntakes.clear();
      lastError.value = '';
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    _contactIntakesSubscription?.cancel();
    _extraPages = <ContactIntake>[];
    _lastDocument = null;

    _contactIntakesSubscription = _firestore!
        .collection('contact_intakes')
        .orderBy('createdAt', descending: true)
        .limit(_initialLoadLimit)
        .snapshots()
        .listen(
          (snapshot) {
            final parsed = <ContactIntake>[];

            for (final doc in snapshot.docs) {
              try {
                parsed.add(ContactIntake.fromDoc(doc));
              } catch (error) {
                debugPrint(
                  'Prise de contact ignorée (parsing) : ${doc.id} -> $error',
                );
              }
            }

            _firstPage = parsed;
            if (snapshot.docs.isNotEmpty) {
              _lastDocument = snapshot.docs.last;
            }
            _recomputeContactIntakes();
            hasMore.value = snapshot.docs.length >= _initialLoadLimit;
            lastError.value = '';
            isLoading.value = false;
          },
          onError: (Object error) {
            debugPrint('Flux Firestore contact_intakes indisponible : $error');
            contactIntakes.clear();
            lastError.value =
                'Impossible de charger les mises en relation. Vérifiez votre connexion puis réessayez.';
            isLoading.value = false;
          },
        );
  }

  /// Voir OffreController.loadMoreOffres.
  Future<void> loadMoreContactIntakes() async {
    if (!hasMore.value || _isLoadingMore) return;
    final cursor = _lastDocument;
    if (cursor == null) return;

    _isLoadingMore = true;
    try {
      final snapshot = await _firestore!
          .collection('contact_intakes')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(cursor)
          .limit(_loadMoreIncrement)
          .get();

      final parsed = <ContactIntake>[];
      for (final doc in snapshot.docs) {
        try {
          parsed.add(ContactIntake.fromDoc(doc));
        } catch (error) {
          debugPrint(
            'Prise de contact ignorée (parsing) : ${doc.id} -> $error',
          );
        }
      }

      _extraPages = <ContactIntake>[..._extraPages, ...parsed];
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      hasMore.value = snapshot.docs.length >= _loadMoreIncrement;
      _recomputeContactIntakes();
    } catch (error) {
      debugPrint(
        'Chargement supplémentaire des mises en relation impossible : $error',
      );
      lastError.value =
          'Impossible de charger plus de mises en relation. Vérifiez votre connexion puis réessayez.';
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    if (user == null) {
      await _stopContactIntakesStream(clearData: true);
      return;
    }

    _listenContactIntakes();
  }

  Future<void> _stopContactIntakesStream({bool clearData = false}) async {
    await _contactIntakesSubscription?.cancel();
    _contactIntakesSubscription = null;

    if (clearData) {
      contactIntakes.clear();
      lastError.value = '';
      isLoading.value = false;
      hasMore.value = false;
      _firstPage = <ContactIntake>[];
      _extraPages = <ContactIntake>[];
      _lastDocument = null;
    }
  }

  Future<void> refreshContactIntakes() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await _stopContactIntakesStream(clearData: true);
      return;
    }

    _listenContactIntakes();
  }

  Future<AdminActionResponse> setAgencyFollowUpStatus({
    required String contactIntakeId,
    required String status,
    String note = '',
  }) async {
    final normalized = AgencyFollowUpStatus.normalize(status);
    if (!followUpStatuses.contains(normalized)) {
      return AdminActionResponse.failure(
        code: 'invalid_status',
        message: 'Statut de suivi agence invalide.',
      );
    }

    final response = await _adminContentService.setContactIntakeFollowUp(
      contactIntakeId: contactIntakeId,
      status: normalized,
      note: note,
    );

    if (response.success) {
      final index = contactIntakes.indexWhere(
        (intake) => intake.id == contactIntakeId,
      );
      if (index != -1) {
        final current = contactIntakes[index];
        final data = response.data ?? const <String, dynamic>{};
        final nextNote = data.containsKey('note')
            ? data['note']
            : current.agencyFollowUpNote;
        final updated = ContactIntake.fromMap(<String, dynamic>{
          'id': current.id,
          'requesterUid': current.requesterUid,
          'targetUid': current.targetUid,
          'requesterRole': current.requesterRole,
          'targetRole': current.targetRole,
          'contextType': current.contextType,
          'contactReason': current.contactReason,
          'introMessage': current.introMessage,
          'status': current.status,
          'agencyFollowUpStatus': data['status']?.toString() ?? normalized,
          'agencyFollowUpNote': nextNote,
          'agencyLastUpdatedByUid':
              data['updatedBy']?.toString() ?? current.agencyLastUpdatedByUid,
          'agencyLastUpdatedAt': DateTime.now(),
          'conversationId': current.conversationId,
          'contextId': current.contextId,
          'contextTitle': current.contextTitle,
          'requesterSnapshot': current.requesterSnapshot,
          'targetSnapshot': current.targetSnapshot,
          'latestParticipantFeedbackStatus':
              current.latestParticipantFeedbackStatus,
          'latestParticipantFeedbackNote':
              current.latestParticipantFeedbackNote,
          'latestParticipantFeedbackByUid':
              current.latestParticipantFeedbackByUid,
          'latestParticipantFeedbackByRole':
              current.latestParticipantFeedbackByRole,
          'latestParticipantFeedbackAt': current.latestParticipantFeedbackAt,
          'suggestedAgencyFollowUpStatus':
              current.suggestedAgencyFollowUpStatus,
          'createdAt': current.createdAt,
          'updatedAt': DateTime.now(),
        }, fallbackId: current.id);
        contactIntakes[index] = updated;
        contactIntakes.refresh();
      }
    }

    return response;
  }

  Future<AdminActionResponse> deleteContactIntake({
    required ContactIntake intake,
  }) async {
    final response = await _adminContentService.deleteContactIntake(
      contactIntakeId: intake.id,
      conversationId: intake.conversationId,
    );

    if (response.success) {
      contactIntakes.removeWhere((current) => current.id == intake.id);
      contactIntakes.refresh();
    }

    return response;
  }

  Future<AdminActionResponse> deleteContactIntakeConversation({
    required ContactIntake intake,
  }) async {
    final response = await _adminContentService.deleteContactIntakeConversation(
      contactIntakeId: intake.id,
      conversationId: intake.conversationId,
    );

    if (response.success) {
      final index = contactIntakes.indexWhere(
        (current) => current.id == intake.id,
      );
      if (index != -1) {
        final current = contactIntakes[index];
        final updated = ContactIntake.fromMap(<String, dynamic>{
          'id': current.id,
          'requesterUid': current.requesterUid,
          'targetUid': current.targetUid,
          'requesterRole': current.requesterRole,
          'targetRole': current.targetRole,
          'contextType': current.contextType,
          'contactReason': current.contactReason,
          'introMessage': current.introMessage,
          'status': current.status,
          'agencyFollowUpStatus': current.agencyFollowUpStatus,
          'agencyFollowUpNote': current.agencyFollowUpNote,
          'agencyLastUpdatedByUid': current.agencyLastUpdatedByUid,
          'agencyLastUpdatedAt': current.agencyLastUpdatedAt,
          'conversationId': null,
          'contextId': current.contextId,
          'contextTitle': current.contextTitle,
          'requesterSnapshot': current.requesterSnapshot,
          'targetSnapshot': current.targetSnapshot,
          'latestParticipantFeedbackStatus':
              current.latestParticipantFeedbackStatus,
          'latestParticipantFeedbackNote':
              current.latestParticipantFeedbackNote,
          'latestParticipantFeedbackByUid':
              current.latestParticipantFeedbackByUid,
          'latestParticipantFeedbackByRole':
              current.latestParticipantFeedbackByRole,
          'latestParticipantFeedbackAt': current.latestParticipantFeedbackAt,
          'suggestedAgencyFollowUpStatus':
              current.suggestedAgencyFollowUpStatus,
          'createdAt': current.createdAt,
          'updatedAt': DateTime.now(),
        }, fallbackId: current.id);
        contactIntakes[index] = updated;
        contactIntakes.refresh();
      }
    }

    return response;
  }
}
