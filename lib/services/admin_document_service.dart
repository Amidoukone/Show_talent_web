import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../utils/admin_picked_file.dart';
import '../utils/private_document_bytes_native.dart'
    if (dart.library.js_interop) '../utils/private_document_bytes_web.dart';
import '../utils/admin_storage_reference.dart';

/// Ce qu'une tentative d'ouverture de pièce a produit.
class AdminDocumentLink {
  const AdminDocumentLink._({
    required this.success,
    required this.message,
    this.bytes,
    this.reference,
  });

  const AdminDocumentLink.failure({required String message})
    : this._(success: false, message: message);

  const AdminDocumentLink.resolved({
    required Uint8List bytes,
    required AdminStorageReference reference,
  }) : this._(success: true, message: '', bytes: bytes, reference: reference);

  final bool success;

  /// Pourquoi la pièce n'a pas pu être ouverte, en clair pour l'opérateur.
  final String message;

  /// Contenu remis à l’aperçu après contrôle des droits.
  final Uint8List? bytes;

  /// La référence d'origine, décomposée.
  final AdminStorageReference? reference;
}

/// Un document déjà présent dans le stockage.
class AdminStoredDocument {
  const AdminStoredDocument({
    required this.objectPath,
    required this.name,
    this.sizeBytes,
    this.updatedAt,
  });

  /// Chemin complet de l'objet, tel que le stockage le nomme.
  final String objectPath;

  /// Nom de fichier seul.
  final String name;

  final int? sizeBytes;
  final DateTime? updatedAt;
}

/// Ce qu'un téléversement a produit.
class AdminUploadResult {
  const AdminUploadResult._({
    required this.success,
    required this.message,
    this.document,
  });

  const AdminUploadResult.failure({required String message})
    : this._(success: false, message: message);

  const AdminUploadResult.stored({
    required AdminStoredDocument document,
    required String message,
  }) : this._(success: true, message: message, document: document);

  final bool success;
  final String message;
  final AdminStoredDocument? document;
}

/// Lecture authentifiée des pièces privées et dépôt des accords.
class AdminDocumentService {
  AdminDocumentService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance,
      _visualQaMode = false;

  AdminDocumentService.visualQa() : _storage = null, _visualQaMode = true;

  final FirebaseStorage? _storage;
  final bool _visualQaMode;

  /// Charge les octets depuis le bucket configuré pour cet environnement.
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

