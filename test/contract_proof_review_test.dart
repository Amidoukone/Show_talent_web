// Les garde-fous de la surface « statuts contractuels ».
//
// Le depot mobile a quatre fois livre une capacite serveur que rien
// n'atteignait, et ses garde-fous ne l'ont pas vu parce qu'ils verifiaient la
// PRESENCE du code et non son ACCESSIBILITE : un test disait
// `expect(repository, contains('submitProfileForReview('))` et serait reste
// vert pour toujours. Ces tests exercent donc l'appelant -- la charge utile
// reellement envoyee, l'onglet reellement monte, l'action reellement desarmee.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// `assignAll` est une extension de GetX : sans cet import, elle n'est pas
// visible ici, meme si admin_test_helpers.dart importe deja le paquet.
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:show_talent/config/app_environment.dart';
import 'package:show_talent/config/app_routes.dart';
import 'package:show_talent/controller/contract_proof_controller.dart';
import 'package:show_talent/dashboard/contract_proof_review_widget.dart';
import 'package:show_talent/models/contract_status_proof.dart';
import 'package:show_talent/models/football_vocabulary.dart';
import 'package:show_talent/models/player_football_profile.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/services/admin_content_service.dart';
import 'package:show_talent/services/admin_document_service.dart';
import 'package:show_talent/utils/admin_callable_action_catalog.dart';
import 'package:show_talent/utils/admin_storage_reference.dart';

import 'test_support/admin_test_helpers.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _MockHttpsCallable extends Mock implements HttpsCallable {}

class _MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<dynamic> {}

class _MockFirestore extends Mock implements FirebaseFirestore {}

/// Un controleur qui n'ouvre aucun flux Firestore.
///
/// `onInit` est neutralise comme dans `TestUserController` : la file est
/// semee a la main, et le constructeur ne garde la fausse instance Firestore
/// que pour ne jamais toucher `FirebaseFirestore.instance`, qui leverait sans
/// Firebase initialise.
class _SeededContractProofController extends ContractProofController {
  _SeededContractProofController({List<AppUser> seeded = const <AppUser>[]})
    : super(
        firestore: _MockFirestore(),
        adminContentService: AdminContentService.visualQa(),
      ) {
    pendingProofs.assignAll(seeded);
    isLoading.value = false;
  }

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> refreshProofs() async {}
}

/// Un joueur avec une piece, construit par la meme porte que la production.
///
/// `AppUser.fromMap` plutot qu'un constructeur direct : la forme des cles est
/// precisement ce qui doit rester aligne sur le depot mobile, et un test qui
/// contournerait le parsing ne verifierait rien de ce contrat.
AppUser _playerWithProof({
  required String uid,
  required String nom,
  Map<String, dynamic>? proof,
  String? declaredContractStatus,
  DateTime? declaredContractEndDate,
}) {
  final endDate = declaredContractEndDate == null
      ? null
      : Timestamp.fromDate(declaredContractEndDate);

  return AppUser.fromMap(<String, dynamic>{
    'uid': uid,
    'nom': nom,
    'role': 'joueur',
    'emailVerified': true,
    'dateInscription': DateTime(2026, 1, 12),
    'dernierLogin': DateTime(2026, 11, 18),
    'contractStatusProof': ?proof,
    'contractStatus': ?declaredContractStatus,
    'contractEndDate': ?endDate,
  });
}

