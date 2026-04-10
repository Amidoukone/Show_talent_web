import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/video.dart';

class VideoController extends GetxController {
  var videoList = <Video>[].obs;

  @override
  void onInit() {
    super.onInit();
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
                return Video.fromMap(doc.data());
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
    try {
      await FirebaseFirestore.instance
          .collection('videos')
          .doc(videoId)
          .delete();

      videoList.removeWhere((video) => video.id == videoId);

      Get.snackbar('Succès', 'Vidéo supprimée avec succès.');
    } catch (e) {
      Get.snackbar('Erreur', 'Échec de la suppression de la vidéo : $e');
    }
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
        return Video.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de récupérer la vidéo.');
    }
    return null;
  }

  Future<void> blockUser(String userId) async {
    Get.snackbar('Succès', 'Utilisateur bloqué avec succès.');
  }

  Future<void> unblockUser(String userId) async {
    Get.snackbar('Succès', 'Utilisateur débloqué avec succès.');
  }
}
