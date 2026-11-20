import 'dart:js_interop';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

@JS('firebase_core.getApp')
external JSObject _app(String name);

@JS('firebase_storage.getStorage')
external JSObject _storage(JSObject app, String bucket);

@JS('firebase_storage.ref')
external JSObject _ref(JSObject storage, String path);

@JS('firebase_storage.getBytes')
external _Download _getBytes(JSObject reference, int limit);

extension type _Download._(JSObject _) implements JSObject {
  @JS('catch')
  external JSPromise<JSArrayBuffer?> onError(JSFunction callback);
}
extension type _StorageError._(JSObject _) implements JSObject {
  external String? get code;
}

// FlutterFire web 3.11.13 implements Reference.getData via getDownloadURL.
// Use the same initialized JS SDK instance, including Auth, App Check and emulators.
Future<Uint8List?> readPrivateDocumentBytes(
  Reference file,
  int maxBytes,
) async {
  final sdk = _storage(_app(file.storage.app.name), file.storage.bucket);
  FirebaseException? failure;
  final download = _getBytes(_ref(sdk, file.fullPath), maxBytes + 1);
  final buffer = await download
      .onError(
        ((JSObject error) {
          final code = _StorageError._(error).code ?? 'unknown';
          failure = FirebaseException(
            plugin: 'firebase_storage',
            code: code.replaceFirst('storage/', ''),
          );
          return null;
        }).toJS,
      )
      .toDart;
  if (failure != null) throw failure!;
  return buffer?.toDart.asUint8List();
}
