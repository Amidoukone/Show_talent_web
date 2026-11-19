/// Les références de fichiers que le portail accepte d'ouvrir.
///
/// Le dépôt mobile écrit les pièces justificatives sous la forme
/// `gs://<bucket>/<chemin>` et jamais sous celle d'un lien de téléchargement.
/// Ce n'est pas un détail de format : un lien Firebase Storage porte un jeton
/// dans son adresse, et ce jeton reste valable après le retrait de l'accès de
/// celui à qui le lien a été remis. Une référence `gs://`, elle, ne vaut rien
/// sans un jeton d'authentification présenté au moment de la lecture, donc
/// `storage.rules` la contrôle à chaque ouverture.
///
/// Miroir de `contractProofObjectPath()` dans
/// `functions/src/contract_status_proof.ts` : c'est le lecteur qui décide ce
/// qu'une référence désigne, jamais la chaîne elle-même.
library;

/// Une référence `gs://` décomposée.
class AdminStorageReference {
  const AdminStorageReference({required this.bucket, required this.objectPath});

  /// Nom du bucket, sans le schéma.
  final String bucket;

  /// Chemin de l'objet dans le bucket, sans barre oblique initiale.
  final String objectPath;

  /// La référence telle qu'elle vit sur le document.
  String get uri => 'gs://$bucket/$objectPath';

  /// Le nom de fichier seul, pour l'afficher sans étaler le chemin complet.
  String get fileName {
    final segments = objectPath.split('/');
    return segments.isEmpty ? objectPath : segments.last;
  }

  /// L'extension en minuscules, sans le point, ou une chaîne vide.
  String get extension {
    final name = fileName;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// Si le fichier s'affiche comme une image plutôt que comme un document.
  bool get looksLikeImage =>
      const <String>{'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(extension);

  /// Décompose une référence, ou rend `null` si elle n'en est pas une.
  ///
  /// Refuse volontairement tout ce qui n'est pas `gs://` — y compris une
  /// adresse `https://firebasestorage.googleapis.com/...` parfaitement
  /// fonctionnelle. Voir l'en-tête de ce fichier : un lien porteur de jeton
  /// survit au retrait de l'accès, et l'accepter ici reviendrait à laisser
  /// une pièce de dossier circuler hors de tout contrôle.
  static AdminStorageReference? parse(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'gs') return null;

    final bucket = uri.host.trim();
    if (bucket.isEmpty) return null;

    final path = Uri.decodeComponent(
      uri.path.startsWith('/') ? uri.path.substring(1) : uri.path,
    ).trim();
    if (path.isEmpty || path.endsWith('/')) return null;

    // Un segment vide (`a//b`) ne désigne rien : `Uri` le conserve tel quel,
    // et le SDK Storage le refuserait avec une erreur technique. Autant ne pas
    // tenter l'ouverture.
    //
    // Les segments `.` et `..` ne sont volontairement pas testés : `Uri.parse`
    // les résout déjà, une référence portant une authority étant normalisée à
    // l'analyse (`gs://b/a/../x` devient `gs://b/x`). Les chercher ici serait
    // du code mort, et le chemin résolu reste soumis à `storage.rules`, qui
    // n'ouvre que les dossiers qu'il nomme.
    if (path.split('/').any((segment) => segment.isEmpty)) {
      return null;
    }

    return AdminStorageReference(bucket: bucket, objectPath: path);
  }

  /// Si [raw] est une référence ouvrable par le portail.
  static bool isSupported(Object? raw) => parse(raw) != null;
}
