import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
import '../models/admin_action_response.dart';
import '../models/event.dart';
import '../services/admin_content_service.dart';

class EventController extends GetxController {
  EventController({
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
    'ouvert',
    'ferme',
    'archive',
  ];

  // Voir OffreController pour le détail du choix (plafond + "charger plus",
  // tri par documentId pour n'exclure aucun document en silence).
  static const int _initialLoadLimit = 500;
  static const int _loadMoreIncrement = 500;
  int _currentLimit = _initialLoadLimit;

  final RxList<Event> events = <Event>[].obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;
  final RxBool hasMore = false.obs;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSubscription;

  @override
  void onInit() {
    super.onInit();
    if (_visualQaMode) {
      events.clear();
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

    _eventsSubscription = _firestore!
        .collection('events')
        .orderBy(FieldPath.documentId)
        .limit(_currentLimit)
        .snapshots()
        .listen(
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
        hasMore.value = snapshot.docs.length >= _currentLimit;
        lastError.value = '';
        isLoading.value = false;
      },
      onError: (Object error) {
        debugPrint('Flux Firestore events indisponible : $error');
        events.clear();
        lastError.value =
            'Impossible de charger les événements. Vérifiez votre connexion puis réessayez.';
        isLoading.value = false;
      },
    );
  }

  /// Voir OffreController.loadMoreOffres.
  void loadMoreEvents() {
    if (!hasMore.value) return;
    _currentLimit += _loadMoreIncrement;
    _listenEvents();
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
      hasMore.value = false;
      _currentLimit = _initialLoadLimit;
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
        message: "Statut d’événement invalide.",
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
