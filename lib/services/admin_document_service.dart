import 'package:firebase_storage/firebase_storage.dart';

import '../utils/admin_storage_reference.dart';

/// Ce qu'une tentative d'ouverture de pièce a produit.
class AdminDocumentLink {
  const AdminDocumentLink._({
    required this.success,
    required this.message,
    this.url,
    this.reference,
  });

  const AdminDocumentLink.failure({required String message})
    : this._(success: false, message: message);

  const AdminDocumentLink.resolved({
    required String url,
    required AdminStorageReference reference,
  }) : this._(success: true, message: '', url: url, reference: reference);

  final bool success;

  /// Pourquoi la pièce n'a pas pu être ouverte, en clair pour l'opérateur.
  final String message;

  /// Adresse de lecture, valable pour la session en cours.
  final String? url;

  /// La référence d'origine, décomposée.
  final AdminStorageReference? reference;
}

/// L'ouverture des pièces justificatives déposées par les utilisateurs.
///
/// Le portail n'ouvrait jusqu'ici aucun document : la fiche de revue se
/// contentait d'annoncer « Présent » ou « Absent » pour le CV et la photo de
/// passeport. Examiner une pièce de statut contractuel demande de la lire,
/// donc cette plomberie existe, une fois, pour toutes les pièces.
///
/// **Aucune URL signée n'est fabriquée ici, et c'est le point important.** La
/// référence `gs://` est convertie en référence Storage, et le SDK présente le
/// jeton d'authentification de l'opérateur à chaque lecture :
/// `storage.rules` contrôle donc l'accès au moment où le fichier est servi.
/// Un lien signé, lui, resterait ouvert après la révocation du claim admin —
/// voir `canReadContractProof(uid)` dans `storage.rules`, qui exige
/// `isAdminOperator()` et rien de moins.
///
/// L'adresse obtenue est volontairement non mémorisée : elle se redemande à
/// chaque ouverture. Un opérateur dont les droits viennent d'être retirés ne
/// doit pas pouvoir rejouer une adresse obtenue cinq minutes plus tôt.
class AdminDocumentService {
  AdminDocumentService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance,
      _visualQaMode = false;

  AdminDocumentService.visualQa() : _storage = null, _visualQaMode = true;

  final FirebaseStorage? _storage;
  final bool _visualQaMode;

  /// Résout une référence `gs://` en adresse de lecture.
  Future<AdminDocumentLink> resolve(Object? rawReference) async {
    final reference = AdminStorageReference.parse(rawReference);
    if (reference == null) {
      return const AdminDocumentLink.failure(
        message:
            'Cette pièce ne porte pas une référence de stockage exploitable. '
            'Signalez-la plutôt que de rendre un verdict dessus.',
      );
    }

    if (_visualQaMode) {
      return const AdminDocumentLink.failure(
        message: 'Ouverture indisponible pendant la revue locale.',
      );
    }

    try {
      final url = await _storage!.refFromURL(reference.uri).getDownloadURL();
      return AdminDocumentLink.resolved(url: url, reference: reference);
    } on FirebaseException catch (error) {
      return AdminDocumentLink.failure(message: _describe(error, reference));
    } catch (_) {
      return const AdminDocumentLink.failure(
        message:
            'Ouverture de la pièce impossible pour le moment. Vérifiez votre '
            'connexion puis réessayez.',
      );
    }
  }

  /// Traduit un code Storage en phrase qui dit quoi faire.
  ///
  /// `object-not-found` mérite son propre message : une pièce détruite par la
  /// purge programmée n'est pas une panne, et l'opérateur n'a rien à
  /// réessayer. Les termes de conservation vivent dans
  /// `functions/src/contract_status_proof.ts` — vingt-quatre mois après un
  /// examen favorable, quatre-vingt-dix jours après un refus.
  String _describe(FirebaseException error, AdminStorageReference reference) {
    switch (error.code) {
      case 'object-not-found':
        return 'Le fichier « ${reference.fileName} » n’est plus dans le '
            'stockage. Une pièce déjà examinée peut avoir été détruite au '
            'terme de sa conservation.';
      case 'unauthorized':
      case 'permission-denied':
        return 'Lecture refusée par le stockage. Votre session n’a plus les '
            'droits d’administration : reconnectez-vous.';
      case 'retry-limit-exceeded':
      case 'unavailable':
        return 'Le stockage n’a pas répondu. Réessayez dans un instant.';
      default:
        return 'Ouverture de la pièce impossible (${error.code}).';
    }
  }
}
