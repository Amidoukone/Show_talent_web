/// L'ouverture d'une adresse dans un nouvel onglet, quand il y en a un.
///
/// Même construction que `browser_fullscreen.dart`, et pour la même raison :
/// le portail se compile aussi pour Windows, macOS et Linux, où `window.open`
/// n'existe pas. L'implémentation web n'est chargée que sur le web ; ailleurs
/// le bouchon répond « non pris en charge » et l'appelant affiche l'adresse
/// plutôt que de prétendre l'avoir ouverte.
///
/// Écrit avec `dart:js_interop` plutôt qu'avec un paquet : c'est un seul appel
/// du DOM, et une dépendance de plus se paierait sur toutes les cibles, y
/// compris celles qui n'ont pas de navigateur.
library;

export 'admin_external_link_stub.dart'
    if (dart.library.js_interop) 'admin_external_link_web.dart';
