/// L'implémentation hors web : il n'y a pas de sélecteur de fichier.
library;

import 'admin_picked_file.dart';

export 'admin_picked_file.dart';

/// Toujours faux hors du web.
bool get adminFilePickerSupported => false;

/// Ne fait rien hors du web, et rend `null`.
///
/// L'appelant distingue ce `null` d'une annulation par
/// [adminFilePickerSupported] : « annulé » se tait, « non pris en charge » se
/// dit, et confondre les deux laisserait un opérateur devant un bouton qui ne
/// répond pas.
Future<AdminPickedFile?> pickAdminFile({required String accept}) async => null;
