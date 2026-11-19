/// L'implémentation web du choix d'un fichier local.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'admin_picked_file.dart';

export 'admin_picked_file.dart';

@JS('document')
external _JsDocument get _document;

extension type _JsDocument._(JSObject _) implements JSObject {
  external _JsInputElement createElement(String tagName);
  external _JsElement? get body;
}

extension type _JsElement._(JSObject _) implements JSObject {
  external void appendChild(JSObject child);
  external void removeChild(JSObject child);
}

extension type _JsInputElement._(JSObject _) implements JSObject {
  external set type(String value);
  external set accept(String value);
  external set multiple(bool value);
  external set hidden(bool value);
  external _JsFileList? get files;
  external void click();
  external void addEventListener(String type, JSFunction callback);
  external void removeEventListener(String type, JSFunction callback);
}

extension type _JsFileList._(JSObject _) implements JSObject {
  external int get length;
  external _JsFile? item(int index);
}

extension type _JsFile._(JSObject _) implements JSObject {
  external String get name;
  external int get size;
  external String get type;

  /// `File.arrayBuffer()` plutôt que `FileReader` : une promesse contre trois
  /// écouteurs d'événements, pour le même résultat, et c'est de loin le moins
  /// de code interop à maintenir. Disponible sur tous les navigateurs encore
  /// servis par ce portail.
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

bool get adminFilePickerSupported => true;

/// Ouvre le sélecteur de fichier et rend ce que l'opérateur a choisi.
///
/// [accept] est passé tel quel à l'attribut `accept` de l'élément : c'est un
/// **filtre d'affichage**, pas un contrôle. Un navigateur laisse choisir
/// « Tous les fichiers », et la vérification qui compte est
/// [describeAgreementRejection], côté Dart et testée.
///
/// Rend `null` quand l'opérateur annule. L'élément est attaché au document le
/// temps du clic — Safari ignore `click()` sur un élément détaché — puis
/// retiré, écouteurs compris, dans tous les cas.
Future<AdminPickedFile?> pickAdminFile({required String accept}) async {
  final input = _document.createElement('input');
  input.type = 'file';
  input.accept = accept;
  input.multiple = false;
  input.hidden = true;

  final completer = Completer<AdminPickedFile?>();
  final body = _document.body;
  JSFunction? onChange;
  JSFunction? onCancel;

  void cleanUp() {
    if (onChange != null) input.removeEventListener('change', onChange);
    if (onCancel != null) input.removeEventListener('cancel', onCancel);
    try {
      body?.removeChild(input);
    } catch (_) {
      // L'élément a déjà quitté le document : rien à défaire.
    }
  }

  Future<void> handleChange(JSAny? _) async {
    try {
      final files = input.files;
      final file = (files == null || files.length == 0) ? null : files.item(0);
      if (file == null) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final buffer = await file.arrayBuffer().toDart;
      if (!completer.isCompleted) {
        completer.complete(
          AdminPickedFile(
            name: file.name,
            bytes: Uint8List.view(buffer.toDart),
            mimeType: file.type.isEmpty ? null : file.type,
          ),
        );
      }
    } catch (error) {
      if (!completer.isCompleted) completer.completeError(error);
    } finally {
      cleanUp();
    }
  }

  void handleCancel(JSAny? _) {
    if (!completer.isCompleted) completer.complete(null);
    cleanUp();
  }

  onChange = ((JSAny? event) => handleChange(event)).toJS;
  onCancel = handleCancel.toJS;
  input.addEventListener('change', onChange);
  // `cancel` n'existe pas sur tous les navigateurs. Quand il manque, une
  // annulation ne résout simplement jamais cette promesse — d'où le soin, chez
  // l'appelant, de ne pas bloquer l'écran en attendant : le bouton reste
  // cliquable, et un second choix remplace le premier.
  input.addEventListener('cancel', onCancel);

  body?.appendChild(input);
  input.click();

  return completer.future;
}
