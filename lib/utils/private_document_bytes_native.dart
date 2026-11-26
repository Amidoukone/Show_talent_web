import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

// `getData` jette au-dela de la limite donnee au lieu de rendre un fichier
// tronque : demander `maxBytes` pile ferait echouer un fichier d'exactement
// `maxBytes + 1` octet avec une erreur technique generique, plutot que le
// message clair ("superieur a 8 Mo") que `admin_document_service.dart`
// produit apres coup sur la taille lue. Meme marge qu'en version web
// (`private_document_bytes_web.dart`), pour que les deux plateformes
// rendent le meme message sur ce fichier limite.
Future<Uint8List?> readPrivateDocumentBytes(Reference file, int maxBytes) =>
    file.getData(maxBytes + 1);
