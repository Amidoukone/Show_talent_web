/// L'implémentation web de l'ouverture d'onglet.
library;

import 'dart:js_interop';

@JS('window')
external _JsWindow get _window;

extension type _JsWindow._(JSObject _) implements JSObject {
  external JSObject? open(String url, String target, String features);
}

bool get adminExternalLinkSupported => true;

/// Ouvre [url] dans un nouvel onglet, et dit si le navigateur a obéi.
///
/// `noopener,noreferrer` n'est pas une précaution de principe : sans
/// `noopener`, la page ouverte reçoit une poignée sur celle du portail par
/// `window.opener` et peut la faire naviguer ailleurs. Les pièces examinées
/// ici viennent d'un dépôt d'utilisateur, donc d'une source non maîtrisée.
///
/// Rend `false` quand le navigateur refuse — c'est le cas d'un bloqueur de
/// fenêtres surgissantes quand l'appel ne descend pas d'un geste de
/// l'utilisateur. L'appelant propose alors l'adresse à la main plutôt que de
/// laisser l'opérateur devant un écran qui n'a rien fait.
bool openAdminExternalLink(String url) {
  final target = url.trim();
  if (target.isEmpty) return false;

  try {
    return _window.open(target, '_blank', 'noopener,noreferrer') != null;
  } catch (_) {
    return false;
  }
}
