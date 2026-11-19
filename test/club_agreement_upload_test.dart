// Le televersement de l'accord signe d'un club.
//
// L'habilitation portait la reference de l'accord, mais le document lui-meme
// n'avait aucun chemin d'arrivee : `storage.rules` prevoyait
// `clubAgreements/{clubUid}/{fileName}` et personne ne pouvait rien y
// deposer.
//
// Le choix du fichier passe par le DOM et n'est pas exerçable ici. Tout ce qui
// decide -- la validation, le nom de l'objet, le type MIME -- vit donc dans
// des fonctions pures, et c'est precisement ce que ces tests verifient :
// `storage.rules` ne controle NI le nom, NI la taille, NI le type sur ce
// dossier, donc ces fonctions sont le seul garde-fou qui existe.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/services/admin_document_service.dart';
import 'package:show_talent/utils/admin_picked_file.dart';
import 'package:show_talent/widgets/club_enrollment_dialog.dart';

import 'test_support/admin_test_helpers.dart';

AdminPickedFile _file({
  String name = 'accord.pdf',
  int sizeBytes = 2048,
  String? mimeType,
}) {
  return AdminPickedFile(
    name: name,
    bytes: Uint8List(sizeBytes),
    mimeType: mimeType,
  );
}

/// Un service de documents qui ne touche jamais le stockage.
class _FakeDocumentService extends AdminDocumentService {
  _FakeDocumentService({
    this.documents = const <AdminStoredDocument>[],
    this.listThrows = false,
  }) : super.visualQa();

  final List<AdminStoredDocument> documents;
  final bool listThrows;

  final List<String> resolvedPaths = <String>[];

  @override
  Future<List<AdminStoredDocument>> listClubAgreements(String clubUid) async {
    if (listThrows) throw Exception('lecture refusee');
    return documents;
  }

  @override
  Future<AdminDocumentLink> resolvePath(String objectPath) async {
    resolvedPaths.add(objectPath);
    return const AdminDocumentLink.failure(message: 'Indisponible en test.');
  }
}

AppUser _clubUser() {
  return AppUser.fromMap(<String, dynamic>{
    'uid': 'club-1',
    'nom': 'Académie Abidjan Nord',
    'email': 'club@exemple.test',
    'role': 'club',
    'emailVerified': true,
    'dateInscription': DateTime(2026, 1, 1),
    'dernierLogin': DateTime(2026, 11, 18),
  });
}

