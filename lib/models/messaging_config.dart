import 'package:cloud_firestore/cloud_firestore.dart';

/// L'interrupteur de la messagerie médiatisée, et les comptes qui la tiennent.
///
/// Vit dans `config/messaging`, **lisible par tout le monde et écrit par
/// personne** côté client : `firestore.rules` pose `allow read: if true;` et
/// `allow write: if false;` sur toute la collection `config`. Aucune Cloud
/// Function ne l'écrit non plus — il se modifie à la main, par la console, et
/// c'est délibéré : refermer un mode qui aurait mal tourné ne doit pas
/// demander de publier un build.
///
/// Le mode médiatisé fait passer toute mise en relation par un compte Adfoot,
/// pour deux raisons que le dépôt mobile documente : l'une réglementaire —
/// coordonner des mises en relation rapproche Adfoot de l'activité
/// d'intermédiaire, et l'avis juridique n'est pas rendu — l'autre
/// opérationnelle : si tout arrive dans une seule boîte, il faut répondre, et
/// une boîte muette abîme la confiance plus vite qu'une fonctionnalité
/// absente.
///
/// Les comptes de support sont **nommés dans ce document** et non reconnus à
/// leur rôle, qui se modifie par une console ou une mauvaise fusion, ni à leur
/// claim, qu'une règle ne sait pas lire sur un autre utilisateur. Une liste
/// écrite par le serveur est la seule désignation qui tienne.
///
/// Miroir en lecture de `messagingConfig()`, `mediatedMessagingEnabled()` et
/// `isAdfootSupportUid()` dans `firestore.rules`.
class MessagingConfig {
  const MessagingConfig({
    this.exists = false,
    this.mediatedOnly = false,
    this.supportUids = const <String>[],
  });

  /// Le document n'existe pas encore : l'interrupteur est au repos.
  static const MessagingConfig absent = MessagingConfig();

  /// Si le document `config/messaging` existe.
  ///
  /// Distingué de `mediatedOnly == false` : les deux donnent la même
  /// messagerie ouverte, mais pas la même conclusion pour l'opérateur — l'un
  /// est un réglage pris, l'autre un document jamais créé.
  final bool exists;

  /// Si toute mise en relation doit passer par un compte Adfoot.
  final bool mediatedOnly;

  /// Les comptes Adfoot qui tiennent la messagerie médiatisée.
  final List<String> supportUids;

  /// Si le mode est actif alors qu'aucun compte ne peut le tenir.
  ///
  /// **L'état à ne jamais laisser en production.** Les règles exigent que
  /// l'une des deux parties d'une conversation soit un compte nommé ici :
  /// activer le mode sans nommer personne ferme donc toute la messagerie de
  /// la plateforme. C'est le bon échec — fermé plutôt qu'ouvert — mais ce
  /// n'est pas un état utilisable, et rien ne l'annonçait.
  bool get closesAllMessaging => mediatedOnly && supportUids.isEmpty;

  /// Ce que le portail affiche comme état.
  String get statusLabel {
    if (!exists) return 'Non configurée';
    if (closesAllMessaging) return 'Médiatisée, sans compte de support';
    if (mediatedOnly) return 'Médiatisée';
    return 'Ouverte';
  }

  factory MessagingConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return absent;

    final rawUids = map['supportUids'];
    return MessagingConfig(
      exists: true,
      mediatedOnly: map['mediatedOnly'] == true,
      supportUids: rawUids is List
          ? List<String>.unmodifiable(
              rawUids
                  .map((value) => value?.toString().trim() ?? '')
                  .where((value) => value.isNotEmpty),
            )
          : const <String>[],
    );
  }

  factory MessagingConfig.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) return absent;
    return MessagingConfig.fromMap(doc.data() ?? <String, dynamic>{});
  }
}
