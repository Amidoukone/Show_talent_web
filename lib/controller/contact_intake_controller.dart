import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/admin_action_response.dart';
import '../models/contact_intake.dart';
import '../services/admin_content_service.dart';

class ContactIntakeController extends GetxController {
  ContactIntakeController({
    FirebaseFirestore? firestore,
    AdminContentService? adminContentService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _adminContentService = adminContentService ?? AdminContentService();

  final FirebaseFirestore _firestore;
  final AdminContentService _adminContentService;

  static const List<String> followUpStatuses = AgencyFollowUpStatus.values;

  final RxList<ContactIntake> contactIntakes = <ContactIntake>[].obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _contactIntakesSubscription;

  @override
  void onInit() {
    super.onInit();
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

    _contactIntakesSubscription =
        _firestore.collection('contact_intakes').snapshots().listen(
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

        parsed.sort((a, b) {
          final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });

        contactIntakes.assignAll(parsed);
        lastError.value = '';
        isLoading.value = false;
      },
      onError: (Object error) {
        debugPrint('Flux Firestore contact_intakes indisponible : $error');
        contactIntakes.clear();
        lastError.value = 'contact_intakes_stream_failed';
        isLoading.value = false;
      },
    );
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
        final updated = ContactIntake.fromMap(
          <String, dynamic>{
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
          },
          fallbackId: current.id,
        );
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
        final updated = ContactIntake.fromMap(
          <String, dynamic>{
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
          },
          fallbackId: current.id,
        );
        contactIntakes[index] = updated;
        contactIntakes.refresh();
      }
    }

    return response;
  }
}