Future<_FakeDocumentService> _pumpDialog(
  WidgetTester tester, {
  List<AdminStoredDocument> documents = const <AdminStoredDocument>[],
  bool listThrows = false,
}) async {
  final service = _FakeDocumentService(
    documents: documents,
    listThrows: listThrows,
  );

  // `showAdminFeedback` passe par la file de snackbars de GetX, qui est
  // globale : un bandeau laisse ouvert par un test fait echouer les suivants
  // sur un Ticker non libere. On remet la file a zero entre les tests.
  addTearDown(Get.reset);

  await pumpAdminTestApp(
    tester,
    Builder(
      builder: (context) =>
          ClubEnrollmentDialog(user: _clubUser(), documentService: service),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  group('validation du fichier', () {
    test('un PDF de taille raisonnable est accepte', () {
      expect(describeAgreementRejection(_file()), isNull);
    });

    test('un fichier vide est refuse', () {
      expect(describeAgreementRejection(_file(sizeBytes: 0)), contains('vide'));
    });

    test('au-dela de 8 Mo le fichier est refuse, avec sa taille', () {
      final rejection = describeAgreementRejection(
        _file(sizeBytes: adminAgreementMaxBytes + 1),
      );

      expect(rejection, contains('8 Mo'));
      expect(rejection, contains('8.0 Mo'));
    });

    test('exactement 8 Mo passe : la borne est inclusive', () {
      expect(
        describeAgreementRejection(_file(sizeBytes: adminAgreementMaxBytes)),
        isNull,
      );
    });

    test('un format hors de la liste est refuse', () {
      for (final name in const <String>[
        'accord.docx',
        'accord.zip',
        'accord',
        'accord.pdf.exe',
      ]) {
        expect(
          describeAgreementRejection(_file(name: name)),
          isNotNull,
          reason: '« $name » ne doit pas passer',
        );
      }
    });

    test('les quatre formats prevus passent, casse comprise', () {
      for (final name in const <String>[
        'a.pdf',
        'a.PDF',
        'a.jpg',
        'a.jpeg',
        'a.PNG',
      ]) {
        expect(
          describeAgreementRejection(_file(name: name)),
          isNull,
          reason: '« $name » doit passer',
        );
      }
    });
  });

  group('nom de l objet stocke', () {
    test('le nom du poste de travail n est jamais repris', () {
      // Un nom local peut porter des espaces, des accents, voire des barres
      // obliques qui changeraient le chemin de stockage.
      final name = adminAgreementObjectName(
        agreementRef: 'ACCORD 2026/011 — Côte d’Ivoire',
        extension: 'pdf',
        now: DateTime.utc(2026, 11, 19, 10),
      );

      expect(name, isNot(contains('/')));
      expect(name, isNot(contains(' ')));
      expect(name, startsWith('agreement_ACCORD-2026-011-C'));
      expect(name, endsWith('.pdf'));
    });

    test('un second depot n ecrase jamais le premier', () {
      // Un accord signe est un acte, et un acte ne se remplace pas en
      // silence : l'horodatage garantit un nom different.
      final first = adminAgreementObjectName(
        agreementRef: 'ACCORD-2026-011',
        extension: 'pdf',
        now: DateTime.utc(2026, 11, 19, 10),
      );
      final second = adminAgreementObjectName(
        agreementRef: 'ACCORD-2026-011',
        extension: 'pdf',
        now: DateTime.utc(2026, 11, 19, 10, 0, 1),
      );

      expect(first, isNot(second));
    });

    test('une reference vide retombe sur un nom neutre', () {
      final name = adminAgreementObjectName(
        agreementRef: '   ',
        extension: 'png',
        now: DateTime.utc(2026, 11, 19),
      );

      expect(name, startsWith('agreement_accord_'));
      expect(name, endsWith('.png'));
    });

    test('une extension absente retombe sur pdf', () {
      final name = adminAgreementObjectName(
        agreementRef: 'A',
        extension: '',
        now: DateTime.utc(2026, 11, 19),
      );

      expect(name, endsWith('.pdf'));
    });

    test('le type MIME vient de l extension, pas du navigateur', () {
      // Un navigateur annonce parfois une chaine vide, et un objet servi sans
      // type se telecharge au lieu de s'afficher dans l'onglet.
      expect(adminAgreementContentType('pdf'), 'application/pdf');
      expect(adminAgreementContentType('png'), 'image/png');
      expect(adminAgreementContentType('jpg'), 'image/jpeg');
      expect(adminAgreementContentType('jpeg'), 'image/jpeg');
      expect(adminAgreementContentType('bin'), 'application/octet-stream');
    });
  });

  group('service de documents', () {
    test('le dossier est celui que storage.rules nomme', () {
      expect(
        AdminDocumentService.clubAgreementFolder(' club-1 '),
        'clubAgreements/club-1',
      );
    });

    test('un fichier refuse ne tente jamais d ecriture', () async {
      // La validation passe AVANT la bascule de revue locale : le message
      // rendu est celui du refus, pas celui du mode.
      final service = AdminDocumentService.visualQa();

      final result = await service.uploadClubAgreement(
        clubUid: 'club-1',
        agreementRef: 'ACCORD-2026-011',
        file: _file(name: 'accord.docx'),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Format non accepté'));
      expect(result.document, isNull);
    });

    test('un club non designe est refuse avant tout le reste', () async {
      final service = AdminDocumentService.visualQa();

      final result = await service.uploadClubAgreement(
        clubUid: '  ',
        agreementRef: 'ACCORD-2026-011',
        file: _file(),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Aucun club'));
    });

    test('un chemin vide ne tente aucune lecture', () async {
      final link = await AdminDocumentService.visualQa().resolvePath('   ');

      expect(link.success, isFalse);
      expect(link.url, isNull);
    });
  });

  group('dialogue d habilitation', () {
    testWidgets('les accords deja deposes sont listes et ouvrables', (
      tester,
    ) async {
      // Sans cette liste, le depot serait une ecriture que personne ne peut
      // relire -- exactement le defaut que ce lot corrige ailleurs.
      final service = await _pumpDialog(
        tester,
        documents: [
          AdminStoredDocument(
            objectPath: 'clubAgreements/club-1/agreement_A_1.pdf',
            name: 'agreement_A_1.pdf',
            sizeBytes: 350 * 1024,
            updatedAt: DateTime(2026, 10, 12),
          ),
        ],
      );

      expect(find.textContaining('agreement_A_1.pdf'), findsOneWidget);
      expect(find.textContaining('12/10/2026'), findsOneWidget);
      expect(find.textContaining('350 Ko'), findsOneWidget);

      await tester.tap(find.text('Ouvrir'));
      await tester.pump();
      // Le bandeau de retour vit trois secondes : le laisser expirer avant de
      // conclure, sinon le minuteur reste en vol a la fin du test.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(service.resolvedPaths, [
        'clubAgreements/club-1/agreement_A_1.pdf',
      ]);
    });

    testWidgets('un dossier vide le dit sans crier a la panne', (tester) async {
      // La quasi-totalite des clubs n'ont jamais eu d'accord depose : traiter
      // ce cas comme une erreur ferait un message rouge a chaque ouverture.
      await _pumpDialog(tester);

      expect(find.textContaining('Aucun document déposé'), findsOneWidget);
      expect(find.text('Déposer l’accord signé'), findsOneWidget);
      expect(find.text('Ouvrir'), findsNothing);
    });

    testWidgets('une lecture refusee laisse le depot possible', (tester) async {
      await _pumpDialog(tester, listThrows: true);

      expect(
        find.textContaining('Impossible de lire les accords'),
        findsOneWidget,
      );
      expect(find.text('Déposer l’accord signé'), findsOneWidget);
    });

    testWidgets('le dialogue rend toujours une decision exploitable', (
      tester,
    ) async {
      // Le depot vit a cote de la decision, et ne la remplace pas : accorder
      // reste conditionne a une reference et a un terme.
      await _pumpDialog(tester);

      final grant = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        grant.onPressed,
        isNull,
        reason: 'sans terme choisi, accorder reste impossible',
      );
    });
  });
}
