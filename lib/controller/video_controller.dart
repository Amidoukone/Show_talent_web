import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
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
  // tri par documentId pour n'exclure aucun document en silence).
  static const int _initialLoadLimit = 500;
  static const int _loadMoreIncrement = 500;
  int _currentLimit = _initialLoadLimit;

  var videoList = <Video>[].obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;
  final RxBool hasMore = false.obs;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _videosSubscription;

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
      _currentLimit = _initialLoadLimit;
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

    isLoading.value = true;
    _videosSubscription?.cancel();
    _videosSubscription = FirebaseFirestore.instance
        .collection('videos')
        .orderBy(FieldPath.documentId)
        .limit(_currentLimit)
        .snapshots()
        .listen(
          (snapshot) {
            videoList.assignAll(
              snapshot.docs
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
                  .toList(),
            );
            hasMore.value = snapshot.docs.length >= _currentLimit;
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
  void loadMoreVideos() {
    if (!hasMore.value) return;
    _currentLimit += _loadMoreIncrement;
    fetchVideos();
  }

  List<Video> getReportedVideos() {
    return videoList.where((video) => video.reportCount > 0).toList();
  }

  List<Video> getAllVideos() {
    return videoList;
  }

  Future<void> deleteVideo(String videoId) async {
    final response = await _adminContentService.deleteVideo(videoId: videoId);
    if (!response.success) {
      final message = response.message.trim().isNotEmpty
          ? response.message
          : 'Suppression de la vidéo impossible.';
      throw StateError(message);
    }

    videoList.removeWhere((video) => video.id == videoId);
  }

  Future<void> setVideoStatus(
    String videoId,
    String status, {
    String reason = '',
  }) async {
    final response = await _adminContentService.setVideoStatus(
      videoId: videoId,
      status: status,
      reason: reason,
    );
    if (!response.success) {
      final message = response.message.trim().isNotEmpty
          ? response.message
          : 'Mise à jour du statut vidéo impossible.';
      throw StateError(message);
    }
  }

  Future<void> approveVideo(String videoId) async {
    await setVideoStatus(videoId, 'approved');
  }

  Future<void> rejectVideo(String videoId, {String reason = ''}) async {
    final response = await _adminContentService.rejectVideo(
      videoId: videoId,
      reason: reason,
    );
    if (!response.success) {
      final message = response.message.trim().isNotEmpty
          ? response.message
          : 'Refus de la vidéo impossible.';
      throw StateError(message);
    }

    videoList.removeWhere((video) => video.id == videoId);
  }

}
