import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:show_talent/models/notification.dart';

class NotificationController extends GetxController {
  final RxList<NotificationModel> _notifications = <NotificationModel>[].obs;
  List<NotificationModel> get notifications => _notifications;

  User? _currentUser;

  @override
  void onInit() {
    super.onInit();
    initCurrentUser();
  }

  void initCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _currentUser = null;
      _notifications.clear();
      Get.snackbar('Erreur', 'Aucun utilisateur connecté.');
      return;
    }

    _currentUser = user;
    fetchNotifications();
  }

  void fetchNotifications() {
    final currentUser = _currentUser;
    if (currentUser == null) {
      Get.snackbar('Erreur', 'Aucun utilisateur connecté.');
      return;
    }

    FirebaseFirestore.instance
        .collection('notifications')
        .where('destinataire.id', isEqualTo: currentUser.uid)
        .orderBy('dateCreation', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        _notifications.assignAll(
          snapshot.docs
              .map((doc) => NotificationModel.fromMap(doc.data()))
              .toList(),
        );
        update();
      },
      onError: (_) {
        Get.snackbar(
          'Erreur',
          'Impossible de charger les notifications pour le moment.',
        );
      },
    );
  }

  Future<void> sendNotification(NotificationModel notification) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());
    } catch (_) {
      Get.snackbar('Erreur', "Échec de l'envoi de la notification.");
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'estLue': true});
    } catch (_) {
      Get.snackbar('Erreur', 'Échec de la mise à jour de la notification.');
    }
  }
}
