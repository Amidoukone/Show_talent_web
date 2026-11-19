import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
import '../models/messaging_config.dart';

/// Lit l'état de la messagerie médiatisée.
///
/// **Lecture seule, et il n'y a rien à brancher d'autre.** `config/messaging`
/// est fermé en écriture à tout client par `firestore.rules`, et aucune Cloud
/// Function ne l'écrit : il se modifie par la console, ce qui est délibéré —
/// refermer un mode qui aurait mal tourné ne doit pas demander de publier un
/// build. La procédure est écrite dans
/// `docs/runbook-production-admin-mobile.md`.
///
/// Ce que ce contrôleur apporte n'est donc pas une action mais une **vue** :
/// activer le mode sans nommer de compte de support ferme toute la messagerie
/// de la plateforme, et rien, nulle part, ne l'annonçait.
///
/// Pas d'écoute de l'état d'authentification, contrairement aux autres
/// contrôleurs : `config` est en `allow read: if true`, donc la lecture ne
/// dépend d'aucune session. Un flux qui s'ouvre une fois et reste branché
/// suffit, et il reflète immédiatement une bascule faite à la console.
class MessagingConfigController extends GetxController {
  MessagingConfigController({FirebaseFirestore? firestore})
    : _visualQaMode = AppEnvironmentConfig.visualQaMode,
      _firestore = AppEnvironmentConfig.visualQaMode
          ? null
          : firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore? _firestore;
  final bool _visualQaMode;

  static const String configCollection = 'config';
  static const String messagingDocument = 'messaging';

  final Rx<MessagingConfig> config = MessagingConfig.absent.obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    if (_visualQaMode) {
      config.value = MessagingConfig.absent;
      isLoading.value = false;
      return;
    }

    _listen();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void _listen() {
    isLoading.value = true;
    _subscription?.cancel();
    _subscription = _firestore!
        .collection(configCollection)
        .doc(messagingDocument)
        .snapshots()
        .listen(
          (snapshot) {
            config.value = MessagingConfig.fromDoc(snapshot);
            lastError.value = '';
            isLoading.value = false;
          },
          onError: (Object error) {
            debugPrint('Lecture de config/messaging indisponible : $error');
            config.value = MessagingConfig.absent;
            lastError.value =
                'Impossible de lire le réglage de la messagerie. Réessayez.';
            isLoading.value = false;
          },
        );
  }

  /// Relance la lecture, pour le bouton « Recharger ».
  Future<void> refreshConfig() async {
    if (_visualQaMode) return;
    _listen();
  }
}
