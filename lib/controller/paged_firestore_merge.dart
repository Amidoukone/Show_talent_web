/// Fusionne une première page temps réel et des pages supplémentaires
/// chargées par curseur, en dédoublonnant par identifiant.
///
/// Partagé par [OffreController] et [ClubLinkController] (voir leurs
/// commentaires d'origine) : les deux seuls contrôleurs du portail à suivre
/// EXACTEMENT ce schéma — une première page qui reste un flux temps réel, des
/// pages supplémentaires statiques ajoutées par `startAfterDocument`, et les
/// deux fenêtres fusionnées par identifiant (la plus fraîche l'emporte).
/// `ContractProofController` ne le suit volontairement pas : l'absence d'un
/// index composite côté mobile l'oblige à un flux unique à limite
/// croissante, un compromis différent, pas un oubli à corriger ici.
///
/// Avant cette classe, la même boucle de fusion (deux `Map` par identifiant,
/// triées, assignées) vivait recopiée dans chaque contrôleur : un correctif à
/// cette mécanique — par exemple un bug de bord sur `hasMore` — devait être
/// retrouvé et appliqué séparément dans chacun.
///
/// Générique sur le type du curseur ([C], typiquement
/// `DocumentSnapshot<Map<String, dynamic>>`) plutôt que de dépendre de
/// `cloud_firestore` directement : `DocumentSnapshot` et
/// `QueryDocumentSnapshot` sont des classes scellées que rien, pas même un
/// bouchon de test, ne peut implémenter hors du paquet qui les déclare. Cette
/// classe n'a d'ailleurs besoin de rien savoir d'un curseur au-delà de le
/// conserver et de le rendre — l'appelant reste seul à savoir comment en
/// extraire un depuis une page de documents.
class PagedFirestoreMerge<T, C> {
  PagedFirestoreMerge({required this.idOf, required this.compare});

  /// L'identifiant qui dédoublonne deux occurrences d'un même document.
  final String Function(T item) idOf;

  /// L'ordre d'affichage de la liste fusionnée.
  final Comparator<T> compare;

  List<T> _firstPage = <T>[];
  List<T> _extraPages = <T>[];
  C? _lastCursor;

  /// Le curseur du dernier document chargé, toutes pages confondues.
  C? get cursor => _lastCursor;

  /// Repart de zéro : nouvelle session, flux relancé.
  void reset() {
    _firstPage = <T>[];
    _extraPages = <T>[];
    _lastCursor = null;
  }

  /// Remplace la première page (ce que le flux temps réel vient d'émettre) et
  /// rend la liste fusionnée, triée.
  ///
  /// [lastCursor] est `null` quand la page reçue est vide : il n'y a alors
  /// rien de plus récent à retenir, et le curseur précédent reste valide.
  List<T> applyFirstPage(List<T> items, C? lastCursor) {
    _firstPage = items;
    if (lastCursor != null) {
      _lastCursor = lastCursor;
    }
    return _merge();
  }

  /// Ajoute un lot chargé par curseur (« charger plus ») et rend la liste
  /// fusionnée, triée.
  List<T> appendPage(List<T> items, C? lastCursor) {
    _extraPages = <T>[..._extraPages, ...items];
    if (lastCursor != null) {
      _lastCursor = lastCursor;
    }
    return _merge();
  }

  /// Retire de la fenêtre chargée tout élément dont l'identifiant satisfait
  /// [shouldRemove], et rend la liste fusionnée restante.
  ///
  /// Pour un retrait local immédiat après une action réussie (clôture,
  /// suppression) : le flux temps réel l'aurait retiré de lui-même pour la
  /// première page, mais pas des pages supplémentaires, qui sont statiques.
  List<T> removeWhere(bool Function(String id) shouldRemove) {
    _firstPage = _firstPage.where((item) => !shouldRemove(idOf(item))).toList();
    _extraPages = _extraPages
        .where((item) => !shouldRemove(idOf(item)))
        .toList();
    return _merge();
  }

  List<T> _merge() {
    final byId = <String, T>{};
    for (final item in _extraPages) {
      byId[idOf(item)] = item;
    }
    for (final item in _firstPage) {
      byId[idOf(item)] = item;
    }
    final merged = byId.values.toList()..sort(compare);
    return merged;
  }
}
