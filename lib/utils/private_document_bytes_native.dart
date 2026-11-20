import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

Future<Uint8List?> readPrivateDocumentBytes(Reference file, int maxBytes) =>
    file.getData(maxBytes);
