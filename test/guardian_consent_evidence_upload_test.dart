// Le televersement de la preuve d'un accord parental.
//
// `evidenceReference` acceptait deja une reference libre de 120 caracteres
// (functions/src/minor_consent.ts, depot mobile), mais aucun document ne
// pouvait etre depose derriere : `storage.rules` ne prevoyait aucun chemin
// pour `identityDocuments/{uid}/guardianConsent/`. Ce chemin existe
// desormais (commit mobile "Ouvrir le chemin Storage de la preuve d'un
// accord parental").
//
// La reference complete `gs://<bucket>/identityDocuments/<uid>/
// guardianConsent/<fichier>` depasse les 120 caracteres pour un UID Firebase
// standard : elle n'est donc jamais ecrite dans
// `guardianConsent.evidenceReference`, qui resterait une note libre. La
// preuve se liste depuis ce dossier deterministe, exactement comme un
// accord de club.
//
// Le choix du fichier passe par le DOM et n'est pas exerçable ici, comme
// pour l'accord de club : ces tests verifient ce qui decide (nom de l'objet,
// dossier, validation) et ce que le dialogue affiche a partir d'un service
// bouche.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/services/admin_document_service.dart';
import 'package:show_talent/utils/admin_picked_file.dart';
import 'package:show_talent/widgets/managed_profile_edit_dialog.dart';

import 'test_support/admin_test_helpers.dart';

AdminPickedFile _file({
  String name = 'justificatif.pdf',
  int sizeBytes = 2048,
}) {
  return AdminPickedFile(name: name, bytes: Uint8List(sizeBytes));
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
  Future<List<AdminStoredDocument>> listGuardianConsentEvidence(
    String uid,
  ) async {
    if (listThrows) throw Exception('lecture refusee');
    return documents;
  }

  @override
  Future<AdminDocumentLink> resolvePath(String objectPath) async {
    resolvedPaths.add(objectPath);
    return const AdminDocumentLink.failure(message: 'Indisponible en test.');
  }
}

AppUser _minorPlayer({String uid = 'm1', bool isMinorProfile = false}) {
  return AppUser.fromMap(<String, dynamic>{
    'uid': uid,
    'nom': 'Mineur Un',
    'email': 'mineur@exemple.test',
    'role': 'joueur',
    'birthDate': DateTime.utc(2012, 1, 1),
    'isMinorProfile': isMinorProfile,
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

  addTearDown(Get.reset);

  await pumpAdminTestApp(
    tester,
    Builder(
      builder: (context) => ManagedProfileEditDialog(
        user: _minorPlayer(),
        documentService: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

void main() {
  group('nom de l objet stocke', () {
    test('correspond exactement a la regle de storage.rules', () {
      final name = guardianConsentObjectName(
        extension: 'pdf',
        now: DateTime.utc(2026, 11, 25, 20, 29),
      );

      expect(
        RegExp(r'^guardian_consent_[0-9]+\.(pdf|jpg|jpeg|png)$').hasMatch(
          name,
        ),
        isTrue,
        reason: name,
      );
    });

    test('un second depot n ecrase jamais le premier', () {
      final first = guardianConsentObjectName(
        extension: 'pdf',
        now: DateTime.utc(2026, 11, 25, 20, 29, 0),
      );
      final second = guardianConsentObjectName(
        extension: 'pdf',
        now: DateTime.utc(2026, 11, 25, 20, 29, 1),
      );

      expect(first, isNot(second));
    });

    test('une extension absente retombe sur pdf', () {
      final name = guardianConsentObjectName(
        extension: '',
        now: DateTime.utc(2026, 11, 25),
      );

      expect(name, endsWith('.pdf'));
    });
  });

  group('service de documents', () {
    test('le dossier est celui que storage.rules nomme', () {
      expect(
        AdminDocumentService.guardianConsentFolder(' m1 '),
        'identityDocuments/m1/guardianConsent',
      );
    });

    test('un fichier refuse ne tente jamais d ecriture', () async {
      final service = AdminDocumentService.visualQa();

      final result = await service.uploadGuardianConsentEvidence(
        uid: 'm1',
        file: _file(name: 'justificatif.docx'),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Format non accepté'));
      expect(result.document, isNull);
    });

    test('un compte non designe est refuse avant tout le reste', () async {
      final service = AdminDocumentService.visualQa();

      final result = await service.uploadGuardianConsentEvidence(
        uid: '  ',
        file: _file(),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Aucun compte'));
    });
  });

  group('dialogue de profil', () {
    testWidgets('les justificatifs deja deposes sont listes et ouvrables', (
      tester,
    ) async {
      final service = await _pumpDialog(
        tester,
        documents: [
          AdminStoredDocument(
            objectPath: 'identityDocuments/m1/guardianConsent/'
                'guardian_consent_1.pdf',
            name: 'guardian_consent_1.pdf',
            sizeBytes: 120 * 1024,
            updatedAt: DateTime(2026, 11, 25),
          ),
        ],
      );

      expect(find.textContaining('guardian_consent_1.pdf'), findsOneWidget);
      expect(find.textContaining('25/11/2026'), findsOneWidget);

      await tester.tap(find.text('Ouvrir'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(service.resolvedPaths, [
        'identityDocuments/m1/guardianConsent/guardian_consent_1.pdf',
      ]);
    });

    testWidgets('un dossier vide le dit sans crier a la panne', (
      tester,
    ) async {
      await _pumpDialog(tester);

      expect(find.textContaining('Aucun justificatif déposé'), findsOneWidget);
      expect(find.text('Déposer un justificatif'), findsOneWidget);
      expect(find.text('Ouvrir'), findsNothing);
    });

    testWidgets('une lecture refusee laisse le depot possible', (
      tester,
    ) async {
      await _pumpDialog(tester, listThrows: true);

      expect(
        find.textContaining('Impossible de lire les justificatifs'),
        findsOneWidget,
      );
      expect(find.text('Déposer un justificatif'), findsOneWidget);
    });
  });
}
