import 'package:flutter/foundation.dart';

/// Lit `users/{uid}/private/contact` pour un compte.
///
/// Injectable pour que la logique de fenêtre, de lots et d'invalidation de
/// [PrivateContactCache] soit vérifiable sans Firestore.
typedef PrivateContactReader =
    Future<Map<String, dynamic>?> Function(String uid);

/// Coordonnées privées (e-mail, téléphone, motif de suspension) des comptes
/// de la fenêtre actuellement chargée par `UserController`.
///
/// e-mail et téléphone ont quitté le document principal `users/{uid}` pour
/// `users/{uid}/private/contact`, qu'un non-admin ne peut pas lire (voir le
/// commentaire de `AppUser.fromMap`). La liste en a pourtant besoin pour sa
/// colonne compte et pour la recherche.
///
/// Le portail s'abonnait pour cela à
/// `collectionGroup('private').snapshots()`, sans filtre ni limite. Cet
/// abonnement recevait en continu *tous* les documents privés de *tous* les
/// comptes de la plateforme — `contact`, mais aussi `adminNotes` et
/// `guardianConsent`, jetés côté client — alors que la liste n'en montre au
/// plus que la fenêtre chargée. À 5 000 comptes, cela faisait plus de 5 000
/// documents facturés et un écouteur permanent à chaque ouverture de
/// session, pour 500 lignes réellement affichées.
///
/// Ici, un document est lu une fois, pour les seuls comptes affichés, et
/// n'est jamais relu tant qu'il reste dans la fenêtre.
///
/// Contrepartie assumée : les coordonnées ne se mettent plus à jour en
/// direct. Un numéro changé depuis le mobile apparaît au prochain
/// « Recharger ». La fiche d'un compte, elle, relit toujours ses champs
/// privés à son ouverture (`UserController.fetchUserWithPrivateFields`) :
/// la valeur sur laquelle un administrateur décide reste donc fraîche.
class PrivateContactCache {
  PrivateContactCache({required this.reader, this.batchSize = defaultBatchSize})
    : assert(batchSize > 0, 'La taille de lot doit être positive.');

  /// Nombre d'uid lus par vague. Borne la concurrence : 500 lectures
  /// simultanées au premier chargement saturent la file réseau du
  /// navigateur et retardent d'autant le premier affichage.
  static const int defaultBatchSize = 50;

  final PrivateContactReader reader;
  final int batchSize;

  final Map<String, Map<String, dynamic>> _byUid =
      <String, Map<String, dynamic>>{};

  /// uid dont la lecture est en vol. Le flux `users` réémet la fenêtre
  /// entière dès qu'un seul document change : sans cette garde, chaque
  /// émission relancerait les mêmes lectures.
  final Set<String> _inFlight = <String>{};

  /// Incrémenté par [invalidate]. Une vague lancée pour une fenêtre périmée
  /// ne doit plus écrire dans le cache ni remonter d'erreur.
  int _generation = 0;

  bool _hasLoaded = false;

  /// Vrai dès qu'une vague a abouti. Tant que c'est faux, l'appelant ne
  /// doit pas projeter le cache sur la liste : il effacerait les adresses
  /// au lieu de les compléter.
  bool get hasLoaded => _hasLoaded;

  /// Le document de [uid], `null` s'il n'a pas encore été lu. Un document
  /// absent côté Firestore est mémorisé comme une map vide, pas comme
  /// `null` : sans cela il serait relu à chaque émission du flux.
  Map<String, dynamic>? contactFor(String uid) => _byUid[uid];

  /// Aligne le cache sur [windowUids] : oublie les comptes sortis de la
  /// fenêtre, lit ceux qui y entrent.
  ///
  /// [onApplied] est appelé après chaque vague, pour que les premières
  /// lignes affichent leur adresse sans attendre la fin de la fenêtre.
  Future<void> syncWindow(
    Iterable<String> windowUids, {
    required void Function() onApplied,
    required void Function(Object error) onError,
  }) async {
    final window = windowUids.toSet();

    // Sans cet oubli, le cache grossit indéfiniment au fil des « charger
    // plus » et des reconnexions.
    _byUid.removeWhere((uid, _) => !window.contains(uid));

    final missing = window
        .where((uid) => !_byUid.containsKey(uid) && !_inFlight.contains(uid))
        .toList(growable: false);

    if (missing.isEmpty) {
      _hasLoaded = true;
      onApplied();
      return;
    }

    final generation = _generation;
    _inFlight.addAll(missing);

    try {
      for (var start = 0; start < missing.length; start += batchSize) {
        final end = start + batchSize < missing.length
            ? start + batchSize
            : missing.length;
        final batch = missing.sublist(start, end);
        final contacts = await Future.wait(batch.map(reader));

        if (generation != _generation) {
          return;
        }

        for (var index = 0; index < batch.length; index += 1) {
          _byUid[batch[index]] = contacts[index] ?? <String, dynamic>{};
        }

        _hasLoaded = true;
        onApplied();
      }
    } catch (error, stackTrace) {
      debugPrint('Lecture des coordonnées privées impossible : $error');
      debugPrintStack(stackTrace: stackTrace);
      if (generation == _generation) {
        onError(error);
      }
    } finally {
      _inFlight.removeAll(missing);
    }
  }

  /// Vide le cache et périme les vagues en vol. À appeler quand le flux
  /// `users` est coupé (déconnexion, « réessayer », « charger plus »).
  void invalidate() {
    _generation += 1;
    _inFlight.clear();
    _byUid.clear();
    _hasLoaded = false;
  }
}
