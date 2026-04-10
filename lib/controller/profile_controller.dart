import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:show_talent/models/user.dart';

class ProfileController extends GetxController {
  AppUser? user;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> updateUserId(String uid) async {
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      if (!snapshot.exists) {
        return;
      }

      user = AppUser.fromMap(snapshot.data()!);
      update();
    } catch (_) {
      Get.snackbar('Erreur', 'Erreur lors du chargement du profil.');
    }
  }

  Future<void> updateProfilePhoto(String uid, String photoUrl) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'photoProfil': photoUrl,
      });
      user?.photoProfil = photoUrl;
      update();
    } catch (_) {
      Get.snackbar(
        'Erreur',
        'Échec de la mise à jour de la photo de profil.',
      );
    }
  }

  Future<void> updateUserProfile(AppUser updatedUser) async {
    try {
      await _firestore
          .collection('users')
          .doc(updatedUser.uid)
          .update(updatedUser.toMap());
      user = updatedUser;
      update();
      Get.snackbar('Succès', 'Profil mis à jour avec succès.');
    } catch (_) {
      Get.snackbar('Erreur', 'Échec de la mise à jour du profil.');
    }
  }

  Future<void> followUser() async {
    if (user == null || _auth.currentUser == null) {
      Get.snackbar('Erreur', 'Aucun utilisateur connecté.');
      return;
    }

    final currentUserId = _auth.currentUser!.uid;
    final profileUserId = user!.uid;

    try {
      final currentUserSnapshot =
          await _firestore.collection('users').doc(currentUserId).get();

      if (!currentUserSnapshot.exists) {
        Get.snackbar(
          'Erreur',
          "Impossible de récupérer les informations de l'utilisateur connecté.",
        );
        return;
      }

      final currentUserData = currentUserSnapshot.data()!;
      final followings =
          List<String>.from(currentUserData['followings'] ?? const []);

      if (followings.contains(profileUserId)) {
        followings.remove(profileUserId);
        user!.followers--;
      } else {
        followings.add(profileUserId);
        user!.followers++;
      }

      await _firestore.collection('users').doc(currentUserId).update({
        'followings': followings,
      });
      await _firestore.collection('users').doc(profileUserId).update({
        'followers': user!.followers,
      });

      update();
    } catch (_) {
      Get.snackbar('Erreur', 'Impossible de suivre cet utilisateur.');
    }
  }

  AppUser? getLoggedInUser() {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null && user?.uid == firebaseUser.uid) {
      return user;
    }
    return null;
  }
}
