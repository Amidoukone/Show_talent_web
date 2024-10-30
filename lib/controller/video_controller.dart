import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/video.dart';

class VideoController extends GetxController {
  // Liste observable des vidéos
  var videoList = <Video>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchVideos();  // Charger les vidéos dès l'initialisation du contrôleur
  }

  // Méthode pour récupérer les vidéos depuis Firestore en temps réel
  void fetchVideos() {
    FirebaseFirestore.instance.collection('videos').snapshots().listen((snapshot) {
      videoList.assignAll(
        snapshot.docs.map((doc) {
          try {
            return Video.fromMap(doc.data());  // Conversion des données Firestore en Video
          } catch (e) {
            print('Erreur lors de la récupération de la vidéo: $e');
            return null; // Si la vidéo est invalide, ignorer
          }
        }).whereType<Video>().toList(),  // Filtrer les objets non-valides
      );
    });
  }

  // Méthode pour récupérer les vidéos signalées
  List<Video> getReportedVideos() {
    return videoList.where((video) => video.reportCount > 0).toList();
  }

  // Méthode pour récupérer toutes les vidéos
  List<Video> getAllVideos() {
    return videoList; // Récupère toutes les vidéos
  }

  // Méthode pour aimer/retirer le like d'une vidéo
  void likeVideo(String videoId, String userId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('videos').doc(videoId).get();
      var videoData = doc.data() as Map<String, dynamic>;

      List<String> likes = List<String>.from(videoData['likes'] ?? []);
      if (likes.contains(userId)) {
        likes.remove(userId); // Retirer le like si déjà liké
      } else {
        likes.add(userId); // Ajouter un like
      }

      await FirebaseFirestore.instance.collection('videos').doc(videoId).update({
        'likes': likes,
      });

      Get.snackbar('Succès', 'Action effectuée avec succès.');
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de liker la vidéo.');
    }
  }

  // Méthode pour partager une vidéo
  void partagerVideo(String videoId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('videos').doc(videoId).get();
      var videoData = doc.data() as Map<String, dynamic>;

      int shareCount = videoData['shareCount'] ?? 0;
      shareCount++;  // Incrémenter le nombre de partages

      await FirebaseFirestore.instance.collection('videos').doc(videoId).update({
        'shareCount': shareCount,
      });

      Get.snackbar('Succès', 'Vidéo partagée avec succès !');
    } catch (e) {
      Get.snackbar('Erreur', 'Erreur lors du partage de la vidéo.');
    }
  }

  // Méthode pour signaler une vidéo inappropriée
  void signalerVideo(String videoId, String userId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('videos').doc(videoId).get();
      var videoData = doc.data() as Map<String, dynamic>;

      List<String> reports = List<String>.from(videoData['reports'] ?? []);
      int reportCount = videoData['reportCount'] ?? 0;

      if (!reports.contains(userId)) {
        reports.add(userId);  // Ajouter un signalement
        reportCount++;  // Incrémenter le nombre de signalements

        await FirebaseFirestore.instance.collection('videos').doc(videoId).update({
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

  // Méthode pour supprimer une vidéo
  Future<void> deleteVideo(String videoId) async {
    try {
      // Supprimer la vidéo de Firestore
      await FirebaseFirestore.instance.collection('videos').doc(videoId).delete();

      // Supprimer la vidéo de la liste locale
      videoList.removeWhere((video) => video.id == videoId);

      Get.snackbar('Succès', 'Vidéo supprimée avec succès.');
    } catch (e) {
      Get.snackbar('Erreur', 'Échec de la suppression de la vidéo : $e');
    }
  }

  // Méthode pour mettre à jour la vidéo avec une nouvelle URL (si nécessaire)
  Future<void> updateVideo(String videoId, Map<String, dynamic> newVideoData) async {
    try {
      await FirebaseFirestore.instance.collection('videos').doc(videoId).update(newVideoData);
      Get.snackbar('Succès', 'Vidéo mise à jour avec succès.');
    } catch (e) {
      Get.snackbar('Erreur', 'Erreur lors de la mise à jour de la vidéo.');
    }
  }

  // Méthode pour récupérer une vidéo spécifique à partir de son ID
  Future<Video?> getVideoById(String videoId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('videos').doc(videoId).get();
      if (doc.exists) {
        return Video.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de récupérer la vidéo.');
    }
    return null;
  }

  // Méthode pour bloquer un utilisateur
  Future<void> blockUser(String userId) async {
    // Logique pour bloquer l'utilisateur (à implémenter selon votre structure de données)
    // Exemple : ajout de l'utilisateur à une liste de bloqués dans Firestore
    Get.snackbar('Succès', 'Utilisateur bloqué avec succès.');
  }

  // Méthode pour débloquer un utilisateur
  Future<void> unblockUser(String userId) async {
    // Logique pour débloquer l'utilisateur (à implémenter selon votre structure de données)
    // Exemple : suppression de l'utilisateur d'une liste de bloqués dans Firestore
    Get.snackbar('Succès', 'Utilisateur débloqué avec succès.');
  }
}