    if (reference.bucket != _storage!.bucket) {
      return const AdminDocumentLink.failure(
        message: 'Bucket de stockage inattendu.',
      );
    }
    return _read(reference);
  }

  /// Résout un chemin d'objet que **ce code a fabriqué**.
  ///
  /// Séparé de [resolve] à dessein. [resolve] n'accepte qu'une référence
  /// `gs://` parce qu'elle vient d'un document écrit par un utilisateur, et ce
  /// refus est une propriété de sécurité qu'il ne faut pas diluer. Ici le
  /// chemin est construit par le portail — `clubAgreements/{clubUid}/…` — donc
  /// il n'y a rien à valider, et exiger un `gs://` obligerait à recomposer une
  /// chaîne pour la redécomposer juste après.
  Future<AdminDocumentLink> resolvePath(String objectPath) async {
    final normalized = objectPath.trim();
    if (normalized.isEmpty) {
      return const AdminDocumentLink.failure(
        message: 'Aucun document désigné.',
      );
    }

    if (_visualQaMode) {
      return const AdminDocumentLink.failure(
        message: 'Ouverture indisponible pendant la revue locale.',
      );
    }

    final reference = AdminStorageReference(
      bucket: _storage!.bucket,
      objectPath: normalized,
    );

    return _read(reference);
  }

  Future<AdminDocumentLink> _read(AdminStorageReference reference) async {
    try {
      final file = _storage!.ref(reference.objectPath);
      // readPrivateDocumentBytes sur le web appelle le SDK JS modulaire par
      // interop brut (voir private_document_bytes_web.dart) : une promesse
      // JS qui ne se resout ni ne rejette jamais laisserait cet appel
      // suspendu pour toujours, sans la moindre erreur a attraper -- le
      // bouton resterait discretement desactive, sans aucun message. Cette
      // limite transforme ce silence en un echec explicite et reessayable.
      final bytes = await readPrivateDocumentBytes(
        file,
        adminAgreementMaxBytes,
      ).timeout(const Duration(seconds: 20));
      if (bytes == null ||
          bytes.isEmpty ||
          bytes.length > adminAgreementMaxBytes) {
        return const AdminDocumentLink.failure(
          message: 'Document vide ou supérieur à 8 Mo.',
        );
      }
      return AdminDocumentLink.resolved(bytes: bytes, reference: reference);
    } on TimeoutException {
      return const AdminDocumentLink.failure(
        message:
            'Le document n’a pas répondu à temps. Vérifiez votre connexion '
            'puis réessayez.',
      );
    } on FirebaseException catch (error) {
      return AdminDocumentLink.failure(message: _describe(error, reference));
    } catch (_) {
      return const AdminDocumentLink.failure(
        message:
            'Ouverture du document impossible pour le moment. Vérifiez votre '
            'connexion puis réessayez.',
      );
    }
  }

  /// Le dossier des accords signés d'un club.
  ///
  /// `storage.rules` réserve `clubAgreements/{clubUid}/` à l'administration
  /// **dans les deux sens** : le club n'y accède pas, volontairement, parce
  /// qu'un accord est un acte signé entre deux parties et non une pièce que
  /// son propriétaire dépose. Il en a son exemplaire, et l'application mobile
  /// n'en parle à personne.
  static String clubAgreementFolder(String clubUid) =>
      'clubAgreements/${clubUid.trim()}';

  /// Les accords déjà déposés pour ce club, du plus récent au plus ancien.
  ///
  /// Lus et non déduits de la seule référence portée par l'habilitation : sans
  /// cette liste, le téléversement serait une écriture que personne ne peut
  /// relire, ce qui est exactement le défaut que ce lot corrige ailleurs.
  Future<List<AdminStoredDocument>> listClubAgreements(String clubUid) {
    final uid = clubUid.trim();
    if (uid.isEmpty) return Future.value(const <AdminStoredDocument>[]);
    return _listFolder(clubAgreementFolder(uid));
  }

  /// Liste un dossier de pièces, du plus récemment modifié au plus ancien.
  ///
  /// Partagé par [listClubAgreements] et [listGuardianConsentEvidence] : même
  /// dossier déterministe à parcourir, même coût borné par pièce (une
  /// métadonnée par fichier), même repli silencieux quand elle manque.
  Future<List<AdminStoredDocument>> _listFolder(String folder) async {
    if (_visualQaMode) {
      return const <AdminStoredDocument>[];
    }

    final listing = await _storage!.ref(folder).listAll();
    final documents = await Future.wait(
      listing.items.map((item) async {
        try {
          final metadata = await item.getMetadata();
          return AdminStoredDocument(
            objectPath: item.fullPath,
            name: item.name,
            sizeBytes: metadata.size,
            updatedAt: metadata.updated,
          );
        } catch (_) {
          return AdminStoredDocument(
            objectPath: item.fullPath,
            name: item.name,
          );
        }
      }),
    );

    documents.sort((a, b) {
      final left = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return documents;
  }

  /// Dépose l'accord signé d'un club.
  ///
  /// **Le dépôt n'est pas transactionnel avec l'habilitation**, et ne peut pas
  /// l'être : l'un est une écriture de stockage, l'autre un callable. L'ordre
  /// retenu est de déposer puis d'accorder — un fichier déposé sans
  /// habilitation est un document inerte dans un dossier que seule
  /// l'administration lit, alors qu'une habilitation accordée sans son
  /// document laisse une référence qui ne pointe sur rien.
  ///
  /// Le nom de l'objet est fabriqué et non repris du poste de travail, et un
  /// second dépôt n'écrase jamais le premier : voir
  /// [adminAgreementObjectName].
  Future<AdminUploadResult> uploadClubAgreement({
    required String clubUid,
    required String agreementRef,
    required AdminPickedFile file,
  }) async {
    final uid = clubUid.trim();
    if (uid.isEmpty) {
      return const AdminUploadResult.failure(
        message: 'Aucun club désigné pour ce dépôt.',
      );
    }

    final rejection = describeAgreementRejection(file);
    if (rejection != null) {
      return AdminUploadResult.failure(message: rejection);
    }

    if (_visualQaMode) {
      return const AdminUploadResult.failure(
        message: 'Dépôt indisponible pendant la revue locale.',
      );
    }

    final objectName = adminAgreementObjectName(
      agreementRef: agreementRef,
      extension: file.extension,
    );
    final objectPath = '${clubAgreementFolder(uid)}/$objectName';

    try {
      await _storage!
          .ref(objectPath)
          .putData(
            file.bytes,
            SettableMetadata(
              contentType: adminAgreementContentType(file.extension),
              cacheControl: 'private, no-store',
              // Le nom d'origine est conservé en métadonnée plutôt que dans le
              // chemin : il renseigne sans pouvoir changer où l'objet atterrit.
              customMetadata: <String, String>{'originalName': file.name},
            ),
          );

      return AdminUploadResult.stored(
        document: AdminStoredDocument(
          objectPath: objectPath,
          name: objectName,
          sizeBytes: file.sizeBytes,
          updatedAt: DateTime.now(),
        ),
        message: 'Accord déposé : $objectName.',
      );
    } on FirebaseException catch (error) {
      if (error.code == 'unauthorized' || error.code == 'permission-denied') {
        return const AdminUploadResult.failure(
          message:
              'Dépôt refusé par le stockage. Votre session n’a plus les '
              'droits d’administration : reconnectez-vous.',
        );
      }
      return AdminUploadResult.failure(
        message: 'Dépôt de l’accord impossible (${error.code}).',
      );
    } catch (_) {
      return const AdminUploadResult.failure(
        message:
            'Dépôt de l’accord impossible pour le moment. Vérifiez votre '
            'connexion puis réessayez.',
      );
    }
  }

  /// Le dossier de la preuve d'un accord parental.
  ///
  /// `storage.rules` du dépôt mobile réserve
  /// `identityDocuments/{uid}/guardianConsent/` à l'administration dans les
  /// deux sens — un mineur ne gère pas son propre compte de manière autonome,
  /// et c'est l'administration qui recueille l'accord du représentant légal,
  /// jamais le mineur. Même modèle que [clubAgreementFolder] ci-dessus.
  ///
  /// **La référence n'est volontairement pas écrite dans
  /// `guardianConsent.evidenceReference`** : ce champ est borné à 120
  /// caractères côté callable (`functions/src/minor_consent.ts`), et une
  /// référence `gs://` complète — bucket, `identityDocuments/{uid}/`,
  /// horodatage — le dépasse largement pour un UID Firebase standard. La
  /// pièce se retrouve donc comme un accord de club : listée depuis ce
  /// dossier déterministe, jamais par une référence stockée sur le document.
  static String guardianConsentFolder(String uid) =>
      'identityDocuments/${uid.trim()}/guardianConsent';

  /// Les preuves déjà déposées pour ce compte, de la plus récente à la plus
  /// ancienne.
  Future<List<AdminStoredDocument>> listGuardianConsentEvidence(String uid) {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) return Future.value(const <AdminStoredDocument>[]);
    return _listFolder(guardianConsentFolder(trimmed));
  }

  /// Dépose la preuve d'un accord parental.
  ///
  /// Le nom de l'objet est fabriqué, jamais repris du poste de travail — voir
  /// [guardianConsentObjectName] — et c'est la seule chose que `storage.rules`
  /// contrôle ici : contrairement à `clubAgreements/`, le nom lui-même est
  /// validé côté serveur, donc le gabarit produit doit lui correspondre au
  /// caractère près.
  Future<AdminUploadResult> uploadGuardianConsentEvidence({
    required String uid,
    required AdminPickedFile file,
  }) async {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) {
      return const AdminUploadResult.failure(
        message: 'Aucun compte désigné pour ce dépôt.',
      );
    }

    final rejection = describeAgreementRejection(file);
    if (rejection != null) {
      return AdminUploadResult.failure(message: rejection);
    }

    if (_visualQaMode) {
      return const AdminUploadResult.failure(
        message: 'Dépôt indisponible pendant la revue locale.',
      );
    }

    final objectName = guardianConsentObjectName(extension: file.extension);
    final objectPath = '${guardianConsentFolder(trimmed)}/$objectName';

    try {
      await _storage!
          .ref(objectPath)
          .putData(
            file.bytes,
            SettableMetadata(
              contentType: adminAgreementContentType(file.extension),
              cacheControl: 'private, no-store',
              customMetadata: <String, String>{'originalName': file.name},
            ),
          );

      return AdminUploadResult.stored(
        document: AdminStoredDocument(
          objectPath: objectPath,
          name: objectName,
          sizeBytes: file.sizeBytes,
          updatedAt: DateTime.now(),
        ),
        message: 'Justificatif déposé : $objectName.',
      );
    } on FirebaseException catch (error) {
      if (error.code == 'unauthorized' || error.code == 'permission-denied') {
        return const AdminUploadResult.failure(
          message:
              'Dépôt refusé par le stockage. Votre session n’a plus les '
              'droits d’administration : reconnectez-vous.',
        );
      }
      return AdminUploadResult.failure(
        message: 'Dépôt du justificatif impossible (${error.code}).',
      );
    } catch (_) {
      return const AdminUploadResult.failure(
        message:
            'Dépôt du justificatif impossible pour le moment. Vérifiez '
            'votre connexion puis réessayez.',
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
