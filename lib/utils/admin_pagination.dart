/// Une page d'une liste déjà filtrée, et les indices qui l'ont produite.
///
/// Même calcul que les 7 écrans de gestion recopiaient chacun à l'identique
/// avant ce fichier (pagination d'une liste locale, pas d'une requête
/// Firestore) : un seul endroit à corriger plutôt que sept.
class AdminPageWindow<T> {
  const AdminPageWindow({
    required this.items,
    required this.totalPages,
    required this.safePage,
    required this.startIndex,
    required this.endIndex,
  });

  /// Les éléments de [filtered] à afficher sur [safePage].
  final List<T> items;

  /// Toujours au moins 1, même pour une liste vide : évite un
  /// `clamp(0, -1)` (qui lève) au premier calcul de [safePage].
  final int totalPages;

  /// [currentPage] ramené dans les bornes valides — utile après une
  /// suppression qui réduit le nombre de pages sous la page affichée.
  final int safePage;
  final int startIndex;
  final int endIndex;
}

AdminPageWindow<T> paginateAdminList<T>({
  required List<T> filtered,
  required int currentPage,
  required int rowsPerPage,
}) {
  final totalPagesRaw = (filtered.length / rowsPerPage).ceil();
  final totalPages = totalPagesRaw < 1 ? 1 : totalPagesRaw;
  final safePage = currentPage >= totalPages
      ? totalPages - 1
      : currentPage.clamp(0, totalPages - 1);
  final startIndex = safePage * rowsPerPage;
  final endIndex = (startIndex + rowsPerPage).clamp(0, filtered.length);

  return AdminPageWindow<T>(
    items: filtered.sublist(startIndex, endIndex),
    totalPages: totalPages,
    safePage: safePage,
    startIndex: startIndex,
    endIndex: endIndex,
  );
}
