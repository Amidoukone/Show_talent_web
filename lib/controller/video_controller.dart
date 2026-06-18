import 'package:cloud_firestore/cloud_firestore.dart';
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

  var videoList = <Video>[].obs;

  @override
  void onInit() {
    super.onInit();
    if (_visualQaMode) {
      videoList.clear();
      return;
    }

    fetchVideos();
  }

  void fetchVideos() {
    FirebaseFirestore.instance.collection('videos').snapshots().listen((
      snapshot,
    ) {
      videoList.assignAll(
        snapshot.docs
            .map((doc) {
              try {
                return Video.fromMap({
                  ...doc.data(),
                  'id': doc.id,
                });
              } catch (e) {
                debugPrint('Erreur lors de la récupération de la vidéo : $e');
                return null;
              }
            })
            .whereType<Video>()
            .toList(),
      );
    }, onError: (Object error) {
      debugPrint('Flux Firestore vidéos indisponible : $error');
      videoList.clear();
    });
  }

  List<Video> getReportedVideos() {
    return videoList.where((video) => video.reportCount > 0).toList();
  }

  List<Video> getAllVideos() {
    return videoList;
  }

  void likeVideo(String videoId, String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();
      final videoData = doc.data() as Map<String, dynamic>;

      final likes = List<String>.from(videoData['likes'] ?? []);
      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }

      await FirebaseFirestore.instance.collection('videos').doc(videoId).update(
        {
          'likes': likes,
        },
      );

      Get.snackbar('Succès', 'Action effectuée avec succès.');
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de liker la vidéo.');
    }
  }

  void partagerVideo(String videoId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();
      final videoData = doc.data() as Map<String, dynamic>;

      var shareCount = videoData['shareCount'] ?? 0;
      shareCount++;

      await FirebaseFirestore.instance.collection('videos').doc(videoId).update(
        {
          'shareCount': shareCount,
        },
      );

      Get.snackbar('Succès', 'Vidéo partagée avec succès.');
    } catch (e) {
      Get.snackbar('Erreur', 'Erreur lors du partage de la vidéo.');
    }
  }

  void signalerVideo(String videoId, String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();
      final videoData = doc.data() as Map<String, dynamic>;

      final reports = List<String>.from(videoData['reports'] ?? []);
      var reportCount = videoData['reportCount'] ?? 0;

      if (!reports.contains(userId)) {
        reports.add(userId);
        reportCount++;

        await FirebaseFirestore.instance
            .collection('videos')
            .doc(videoId)
            .update({
          'reports': reports,
          'reportCount': reportCount,
        });

        Get.snackbar('Succès', 'Vidéo signalée avec succès.');
      } else {
        Get.snackbar('Erreur', 'Vous avez déjà signalé cette vidéo.');
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Erreur lors du signalement de la vidéo.');
    }
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

  Future<void> updateVideo(
    String videoId,
    Map<String, dynamic> newVideoData,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .update(newVideoData);
      Get.snackbar('Succès', 'Vidéo mise à jour avec succès.');
    } catch (e) {
      Get.snackbar('Erreur', 'Erreur lors de la mise à jour de la vidéo.');
    }
  }

  Future<Video?> getVideoById(String videoId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .get();
      if (doc.exists) {
        return Video.fromMap({
          ...(doc.data() as Map<String, dynamic>),
          'id': doc.id,
        });
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de récupérer la vidéo.');
    }
    return null;
  }
}
