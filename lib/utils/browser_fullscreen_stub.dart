/// L'implémentation hors web : il n'y a pas de navigateur à mettre en plein
/// écran, et le lecteur doit continuer de fonctionner exactement pareil.
library;

/// Toujours faux hors du web.
bool get browserFullscreenSupported => false;

/// Toujours faux hors du web.
bool get browserFullscreenActive => false;

/// Ne fait rien hors du web.
Future<void> setBrowserFullscreen(bool enabled) async {}

/// N'écoute rien hors du web, et rend une fonction d'arrêt inoffensive.
void Function() listenBrowserFullscreen(void Function(bool active) onChanged) {
  return () {};
}
