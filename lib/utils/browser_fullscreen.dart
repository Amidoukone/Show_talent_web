/// Le plein écran du navigateur, quand il existe.
///
/// Le portail se compile aussi pour Windows, macOS et Linux, où l'API
/// `document.requestFullscreen` n'a aucun sens. L'implémentation web n'est
/// donc chargée que sur le web ; ailleurs, le bouchon dit « non pris en
/// charge » et ne fait rien, et le mode plein écran applicatif du lecteur
/// suffit.
///
/// L'appelant ne doit jamais conditionner son affichage à cette API : elle
/// peut échouer silencieusement (refus du navigateur, page en iframe sans
/// l'autorisation `fullscreen`). Le plein écran applicatif reste la source de
/// vérité de la mise en page ; celui-ci ne fait que l'accompagner.
library;

export 'browser_fullscreen_stub.dart'
    if (dart.library.js_interop) 'browser_fullscreen_web.dart';
