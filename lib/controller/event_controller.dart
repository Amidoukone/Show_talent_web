import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/admin_action_response.dart';
import '../models/event.dart';
import '../services/admin_content_service.dart';

class EventController extends GetxController {
  EventController({
    FirebaseFirestore? firestore,
    AdminContentService? adminContentService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _adminContentService = adminContentService ?? AdminContentService();

  final FirebaseFirestore _firestore;
  final AdminContentService _adminContentService;

  static const List<String> moderationStatuses = <String>[
    'brouillon',
    'ouvert',
    'ferme',
    'archive',
  ];

  final RxList<Event> events = <Event>[].obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSubscription;

  @override
  void onInit() {
    super.onInit();
    _listenEvents();
  }

  @override
  void onClose() {
    _eventsSubscription?.cancel();
    super.onClose();
  }

  void _listenEvents() {
    isLoading.value = true;
    _eventsSubscription?.cancel();

    _eventsSubscription = _firestore.collection('events').snapshots().listen(
      (snapshot) {
        final parsed = <Event>[];

        for (final doc in snapshot.docs) {
          try {
            parsed.add(Event.fromDoc(doc));
          } catch (error) {
            debugPrint('Event ignore (parsing): ${doc.id} -> $error');
          }
        }

        parsed.sort((a, b) => b.dateDebut.compareTo(a.dateDebut));
        events.assignAll(parsed);
        lastError.value = '';
        isLoading.value = false;
      },
      onError: (Object error) {
        debugPrint('Flux Firestore events indisponible: $error');
        events.clear();
        lastError.value = 'events_stream_failed';
        isLoading.value = false;
      },
    );
  }

  void refreshEvents() {
    _listenEvents();
  }

  Future<AdminActionResponse> setEventStatus({
    required String eventId,
    required String status,
  }) async {
    final normalized = Event.normalizeStatus(status);
    if (!moderationStatuses.contains(normalized)) {
      return AdminActionResponse.failure(
        code: 'invalid_status',
        message: 'Statut evenement invalide.',
      );
    }

    final response = await _adminContentService.setEventStatus(
      eventId: eventId,
      status: normalized,
    );

    if (response.success) {
      final index = events.indexWhere((event) => event.id == eventId);
      if (index != -1) {
        events[index].statut = normalized;
        events.refresh();
      }
    }

    return response;
  }

  Future<AdminActionResponse> deleteEvent(String eventId) async {
    final response = await _adminContentService.deleteEvent(eventId: eventId);
    if (response.success) {
      events.removeWhere((event) => event.id == eventId);
    }
    return response;
  }
}
