import 'dart:typed_data';

/// Un fichier choisi par l'opérateur, en mémoire.
///
/// Déclaré hors des deux implémentations du sélecteur pour que le bouchon et
/// la version web rendent exactement le même type : sans cela l'appelant
/// devrait connaître laquelle est chargée.
class AdminPickedFile {
  const AdminPickedFile({
    required this.name,
    required this.bytes,
    this.mimeType,
  });

  /// Nom du fichier tel que le système l'a donné.
  ///
  /// Jamais employé comme nom de stockage : voir
  /// [adminAgreementObjectName], qui en fabrique un à partir de la seule
  /// extension. Un nom de fichier venu d'un poste de travail peut porter des
  /// espaces, des accents et des barres obliques.
  final String name;

  final Uint8List bytes;

  /// Type MIME annoncé par le navigateur, quand il en annonce un.
  final String? mimeType;

  int get sizeBytes => bytes.lengthInBytes;

  /// L'extension en minuscules, sans le point, ou une chaîne vide.
  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}

/// Les formats acceptés pour un accord signé.
///
/// Les mêmes que pour une pièce de statut contractuel : un accord arrive en
/// PDF dans la quasi-totalité des cas, et en photo quand il a été signé sur
/// papier et photographié.
const Set<String> adminAgreementExtensions = <String>{
  'pdf',
  'jpg',
  'jpeg',
  'png',
};

/// Taille maximale d'un accord téléversé.
///
/// Huit mébioctets, comme les pièces d'identité dans `storage.rules`. Un
/// accord de quelques pages scanné y tient largement ; au-delà, c'est un
/// scan non compressé, et le refuser ici évite un téléversement qui échouerait
/// plus loin ou encombrerait le stockage pour rien.
const int adminAgreementMaxBytes = 8 * 1024 * 1024;

/// Pourquoi ce fichier ne peut pas servir d'accord, ou `null`.
///
/// **`storage.rules` ne valide rien sur `clubAgreements/`** — la règle est
/// `allow read, write: if isAdminOperator()`, sans contrôle de nom, de taille
/// ni de type, contrairement aux pièces d'identité. Ce contrôle-ci est donc le
/// seul qui existe, et c'est pour cela qu'il vit dans une fonction pure et
/// testée plutôt que dans le dialogue.
String? describeAgreementRejection(AdminPickedFile file) {
  if (file.sizeBytes == 0) {
    return 'Ce fichier est vide.';
  }
  if (file.sizeBytes > adminAgreementMaxBytes) {
    final megabytes = (file.sizeBytes / (1024 * 1024)).toStringAsFixed(1);
    return 'Ce fichier pèse $megabytes Mo, au-delà des 8 Mo acceptés. '
        'Compressez le scan avant de le déposer.';
  }
  if (!adminAgreementExtensions.contains(file.extension)) {
    return 'Format non accepté. Déposez un PDF, ou une photo JPG ou PNG.';
  }
  return null;
}

/// Le nom sous lequel un accord est stocké.
///
/// Fabriqué, jamais repris du poste de travail : un nom de fichier local peut
/// porter des espaces, des accents, voire des barres obliques qui changeraient
/// le chemin de stockage. Il garde la référence de l'accord pour qu'un
/// opérateur retrouve le bon document des mois plus tard, et un horodatage
/// pour qu'un second dépôt n'écrase pas le premier — un accord signé est un
/// acte, et un acte ne se remplace pas en silence.
String adminAgreementObjectName({
  required String agreementRef,
  required String extension,
  DateTime? now,
}) {
  final slug = agreementRef
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final reference = slug.isEmpty ? 'accord' : slug;
  final stamp = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
  final suffix = extension.isEmpty ? 'pdf' : extension;

  return 'agreement_${reference}_$stamp.$suffix';
}

/// Le nom sous lequel la preuve d'un accord parental est stockée.
///
/// À la différence d'[adminAgreementObjectName], aucune référence libre n'y
/// entre : `storage.rules` du dépôt mobile valide le nom de fichier lui-même
/// sur `identityDocuments/{uid}/guardianConsent/` —
/// `^guardian_consent_[0-9]+\.(pdf|jpg|jpeg|png)\$` — là où `clubAgreements/`
/// n'impose aucun nom. Un seul segment, l'horodatage, pour la même raison
/// qu'un accord de club : un second dépôt ne doit pas écraser le premier.
String guardianConsentObjectName({required String extension, DateTime? now}) {
  final stamp = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
  final suffix = extension.isEmpty ? 'pdf' : extension;
  return 'guardian_consent_$stamp.$suffix';
}

/// Le type MIME à enregistrer avec l'objet.
///
/// Déduit de l'extension plutôt que repris du navigateur : un navigateur
/// annonce parfois une chaîne vide, et un objet servi sans type se télécharge
/// au lieu de s'afficher dans l'onglet.
String adminAgreementContentType(String extension) {
  switch (extension) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    default:
      return 'application/octet-stream';
  }
}