void main() {
  group('reference de stockage', () {
    test('une reference gs:// est decomposee', () {
      final reference = AdminStorageReference.parse(
        'gs://adfoot-production.firebasestorage.app/identityDocuments/u1/'
        'contractProofs/contract_1763500000000.pdf',
      );

      expect(reference, isNotNull);
      expect(reference!.bucket, 'adfoot-production.firebasestorage.app');
      expect(reference.fileName, 'contract_1763500000000.pdf');
      expect(reference.extension, 'pdf');
      expect(reference.looksLikeImage, isFalse);
    });

    test('une image est reconnue comme telle', () {
      final reference = AdminStorageReference.parse(
        'gs://bucket/identityDocuments/u1/contractProofs/contract_17.JPG',
      );

      expect(reference!.looksLikeImage, isTrue);
      expect(reference.extension, 'jpg');
    });

    test(
      'un lien de telechargement porteur de jeton est refuse, pas accepte',
      () {
        // Le point de tout ce fichier. Un lien firebasestorage porte son
        // jeton dans l'adresse et reste ouvert APRES le retrait de l'acces de
        // celui a qui il a ete remis. L'accepter ici laisserait une piece de
        // dossier circuler hors de tout controle, alors qu'une reference
        // gs:// est revalidee par storage.rules a chaque lecture.
        expect(
          AdminStorageReference.isSupported(
            'https://firebasestorage.googleapis.com/v0/b/bucket/o/'
            'identityDocuments%2Fu1%2FcontractProofs%2Fcontract_17.pdf'
            '?alt=media&token=abc',
          ),
          isFalse,
        );
      },
    );

    test('une reference malformee ne designe rien', () {
      expect(AdminStorageReference.isSupported('gs://bucket/a//b'), isFalse);
      expect(AdminStorageReference.isSupported('gs://bucket/'), isFalse);
      expect(AdminStorageReference.isSupported('gs:///chemin'), isFalse);
      expect(
        AdminStorageReference.isSupported('identityDocuments/u1'),
        isFalse,
      );
      expect(AdminStorageReference.isSupported(''), isFalse);
      expect(AdminStorageReference.isSupported(null), isFalse);
    });

    test('un chemin relatif est resolu, jamais laisse tel quel', () {
      // `Uri.parse` normalise les segments `.` et `..` des l'analyse, donc une
      // tentative de remontee ne survit pas au parsing : elle devient un
      // chemin concret, que storage.rules refuse ensuite s'il ne nomme pas ce
      // dossier. C'est pourquoi le parseur ne les cherche pas lui-meme.
      final reference = AdminStorageReference.parse(
        'gs://bucket/identityDocuments/u1/contractProofs/../../secret.pdf',
      );

      expect(reference, isNotNull);
      expect(reference!.objectPath, 'identityDocuments/secret.pdf');
    });
  });

  group('modele de piece', () {
    test('les noms de champs du depot mobile sont lus tels quels', () {
      final proof = ContractStatusProof.fromMap(<String, dynamic>{
        'status': 'approved',
        'fileUrl': 'gs://bucket/identityDocuments/u1/contractProofs/c_1.pdf',
        'submittedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 1, 9)),
        'reviewedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 3, 14)),
        'reviewedBy': 'operateur-1',
        'reviewNote': 'Contrat signe et date.',
        'approvedContractStatus': 'under_contract',
        'approvedContractEndDate': Timestamp.fromDate(
          DateTime.utc(2028, 6, 30),
        ),
      });

      expect(proof.submitted, isTrue);
      expect(proof.isApproved, isTrue);
      expect(proof.hasFile, isTrue);
      expect(proof.reviewedBy, 'operateur-1');
      expect(proof.reviewNote, 'Contrat signe et date.');
      expect(proof.approvedContractStatus, ContractStatus.underContract);
      // `.toUtc()` parce que `Timestamp.toDate()` rend une date locale :
      // DateTime.== compare l'instant ET le fuseau, donc comparer directement
      // a une date UTC echouerait sur une machine hors UTC.
      expect(proof.approvedContractEndDate!.toUtc(), DateTime.utc(2028, 6, 30));
      expect(proof.statusLabel, 'Approuvée');
    });

    test('un document absent ne vaut pas une piece deposee', () {
      expect(ContractStatusProof.fromMap(null).submitted, isFalse);
      expect(ContractStatusProof.fromMap('approved').submitted, isFalse);
      expect(ContractStatusProof.absent.statusLabel, 'Aucune pièce');
    });

    test('un etat inconnu est montre tel quel, pas traduit au hasard', () {
      final proof = ContractStatusProof.fromMap(<String, dynamic>{
        'status': 'escalated',
      });

      expect(proof.statusLabel, 'escalated');
      expect(proof.isPending, isFalse);
      expect(proof.isApproved, isFalse);
    });

    group('ce que la fiche publique affiche', () {
      const approvedFree = ContractStatusProof(
        submitted: true,
        status: ContractStatusProof.statusApproved,
        fileUrl: 'gs://bucket/identityDocuments/u1/contractProofs/c_1.pdf',
        approvedContractStatus: ContractStatus.free,
      );

      test('une piece en attente ne publie rien', () {
        const pending = ContractStatusProof(
          submitted: true,
          status: ContractStatusProof.statusPending,
        );

        expect(
          pending.publishedStatusFor(
            const PlayerFootballProfile(contractStatus: ContractStatus.free),
          ),
          isNull,
        );
      });

      test('le statut approuve se publie quand le joueur declare le meme', () {
        expect(
          approvedFree.publishedStatusFor(
            const PlayerFootballProfile(contractStatus: ContractStatus.free),
          ),
          ContractStatus.free,
        );
      });

      test('un joueur qui change de statut apres coup perd l affichage', () {
        // Sans cette comparaison, un joueur ferait approuver une lettre de
        // liberation puis ecrirait ce qu'il veut dans le champ,
        // l'approbation servant de caution a une declaration que personne
        // n'a lue.
        final football = const PlayerFootballProfile(
          contractStatus: ContractStatus.underContract,
        );

        expect(approvedFree.publishedStatusFor(football), isNull);
        expect(approvedFree.isApprovedButSupersededFor(football), isTrue);
      });

      test('une fin de contrat repoussee fait tomber l affichage', () {
        final proof = ContractStatusProof(
          submitted: true,
          status: ContractStatusProof.statusApproved,
          fileUrl: 'gs://bucket/identityDocuments/u1/contractProofs/c_1.pdf',
          approvedContractStatus: ContractStatus.underContract,
          approvedContractEndDate: DateTime.utc(2027, 6, 30),
        );

        expect(
          proof.publishedStatusFor(
            PlayerFootballProfile(
              contractStatus: ContractStatus.underContract,
              contractEndDate: DateTime.utc(2027, 6, 30),
            ),
          ),
          ContractStatus.underContract,
        );

        expect(
          proof.publishedStatusFor(
            PlayerFootballProfile(
              contractStatus: ContractStatus.underContract,
              contractEndDate: DateTime.utc(2029, 6, 30),
            ),
          ),
          isNull,
        );
      });

      test('un statut qui attend une date sans date ne publie rien', () {
        const proof = ContractStatusProof(
          submitted: true,
          status: ContractStatusProof.statusApproved,
          fileUrl: 'gs://bucket/identityDocuments/u1/contractProofs/c_1.pdf',
          approvedContractStatus: ContractStatus.onLoan,
        );

        expect(
          proof.publishedStatusFor(
            const PlayerFootballProfile(contractStatus: ContractStatus.onLoan),
          ),
          isNull,
        );
      });
    });

    test('la piece survit a la relecture d un compte enrichi', () {
      // fetchUserWithPrivateFields reconstruit un AppUser en repassant par
      // toMap(). Sans l'entree correspondante, la fiche de revue annoncerait
      // « aucune piece » juste apres en avoir affiche une.
      final user = _playerWithProof(
        uid: 'u1',
        nom: 'Joueur Un',
        proof: <String, dynamic>{
          'status': 'pending',
          'fileUrl': 'gs://bucket/identityDocuments/u1/contractProofs/c_1.pdf',
          'submittedAt': Timestamp.fromDate(DateTime.utc(2026, 11, 10)),
        },
      );

      final roundTripped = AppUser.fromMap(user.toMap());

      expect(roundTripped.contractStatusProof.isPending, isTrue);
      expect(roundTripped.contractStatusProof.hasFile, isTrue);
      expect(
        roundTripped.contractStatusProof.submittedAt!.toUtc(),
        DateTime.utc(2026, 11, 10),
      );
    });
  });

  group('appel du callable', () {
    late _MockFirebaseFunctions functions;
    late _MockHttpsCallable callable;
    late AdminContentService service;

    setUp(() {
      functions = _MockFirebaseFunctions();
      callable = _MockHttpsCallable();
      when(() => functions.httpsCallable(any())).thenReturn(callable);
      service = AdminContentService(functions: functions);

      final result = _MockHttpsCallableResult();
      when(() => result.data).thenReturn(<String, dynamic>{
        'success': true,
        'code': 'ok',
        'message': 'Verdict enregistre.',
      });
      when(() => callable.call(any())).thenAnswer((_) async => result);
    });

    test(
      'une approbation envoie le statut couvert et sa date de fin',
      () async {
        final response = await service.reviewContractStatusProof(
          uid: ' u1 ',
          status: 'Approved',
          contractStatus: 'under_contract',
          contractEndDate: DateTime.utc(2028, 6, 30),
          note: ' Contrat signe. ',
        );

        expect(response.success, isTrue);
        verify(
          () => functions.httpsCallable('reviewContractStatusProof'),
        ).called(1);
        verify(
          () => callable.call(<String, dynamic>{
            'uid': 'u1',
            'status': 'approved',
            'contractStatus': 'under_contract',
            'contractEndDate': '2028-06-30T00:00:00.000Z',
            'note': 'Contrat signe.',
          }),
        ).called(1);
      },
    );

    test('un rejet n envoie ni statut ni date', () async {
      await service.reviewContractStatusProof(
        uid: 'u1',
        status: 'rejected',
        contractStatus: 'free',
        note: 'Document illisible.',
      );

      verify(
        () => callable.call(<String, dynamic>{
          'uid': 'u1',
          'status': 'rejected',
          'note': 'Document illisible.',
        }),
      ).called(1);
    });

    test(
      'approuver sans dire quel statut ne part jamais sur le reseau',
      () async {
        final response = await service.reviewContractStatusProof(
          uid: 'u1',
          status: 'approved',
        );

        expect(response.success, isFalse);
        expect(response.code, 'missing_contract_status');
        verifyNever(() => callable.call(any()));
      },
    );

    test('un verdict hors des deux valeurs est refuse localement', () async {
      final response = await service.reviewContractStatusProof(
        uid: 'u1',
        status: 'pending',
      );

      expect(response.success, isFalse);
      expect(response.code, 'invalid_status');
      verifyNever(() => callable.call(any()));
    });

    test('un motif trop long est refuse avec sa limite', () async {
      final response = await service.reviewContractStatusProof(
        uid: 'u1',
        status: 'rejected',
        note: 'x' * (ContractStatusProof.maxReviewNoteLength + 1),
      );

      expect(response.success, isFalse);
      expect(response.code, 'note_too_long');
      expect(response.message, contains('400'));
      verifyNever(() => callable.call(any()));
    });

    test('un uid vide est refuse localement', () async {
      final response = await service.reviewContractStatusProof(
        uid: '   ',
        status: 'rejected',
        note: 'Motif.',
      );

      expect(response.success, isFalse);
      expect(response.code, 'invalid_uid');
      verifyNever(() => callable.call(any()));
    });
  });

  group('ouverture de document', () {
    test(
      'une reference non exploitable ne touche jamais le stockage',
      () async {
        // Pas de FirebaseStorage injecte : si le service tentait une lecture,
        // le test leverait au lieu de rendre un echec type.
        final service = AdminDocumentService.visualQa();

        final link = await service.resolve('https://exemple.test/piece.pdf');

        expect(link.success, isFalse);
        expect(link.url, isNull);
        expect(link.message, contains('référence de stockage'));
      },
    );
  });

  group('accessibilite de la surface', () {
    test('le catalogue porte l entree, raccordee a une interface', () {
      final entry = adminCallableActions.firstWhere(
        (action) => action.callableName == 'reviewContractStatusProof',
      );

      expect(entry.isAvailableInBackend, isTrue);
      expect(entry.isConnectedInUi, isTrue);
      expect(entry.uiSurfaces, contains('ContractProofReviewWidget'));
      expect(
        connectedAdminCallableActions.map((action) => action.callableName),
        contains('reviewContractStatusProof'),
      );
    });

    test('l onglet est monte a la position que les liens profonds visent', () {
      // _dashboardItems et _widgetOptions() sont indexes par position, et
      // app_routes.dart resout les liens profonds sur ces index. Une
      // insertion au milieu decalerait tous les liens suivants sans que rien
      // n'echoue : d'ou cette verification de POSITION, et pas seulement de
      // presence.
      //
      // Les helpers lisent la source parce que les deux listes sont privees.
      // Volontairement pas d'assertion sur le nombre total d'onglets : un
      // onglet ajoute plus tard derriere celui-ci est legitime, et un test
      // qui l'interdirait ne protegerait rien.
      expect(dashboardItemIndex('Statuts contractuels'), 9);
      expect(dashboardScreenIndex('ContractProofReviewWidget'), 9);

      // Rattache a « Moderation » : son metier, et non une categorie neuve.
      expect(dashboardGroupIndices('Modération'), contains(9));
    });

    test('le lien profond resout vers le dernier onglet', () {
      for (final slug in const <String>[
        'contract-proofs',
        'statuts-contractuels',
      ]) {
        expect(
          AppRoutes.resolveDashboardInitialIndex(
            environment: AppEnvironment.local,
            uri: Uri.parse('http://localhost:8080/#/admin-dashboard?tab=$slug'),
          ),
          9,
          reason: 'le lien profond « $slug » doit ouvrir l onglet des pieces',
        );
      }
    });

    test('le controleur est enregistre par la liaison du tableau de bord', () {
      final bindings = File(
        'lib/config/app_page_bindings.dart',
      ).readAsStringSync();

      expect(bindings, contains('ContractProofController'));
    });
  });

  group('ecran d examen', () {
    testWidgets('une piece en attente est listee avec son attente', (
      tester,
    ) async {
      final controller = _SeededContractProofController(
        seeded: [
          _playerWithProof(
            uid: 'u1',
            nom: 'Mamadou Diabaté',
            declaredContractStatus: 'free',
            proof: <String, dynamic>{
              'status': 'pending',
              'fileUrl':
                  'gs://bucket/identityDocuments/u1/contractProofs/c_1.pdf',
              'submittedAt': Timestamp.fromDate(
                DateTime.now().subtract(const Duration(days: 9)),
              ),
            },
          ),
        ],
      );
      addTearDown(controller.onClose);

      await pumpAdminTestApp(
        tester,
        ContractProofReviewWidget(
          controller: controller,
          documentService: AdminDocumentService.visualQa(),
        ),
      );
      await tester.pump();

      expect(find.text('Mamadou Diabaté'), findsOneWidget);
      expect(find.text('c_1.pdf'), findsOneWidget);
      expect(find.text('Libre'), findsOneWidget);
      expect(find.text('9 j'), findsOneWidget);
      // Neuf jours d'attente : la bande de synthese doit le compter comme
      // en retard, c'est tout l'interet du compteur.
      expect(find.text('depuis plus de 7 jours'), findsOneWidget);
    });

    testWidgets(
      'l examen est desarme quand le serveur le refuserait, et dit pourquoi',
      (tester) async {
        // La lecon de la surface du consentement video : le callable refuse
        // une piece sans fichier (`failed-precondition`). Laisser le bouton
        // actif ferait buter l'operateur sur un refus serveur qu'aucun ecran
        // n'explique, et il concluerait a une panne.
        final controller = _SeededContractProofController(
          seeded: [
            _playerWithProof(
              uid: 'u2',
              nom: 'Sans Fichier',
              proof: <String, dynamic>{'status': 'pending'},
            ),
          ],
        );
        addTearDown(controller.onClose);

        await pumpAdminTestApp(
          tester,
          ContractProofReviewWidget(
            controller: controller,
            documentService: AdminDocumentService.visualQa(),
          ),
        );
        await tester.pump();

        expect(find.text('Sans Fichier'), findsOneWidget);
        expect(find.text('Aucun fichier'), findsOneWidget);
        expect(find.text('sans fichier exploitable'), findsOneWidget);

        final blockedAction = tester.widget<IconButton>(
          find.ancestor(
            of: find.byIcon(Icons.gavel_rounded),
            matching: find.byType(IconButton),
          ),
        );
        expect(
          blockedAction.onPressed,
          isNull,
          reason: 'l action doit etre desarmee, pas seulement echouer',
        );

        // AdminRowActions porte l'intitule sur un Tooltip enveloppant, pas
        // sur IconButton.tooltip : c'est ce Tooltip-la qui doit dire pourquoi.
        final blockedTooltip = tester.widget<Tooltip>(
          find
              .ancestor(
                of: find.byIcon(Icons.gavel_rounded),
                matching: find.byType(Tooltip),
              )
              .first,
        );
        expect(
          blockedTooltip.message,
          contains('il n’y a rien à examiner'),
          reason: 'et elle doit dire pourquoi',
        );
      },
    );

    testWidgets('une file vide le dit sans proposer de verdict', (
      tester,
    ) async {
      final controller = _SeededContractProofController();
      addTearDown(controller.onClose);

      await pumpAdminTestApp(
        tester,
        ContractProofReviewWidget(
          controller: controller,
          documentService: AdminDocumentService.visualQa(),
        ),
      );
      await tester.pump();

      expect(find.text('Aucune pièce à examiner'), findsOneWidget);
      expect(find.byIcon(Icons.gavel_rounded), findsNothing);
    });
  });
}
