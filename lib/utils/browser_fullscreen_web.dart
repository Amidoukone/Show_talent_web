/// L'implémentation web du plein écran navigateur.
///
/// Écrite directement avec `dart:js_interop` plutôt qu'avec un paquet : il
/// s'agit de trois appels du DOM, et une dépendance de plus se paierait sur
/// toutes les cibles, y compris celles qui n'ont pas de navigateur.
library;

import 'dart:js_interop';

@JS('document')
external _JsDocument get _document;

extension type _JsDocument._(JSObject _) implements JSObject {
  external _JsElement? get documentElement;
  external JSObject? get fullscreenElement;
  external JSPromise<JSAny?> exitFullscreen();
  external void addEventListener(String type, JSFunction callback);
  external void removeEventListener(String type, JSFunction callback);
}

extension type _JsElement._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> requestFullscreen();
}

bool get browserFullscreenSupported => true;

bool get browserFullscreenActive => _document.fullscreenElement != null;

/// Entre ou sort du plein écran du navigateur.
///
/// N'échoue jamais bruyamment : un navigateur refuse le plein écran quand la
/// demande ne vient pas d'un geste utilisateur, ou quand la page est dans une
/// iframe sans l'autorisation `fullscreen`. Dans ces cas l'opérateur garde le
/// plein écran applicatif, ce qui est déjà l'essentiel.
Future<void> setBrowserFullscreen(bool enabled) async {
  try {
    if (enabled) {
      final element = _document.documentElement;
      if (element == null) {
        return;
      }
      await element.requestFullscreen().toDart;
      return;
    }

    if (browserFullscreenActive) {
      await _document.exitFullscreen().toDart;
    }
  } catch (_) {
    // Voir ci-dessus : un refus du navigateur n'est pas une erreur du portail.
  }
}

/// Écoute les sorties de plein écran décidées par l'utilisateur — Échap ou
/// F11 — pour que la mise en page du lecteur ne reste pas en plein écran
/// alors que le navigateur en est déjà sorti.
void Function() listenBrowserFullscreen(void Function(bool active) onChanged) {
  void handle(JSAny? _) => onChanged(browserFullscreenActive);

  final callback = handle.toJS;
  _document.addEventListener('fullscreenchange', callback);
  return () => _document.removeEventListener('fullscreenchange', callback);
}
