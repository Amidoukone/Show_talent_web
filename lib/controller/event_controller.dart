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
    'ouvert',
    'ferme',
    'archive',
  ];

  // Voir OffreController pour le détail du choix (plafond + "charger plus",
  // tri par createdAt). Vérifié comme pour les offres : createdAt est posé
  // sans condition au seul point de création d'un événement
  // (event_repository.dart, bloc "nouvel événement") et le mobile
  // l'utilise déjà lui-même comme tri de référence
  // (event_repository.dart:502,504). Ajouté le 2025-03-18 (commit
  // a484641) ; la purge totale des événements du 2026-09-28 a effacé tout
  // document antérieur à cet ajout.
  static const int _initialLoadLimit = 500;
  static const int _loadMoreIncrement = 500;

  // Voir OffreController._recomputeOffres/_firstPage/_extraPages pour le
  // détail : page 1 temps réel, pages suivantes par curseur et statiques.
  List<Event> _firstPage = <Event>[];
  List<Event> _extraPages = <Event>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _isLoadingMore = false;

  final RxList<Event> events = <Event>[].obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;
  final RxBool hasMore = false.obs;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSubscription;

  void _recomputeEvents() {
    final byId = <String, Event>{};
    for (final event in _extraPages) {
      byId[event.id] = event;
    }
    for (final event in _firstPage) {
      byId[event.id] = event;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    events.assignAll(merged);
  }

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
    _extraPages = <Event>[];
    _lastDocument = null;

    _eventsSubscription = _firestore!
        .collection('events')
        .orderBy('createdAt', descending: true)
        .limit(_initialLoadLimit)
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

            _firstPage = parsed;
            if (snapshot.docs.isNotEmpty) {
              _lastDocument = snapshot.docs.last;
            }
            _recomputeEvents();
            hasMore.value = snapshot.docs.length >= _initialLoadLimit;
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
  Future<void> loadMoreEvents() async {
    if (!hasMore.value || _isLoadingMore) return;
    final cursor = _lastDocument;
    if (cursor == null) return;

    _isLoadingMore = true;
    try {
      final snapshot = await _firestore!
          .collection('events')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(cursor)
          .limit(_loadMoreIncrement)
          .get();

      final parsed = <Event>[];
      for (final doc in snapshot.docs) {
        try {
          parsed.add(Event.fromDoc(doc));
        } catch (error) {
          debugPrint('Événement ignoré (parsing) : ${doc.id} -> $error');
        }
      }

      _extraPages = <Event>[..._extraPages, ...parsed];
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      hasMore.value = snapshot.docs.length >= _loadMoreIncrement;
      _recomputeEvents();
    } catch (error) {
      debugPrint(
        'Chargement supplémentaire des événements impossible : $error',
      );
      lastError.value =
          'Impossible de charger plus d’événements. Vérifiez votre connexion puis réessayez.';
    } finally {
      _isLoadingMore = false;
    }
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
      _firstPage = <Event>[];
      _extraPages = <Event>[];
      _lastDocument = null;
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
