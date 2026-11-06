import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
import '../models/admin_action_response.dart';
import '../models/video.dart';
import '../services/admin_content_service.dart';

class VideoController extends GetxController {
  VideoController({AdminContentService? adminContentService})
    : _visualQaMode = AppEnvironmentConfig.visualQaMode,
      _adminContentService = AppEnvironmentConfig.visualQaMode
          ? AdminContentService.visualQa()
          : adminContentService ?? AdminContentService();

  final AdminContentService _adminContentService;
  final bool _visualQaMode;

  // Voir OffreController pour le détail du choix (plafond + "charger plus",
  // tri par createdAt). Vérifié comme pour offres/événements : createdAt
  // est posé sans condition au seul point de création d'un document vidéo
  // (upload_session.ts:678, "Seeded here, once, on the document's only
  // creation point"). Jamais absent, aucune réserve historique.
  static const int _initialLoadLimit = 500;
  static const int _loadMoreIncrement = 500;

  // Voir OffreController._recomputeOffres/_firstPage/_extraPages pour le
  // détail : page 1 temps réel, pages suivantes par curseur et statiques.
  List<Video> _firstPage = <Video>[];
  List<Video> _extraPages = <Video>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _isLoadingMore = false;

  var videoList = <Video>[].obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;
  final RxBool hasMore = false.obs;

  /// Nombre total de vidéos, indépendant de la fenêtre chargée ci-dessus.
  /// Voir UserController.totalUsersCount pour le détail du problème évité
  /// (l'écran Statistiques affichait un total tronqué à [_initialLoadLimit]).
  final Rxn<int> totalVideosCount = Rxn<int>();

  Future<void> _refreshTotalVideosCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .count()
          .get();
      totalVideosCount.value = snapshot.count;
    } catch (error) {
      debugPrint('Comptage total des vidéos indisponible : $error');
    }
  }

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _videosSubscription;

  void _recomputeVideos() {
    final byId = <String, Video>{};
    for (final video in _extraPages) {
      byId[video.id] = video;
    }
    for (final video in _firstPage) {
      byId[video.id] = video;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    videoList.assignAll(merged);
  }

  @override
  void onInit() {
    super.onInit();
    if (_visualQaMode) {
      videoList.clear();
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
    _videosSubscription?.cancel();
    super.onClose();
  }

  void _handleAuthStateChanged(User? user) {
    if (user == null) {
      _videosSubscription?.cancel();
      _videosSubscription = null;
      videoList.clear();
      lastError.value = '';
      hasMore.value = false;
      _firstPage = <Video>[];
      _extraPages = <Video>[];
      _lastDocument = null;
      totalVideosCount.value = null;
      isLoading.value = false;
      return;
    }

    fetchVideos();
  }

  // Called both from onInit/auth-state changes and from three "Recharger"
  // reload buttons across the moderation widgets -- must be safe to call
  // repeatedly. Previously this opened a brand-new Firestore listener on
  // every call with nothing ever cancelling any of them (no onClose
  // override either), so listeners stacked up forever and kept running
  // after logout. Mirrors OffreController/EventController's pattern.
  void fetchVideos() {
    if (_visualQaMode) return;
    if (FirebaseAuth.instance.currentUser == null) {
      videoList.clear();
      lastError.value = '';
      isLoading.value = false;
      return;
    }

    unawaited(_refreshTotalVideosCount());

    isLoading.value = true;
    _videosSubscription?.cancel();
    _extraPages = <Video>[];
    _lastDocument = null;
    _videosSubscription = FirebaseFirestore.instance
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(_initialLoadLimit)
        .snapshots()
        .listen(
          (snapshot) {
            final parsed = snapshot.docs
                .map((doc) {
                  try {
                    return Video.fromMap({...doc.data(), 'id': doc.id});
                  } catch (e) {
                    debugPrint(
                      'Erreur lors de la récupération de la vidéo : $e',
                    );
                    return null;
                  }
                })
                .whereType<Video>()
                .toList();

            _firstPage = parsed;
            if (snapshot.docs.isNotEmpty) {
              _lastDocument = snapshot.docs.last;
            }
            _recomputeVideos();
            hasMore.value = snapshot.docs.length >= _initialLoadLimit;
            lastError.value = '';
            isLoading.value = false;
          },
          onError: (Object error) {
            debugPrint('Flux Firestore vidéos indisponible : $error');
            videoList.clear();
            lastError.value =
                'Impossible de charger les vidéos. Vérifiez votre connexion puis réessayez.';
            isLoading.value = false;
          },
        );
  }

  /// Voir OffreController.loadMoreOffres.
  Future<void> loadMoreVideos() async {
    if (!hasMore.value || _isLoadingMore) return;
    final cursor = _lastDocument;
    if (cursor == null) return;

    _isLoadingMore = true;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(cursor)
          .limit(_loadMoreIncrement)
          .get();

      final parsed = snapshot.docs
          .map((doc) {
            try {
              return Video.fromMap({...doc.data(), 'id': doc.id});
            } catch (e) {
              debugPrint('Erreur lors de la récupération de la vidéo : $e');
              return null;
            }
          })
          .whereType<Video>()
          .toList();

      _extraPages = <Video>[..._extraPages, ...parsed];
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      hasMore.value = snapshot.docs.length >= _loadMoreIncrement;
      _recomputeVideos();
    } catch (error) {
      debugPrint('Chargement supplémentaire des vidéos impossible : $error');
      lastError.value =
          'Impossible de charger plus de vidéos. Vérifiez votre connexion puis réessayez.';
    } finally {
      _isLoadingMore = false;
    }
  }

  List<Video> getReportedVideos() {
    return videoList.where((video) => video.reportCount > 0).toList();
  }

  List<Video> getAllVideos() {
    return videoList;
  }

  /// Même contrat de retour qu'OffreController/EventController : une
  /// réponse typée, jamais une exception. VideoController levait auparavant
  /// un StateError ici, seul des 3 contrôleurs de contenu à rompre ce
  /// contrat — un appelant qui ne s'y attendait pas affichait la chaîne
  /// d'erreur brute au lieu du message propre porté par la réponse.
  Future<AdminActionResponse> deleteVideo(String videoId) async {
    final response = await _adminContentService.deleteVideo(videoId: videoId);
    if (response.success) {
      videoList.removeWhere((video) => video.id == videoId);
    }
    return response;
  }

  Future<AdminActionResponse> setVideoStatus(
    String videoId,
    String status, {
    String reason = '',
  }) {
    return _adminContentService.setVideoStatus(
      videoId: videoId,
      status: status,
      reason: reason,
    );
  }

  Future<AdminActionResponse> approveVideo(String videoId) {
    return setVideoStatus(videoId, 'approved');
  }

  Future<AdminActionResponse> rejectVideo(
    String videoId, {
    String reason = '',
  }) async {
    final response = await _adminContentService.rejectVideo(
      videoId: videoId,
      reason: reason,
    );
    if (response.success) {
      videoList.removeWhere((video) => video.id == videoId);
    }
    return response;
  }
}
