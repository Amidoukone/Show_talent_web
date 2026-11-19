import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
import '../models/contact_leak_report.dart';

/// Les coordonnées retirées avant publication, et personne pour les lire.
///
/// Le serveur retire les numéros et les adresses des champs libres, puis
/// consigne ce qu'il a retiré. Ce contrôleur lit les deux traces, qui n'ont
/// pas la même forme parce que les deux surfaces nettoyées n'ont pas la même
/// architecture :
///
/// - une **offre** ou un **événement** n'a pas de projection publique, le
///   document *est* la surface de lecture. Il est donc nettoyé sur place, et
///   l'original part dans `contact_leak_reports` ;
/// - un **profil** a une projection publique, seule écrivain du document que
///   le monde lit. Le verdict vit donc sur `users/{uid}`, en deux champs
///   (`contactLeakFlagged`, `contactLeakFields`), et le document interne garde
///   la valeur saisie.
///
/// Deux flux, donc, et pas un : ni la collection ni la requête ne sont les
/// mêmes, et les fusionner aurait demandé de lire tous les utilisateurs pour
/// en retenir quelques-uns.
///
/// **Lecture seule, dans les deux cas.** `contact_leak_reports` est fermée en
/// écriture à tout le monde, opérateur compris : les déclencheurs écrivent par
/// le SDK Admin, et une trace de modération ne se retouche pas. L'opérateur
/// agit par les actions qui existent déjà — suspendre un compte, supprimer une
/// annonce — et non sur le signalement.
class ContactLeakController extends GetxController {
  ContactLeakController({FirebaseFirestore? firestore})
    : _visualQaMode = AppEnvironmentConfig.visualQaMode,
      _firestore = AppEnvironmentConfig.visualQaMode
          ? null
          : firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore? _firestore;
  final bool _visualQaMode;

  static const String reportsCollection = 'contact_leak_reports';

  /// Plafond de chaque flux.
  ///
  /// Pas de « charger plus » ici, et c'est un choix : un signalement est une
  /// ligne par document nettoyé, pas une par écriture, et la file se vide à
  /// mesure que la modération agit. Si elle dépassait ce plafond, le problème
  /// ne serait pas la pagination mais le volume — l'écran le dit par un
  /// bandeau plutôt que de laisser croire qu'il montre tout.
  static const int _loadLimit = 500;

  final RxList<ContactLeakReport> reports = <ContactLeakReport>[].obs;
  final RxList<ContactLeakProfile> profiles = <ContactLeakProfile>[].obs;
  final RxBool isLoading = true.obs;
  final RxString lastError = ''.obs;

  /// Si l'un des deux flux a atteint son plafond.
  final RxBool truncated = false.obs;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reportsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _profilesSubscription;

  bool _reportsLoaded = false;
  bool _profilesLoaded = false;

  void _markLoaded() {
    if (_reportsLoaded && _profilesLoaded) {
      isLoading.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    if (_visualQaMode) {
      reports.clear();
      profiles.clear();
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
    _reportsSubscription?.cancel();
    _profilesSubscription?.cancel();
    super.onClose();
  }

  Future<void> _handleAuthStateChanged(User? user) async {
    if (user == null) {
      await _stopStreams(clearData: true);
      return;
    }

    _listen();
  }

  Future<void> _stopStreams({bool clearData = false}) async {
    await _reportsSubscription?.cancel();
    await _profilesSubscription?.cancel();
    _reportsSubscription = null;
    _profilesSubscription = null;
    _reportsLoaded = false;
    _profilesLoaded = false;

    if (clearData) {
      reports.clear();
      profiles.clear();
      lastError.value = '';
      truncated.value = false;
      isLoading.value = false;
    }
  }

  void _listen() {
    if (FirebaseAuth.instance.currentUser == null) {
      reports.clear();
      profiles.clear();
      isLoading.value = false;
      return;
    }

    isLoading.value = true;
    _reportsLoaded = false;
    _profilesLoaded = false;
    _reportsSubscription?.cancel();
    _profilesSubscription?.cancel();

    // Tri sur `flaggedAt` seul, sans filtre : un seul champ d'ordre, donc
    // l'index automatique suffit. Le partage offres / événements est un filtre
    // d'affichage — il porte sur quelques centaines de lignes au plus, et le
    // faire côté serveur demanderait un index composite à déployer avant ce
    // portail pour un gain nul.
    _reportsSubscription = _firestore!
        .collection(reportsCollection)
        .orderBy('flaggedAt', descending: true)
        .limit(_loadLimit)
        .snapshots()
        .listen(
          (snapshot) {
            final parsed = <ContactLeakReport>[];
            for (final doc in snapshot.docs) {
              try {
                parsed.add(ContactLeakReport.fromDoc(doc));
              } catch (error) {
                debugPrint(
                  'Signalement ignore (parsing) : ${doc.id} -> $error',
                );
              }
            }
            reports.assignAll(parsed);
            _updateTruncated(snapshot.docs.length, profiles.length);
            lastError.value = '';
            _reportsLoaded = true;
            _markLoaded();
          },
          onError: (Object error) {
            debugPrint('Flux Firestore des signalements indisponible : $error');
            reports.clear();
            lastError.value =
                'Impossible de charger les signalements. Un claim admin '
                'signé est requis : reconnectez-vous, puis réessayez.';
            _reportsLoaded = true;
            _markLoaded();
          },
        );

    // Égalité seule, donc index automatique là aussi. Les profils signalés se
    // comptent sur les doigts de la main dans une base saine.
    _profilesSubscription = _firestore
        .collection('users')
        .where('contactLeakFlagged', isEqualTo: true)
        .limit(_loadLimit)
        .snapshots()
        .listen(
          (snapshot) {
            final parsed = <ContactLeakProfile>[];
            for (final doc in snapshot.docs) {
              try {
                parsed.add(ContactLeakProfile.fromDoc(doc));
              } catch (error) {
                debugPrint('Profil ignore (parsing) : ${doc.id} -> $error');
              }
            }
            // Par nom, les signalements de profil n'ayant pas d'horodatage :
            // le serveur ne pose que le drapeau et la liste des champs.
            parsed.sort(
              (a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()),
            );
            profiles.assignAll(parsed);
            _updateTruncated(reports.length, snapshot.docs.length);
            _profilesLoaded = true;
            _markLoaded();
          },
          onError: (Object error) {
            debugPrint(
              'Flux Firestore des profils signales indisponible : $error',
            );
            profiles.clear();
            _profilesLoaded = true;
            _markLoaded();
          },
        );
  }

  void _updateTruncated(int reportCount, int profileCount) {
    truncated.value = reportCount >= _loadLimit || profileCount >= _loadLimit;
  }

  /// Relance les deux flux, pour le bouton « Recharger ».
  Future<void> refreshLeaks() async {
    if (_visualQaMode) return;
    if (FirebaseAuth.instance.currentUser == null) {
      await _stopStreams(clearData: true);
      return;
    }

    _listen();
  }
}
