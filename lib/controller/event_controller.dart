import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSubscription;

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
    _eventsSubscription?.cancel();
    super.onClose();
  }

  void _listenEvents() {
    if (FirebaseAuth.instance.currentUser == null) {
      events.clear();
      lastError.value = '';
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    _eventsSubscription?.cancel();

    _eventsSubscription = _firestore.collection('events').snapshots().listen(
      (snapshot) {
        final parsed = <Event>[];

        for (final doc in snapshot.docs) {
          try {
            parsed.add(Event.fromDoc(doc));
          } catch (error) {
            debugPrint('Événement ignoré (parsing) : ${doc.id} -> $error');
          }
        }

        parsed.sort((a, b) => b.dateDebut.compareTo(a.dateDebut));
        events.assignAll(parsed);
        lastError.value = '';
        isLoading.value = false;
      },
      onError: (Object error) {
        debugPrint('Flux Firestore events indisponible : $error');
        events.clear();
        lastError.value = 'events_stream_failed';
        isLoading.value = false;
      },
    );
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    if (user == null) {
      await _stopEventsStream(clearData: true);
      return;
    }

    _listenEvents();
  }

  Future<void> _stopEventsStream({bool clearData = false}) async {
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;

    if (clearData) {
      events.clear();
      lastError.value = '';
      isLoading.value = false;
    }
  }

  void refreshEvents() {
    if (FirebaseAuth.instance.currentUser == null) {
      _stopEventsStream(clearData: true);
      return;
    }

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
        message: "Statut d'événement invalide.",
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
