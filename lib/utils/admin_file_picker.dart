/// Le choix d'un fichier local, quand le navigateur en offre un.
///
/// Même construction que `browser_fullscreen.dart` et
/// `admin_external_link.dart`, et pour la même raison : le portail se compile
/// aussi pour Windows, macOS et Linux, où il n'y a pas d'`<input type="file">`.
/// L'implémentation web n'est chargée que sur le web ; ailleurs le bouchon
/// répond « non pris en charge » et l'appelant le dit plutôt que d'ouvrir un
/// sélecteur qui n'existe pas.
///
/// Écrit avec `dart:js_interop` plutôt qu'avec un paquet, comme le plein écran
/// du navigateur : c'est un élément du DOM et une promesse, et une dépendance
/// de plus se paierait sur toutes les cibles, y compris celles qui n'ont pas
/// de navigateur.
library;

export 'admin_file_picker_stub.dart'
    if (dart.library.js_interop) 'admin_file_picker_web.dart';
