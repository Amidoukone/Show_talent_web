import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:show_talent/controller/user_controller.dart';
import 'package:show_talent/controller/video_controller.dart';
import 'package:show_talent/dashboard/user_management_widget.dart';
import 'package:show_talent/dashboard/video_added_widget.dart';
import 'package:show_talent/dashboard/video_reported_widget.dart';
import 'package:show_talent/dashboard/video_review_widget.dart';
import 'package:show_talent/models/admin_action_response.dart';
import 'package:show_talent/models/contract_status_proof.dart';
import 'package:show_talent/models/football_vocabulary.dart';
import 'package:show_talent/models/player_football_profile.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/models/video.dart';
import 'package:show_talent/services/admin_content_service.dart';
import 'package:show_talent/services/managed_account_service.dart';
import 'package:show_talent/widgets/contract_proof_verdict_dialog.dart';
import 'package:show_talent/widgets/managed_profile_edit_dialog.dart';

import 'test_support/admin_test_helpers.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _MockHttpsCallable extends Mock implements HttpsCallable {}

class _MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<dynamic> {}

class _SeededVideoController extends VideoController {
  _SeededVideoController(List<Video> seeded)
    : super(adminContentService: AdminContentService.visualQa()) {
    videoList.assignAll(seeded);
    isLoading.value = false;
  }

  final List<Map<String, String>> rejectedCalls = <Map<String, String>>[];

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  void fetchVideos() {}

  @override
  Future<AdminActionResponse> rejectVideo(
    String videoId, {
    String reason = '',
  }) async {
    rejectedCalls.add({'videoId': videoId, 'reason': reason});
    videoList.removeWhere((video) => video.id == videoId);
    return const AdminActionResponse(
      success: true,
      code: 'ok',
      message: 'Vidéo refusée.',
    );
  }
}

void main() {
  group('Dates calendaires UTC (P1-7 & P1-8)', () {
    test(
      'ContractStatusProof.publishedStatusFor compare au jour calendaire UTC',
      () {
        final proof = ContractStatusProof(
          submitted: true,
          status: ContractStatusProof.statusApproved,
          fileUrl: 'gs://bucket/identityDocuments/u1/contractProofs/c_1.pdf',
          approvedContractStatus: ContractStatus.underContract,
          approvedContractEndDate: DateTime.utc(2027, 6, 30),
          reviewRevision: 2,
        );

        expect(
          proof.publishedStatusFor(
            PlayerFootballProfile(
              contractStatus: ContractStatus.underContract,
              contractEndDate: DateTime.utc(2027, 6, 30, 14, 30),
            ),
          ),
          ContractStatus.underContract,
        );
        expect(
          proof.isApprovedButSupersededFor(
            PlayerFootballProfile(
              contractStatus: ContractStatus.underContract,
              contractEndDate: DateTime.utc(2027, 6, 30, 23, 59),
            ),
          ),
          isFalse,
        );
        expect(
          proof.publishedStatusFor(
            PlayerFootballProfile(
              contractStatus: ContractStatus.underContract,
              contractEndDate: DateTime.utc(2027, 7, 1),
            ),
          ),
          isNull,
        );
      },
    );

    test('reviewRevision survit à fromMap / toMap', () {
      final proof = ContractStatusProof.fromMap(<String, dynamic>{
        'status': 'approved',
        'fileUrl': 'gs://bucket/identityDocuments/u1/contractProofs/c_1.pdf',
        'approvedContractStatus': 'free',
        'reviewRevision': 3,
      });

      expect(proof.reviewRevision, 3);
      expect(proof.toMap()?['reviewRevision'], 3);
    });

    testWidgets(
      'ContractProofVerdictDialog ne signale pas de discordance sur un même jour UTC',
      (tester) async {
        final player = AppUser.fromMap(<String, dynamic>{
          'uid': 'u1',
          'nom': 'Moussa Koné',
          'role': 'joueur',
          'emailVerified': true,
          'dateInscription': DateTime.utc(2026, 1, 10),
          'dernierLogin': DateTime.utc(2026, 11, 18),
          'contractStatus': 'under_contract',
          'contractEndDate': Timestamp.fromDate(DateTime.utc(2027, 6, 30, 12)),
          'contractStatusProof': <String, dynamic>{
            'status': 'pending',
            'fileUrl': 'gs://bucket/identityDocuments/u1/contractProofs/c.pdf',
            'approvedContractStatus': 'under_contract',
            'approvedContractEndDate': Timestamp.fromDate(
              DateTime.utc(2027, 6, 30),
            ),
          },
        });

        await pumpAdminTestApp(
          tester,
          ContractProofVerdictDialog(user: player),
        );

        expect(
          find.textContaining('deux dates ne concordent pas'),
          findsNothing,
        );
      },
    );

    test(
      'AdminContentService et ManagedAccountService sérialisent les dates calendaires à minuit UTC',
      () async {
        final functions = _MockFirebaseFunctions();
        final callable = _MockHttpsCallable();
        final result = _MockHttpsCallableResult();
        when(() => functions.httpsCallable(any())).thenReturn(callable);
        when(() => result.data).thenReturn(<String, dynamic>{'success': true});
        when(() => callable.call(any())).thenAnswer((_) async => result);

        final contentService = AdminContentService(functions: functions);
        await contentService.reviewContractStatusProof(
          uid: 'player-1',
          expectedFileUrl:
              'gs://bucket/identityDocuments/player-1/contractProofs/c.pdf',
          status: 'approved',
          contractStatus: 'under_contract',
          contractEndDate: DateTime(2028, 6, 30, 15, 45),
        );

        verify(
          () => callable.call(<String, dynamic>{
            'uid': 'player-1',
            'expectedFileUrl':
                'gs://bucket/identityDocuments/player-1/contractProofs/c.pdf',
            'expectedStatus': 'pending',
            'status': 'approved',
            'contractStatus': 'under_contract',
            'contractEndDate': '2028-06-30T00:00:00.000Z',
          }),
        ).called(1);

        final recorded = <Map<String, dynamic>>[];
        final managedService = ManagedAccountService(
          callableExecutor: (name, payload) async {
            recorded.add({'name': name, 'payload': payload});
            return <String, dynamic>{'uid': 'p1', 'role': 'joueur'};
          },
        );
        await managedService.provisionManagedAccount(
          email: 'p1@example.com',
          nom: 'Moussa',
          role: 'joueur',
          birthDate: DateTime(2008, 1, 1, 14, 20),
        );
        expect(
          recorded.single['payload']['birthDate'],
          '2008-01-01T00:00:00.000Z',
        );

        final editDialogSource = File(
          'lib/widgets/managed_profile_edit_dialog.dart',
        ).readAsStringSync();
        expect(
          editDialogSource,
          contains(
            'DateTime.utc(date.year, date.month, date.day).toIso8601String()',
          ),
        );
      },
    );
  });

  group('Révocation d’une pièce contractuelle approuvée (R83)', () {
    test(
      'AdminContentService transmet expectedStatus=approved et expectedReviewRevision',
      () async {
        final functions = _MockFirebaseFunctions();
        final callable = _MockHttpsCallable();
        final result = _MockHttpsCallableResult();
        when(() => functions.httpsCallable(any())).thenReturn(callable);
        when(() => result.data).thenReturn(<String, dynamic>{
          'success': true,
          'message': 'Révoquée.',
        });
        when(() => callable.call(any())).thenAnswer((_) async => result);

        final service = AdminContentService(functions: functions);
        final response = await service.reviewContractStatusProof(
          uid: 'player-83',
          expectedFileUrl:
              'gs://bucket/identityDocuments/player-83/contractProofs/c.pdf',
          expectedStatus: ContractStatusProof.statusApproved,
          expectedReviewRevision: 2,
          status: ContractStatusProof.statusRejected,
          note: 'Pièce expirée après purge',
        );

        expect(response.success, isTrue);
        verify(
          () => callable.call(<String, dynamic>{
            'uid': 'player-83',
            'expectedFileUrl':
                'gs://bucket/identityDocuments/player-83/contractProofs/c.pdf',
            'expectedStatus': 'approved',
            'expectedReviewRevision': 2,
            'status': 'rejected',
            'note': 'Pièce expirée après purge',
          }),
        ).called(1);

        final invalid = await service.reviewContractStatusProof(
          uid: 'player-83',
          expectedFileUrl: 'gs://bucket/c.pdf',
          expectedStatus: 'unknown',
          status: 'rejected',
        );
        expect(invalid.success, isFalse);
        expect(invalid.code, 'invalid_expected_status');
      },
    );

    testWidgets(
      'UserManagementWidget permet de révoquer un statut contractuel approuvé',
      (tester) async {
        final functions = _MockFirebaseFunctions();
        final callable = _MockHttpsCallable();
        final result = _MockHttpsCallableResult();
        when(() => functions.httpsCallable(any())).thenReturn(callable);
        when(() => result.data).thenReturn(<String, dynamic>{
          'success': true,
          'message': 'Statut révoqué.',
        });
        when(() => callable.call(any())).thenAnswer((_) async => result);

        final player = AppUser.fromMap(<String, dynamic>{
          'uid': 'player-83',
          'nom': 'Ibrahima Touré',
          'email': 'ibrahima@example.com',
          'role': 'joueur',
          'createdByAdmin': true,
          'estActif': true,
          'authDisabled': false,
          'emailVerified': true,
          'dateInscription': DateTime.utc(2026, 1, 10),
          'dernierLogin': DateTime.utc(2026, 11, 20),
          'contractStatus': 'free',
          'contractStatusProof': <String, dynamic>{
            'status': 'approved',
            'fileUrl':
                'gs://bucket/identityDocuments/player-83/contractProofs/c.pdf',
            'approvedContractStatus': 'free',
            'reviewRevision': 1,
          },
        });

        final userController = TestUserController(users: [player]);
        final managedService = ManagedAccountService(
          callableExecutor: (_, _) async => <String, dynamic>{'success': true},
        );
        final contentService = AdminContentService(functions: functions);

        await pumpAdminTestApp(
          tester,
          UserManagementWidget(
            selectedRole: 'Tous',
            userController: userController,
            managedAccountService: managedService,
            adminContentService: contentService,
          ),
        );
        await tester.pumpAndSettle();

        final overflowMenu = find.byType(PopupMenuButton<int>);
        await tester.ensureVisible(overflowMenu);
        await tester.tap(overflowMenu);
        await tester.pumpAndSettle();

        expect(find.text('Révoquer le statut contractuel'), findsOneWidget);
        await tester.tap(find.text('Révoquer le statut contractuel'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).last,
          'Contrat expiré, pièce purgée',
        );
        await tester.pump();
        await tester.tap(find.text('Révoquer'));
        await tester.pumpAndSettle();

        verify(
          () => callable.call(<String, dynamic>{
            'uid': 'player-83',
            'expectedFileUrl':
                'gs://bucket/identityDocuments/player-83/contractProofs/c.pdf',
            'expectedStatus': 'approved',
            'expectedReviewRevision': 1,
            'status': 'rejected',
            'note': 'Contrat expiré, pièce purgée',
          }),
        ).called(1);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Invalidation de certification & protections mineurs (R78 & R83)', () {
    testWidgets(
      'ManagedProfileEditDialog avertit du retrait de certification pour les champs football',
      (tester) async {
        final verifiedPlayer = buildTestUser(
          uid: 'player-v',
          nom: 'Oumar Diallo',
          email: 'oumar@example.com',
          role: 'joueur',
          createdByAdmin: true,
          profileVerified: true,
        );

        await pumpAdminTestApp(
          tester,
          ManagedProfileEditDialog(user: verifiedPlayer),
        );

        expect(
          find.textContaining(
            'Ce profil est certifié : modifier les informations',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'UserManagementWidget désarme la réactivation d’un mineur sans accord parental et mentionne le passeport au retrait',
      (tester) async {
        final minor = AppUser.fromMap(<String, dynamic>{
          'uid': 'minor-1',
          'nom': 'Adama Mineur',
          'email': 'minor@example.com',
          'role': 'joueur',
          'createdByAdmin': true,
          'estActif': false,
          'authDisabled': true,
          'emailVerified': true,
          'isMinorProfile': true,
          'minorProfileApproved': false,
          'dateInscription': DateTime.utc(2026, 1, 10),
          'dernierLogin': DateTime.utc(2026, 11, 20),
        });

        final userController = TestUserController(users: [minor]);
        final managedService = ManagedAccountService(
          callableExecutor: (_, _) async => <String, dynamic>{'success': true},
        );

        await pumpAdminTestApp(
          tester,
          UserManagementWidget(
            selectedRole: 'Tous',
            userController: userController,
            managedAccountService: managedService,
            adminContentService: AdminContentService.visualQa(),
          ),
        );
        await tester.pumpAndSettle();

        final lockButton = find.ancestor(
          of: find.byIcon(Icons.lock_open_rounded),
          matching: find.byType(IconButton),
        );
        expect(lockButton, findsOneWidget);
        expect(tester.widget<IconButton>(lockButton).onPressed, isNull);
        final lockTooltip = find.ancestor(
          of: lockButton,
          matching: find.byType(Tooltip),
        );
        expect(lockTooltip, findsOneWidget);
        expect(
          tester.widget<Tooltip>(lockTooltip).message,
          contains('accord parental'),
        );

        final overflowMenu = find.byType(PopupMenuButton<int>);
        await tester.ensureVisible(overflowMenu);
        await tester.tap(overflowMenu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Retirer les autorisations parentales'));
        await tester.pumpAndSettle();

        expect(find.textContaining('passeport'), findsOneWidget);
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
      },
    );
  });

  group('Dépôts de clubs (playerUid) et dialogues vidéo sûrs', () {
    tearDown(Get.reset);

    testWidgets(
      'VideoAddedWidget et VideoReportedWidget affichent et recherchent le joueur montré',
      (tester) async {
        final club = buildTestUser(
          uid: 'club-1',
          nom: 'AS Bamako',
          email: 'club@example.com',
          role: 'club',
        );
        final player = buildTestUser(
          uid: 'player-9',
          nom: 'Salif Keïta',
          email: 'salif@example.com',
          role: 'joueur',
        );
        final clubVideo = Video(
          id: 'vid-club-9',
          videoUrl: 'https://example.invalid/v.mp4',
          caption: 'Frappe en lucarne',
          uid: 'club-1',
          playerUid: 'player-9',
          status: 'ready',
          moderationStatus: 'approved',
          isPublic: true,
          optimized: true,
          reportCount: 2,
          reports: const ['u-a', 'u-b'],
        );

        Get.put<UserController>(TestUserController(users: [club, player]));
        Get.put<VideoController>(_SeededVideoController([clubVideo]));

        await pumpAdminTestApp(tester, const VideoAddedWidget());
        await tester.pumpAndSettle();
        expect(find.text('Salif Keïta'), findsOneWidget);
        expect(find.text('Déposée par AS Bamako'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Salif');
        await tester.pumpAndSettle();
        expect(find.text('Frappe en lucarne'), findsOneWidget);

        await pumpAdminTestApp(tester, const VideoReportedWidget());
        await tester.pumpAndSettle();
        expect(find.text('Salif Keïta'), findsOneWidget);
        expect(find.text('Déposée par AS Bamako'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'player-9');
        await tester.pumpAndSettle();
        expect(find.text('Frappe en lucarne'), findsOneWidget);
      },
    );

    testWidgets(
      'VideoReviewWidget ferme le dialogue de refus sans erreur de TextEditingController',
      (tester) async {
        final player = buildTestUser(
          uid: 'player-1',
          nom: 'Moussa',
          email: 'moussa@example.com',
          role: 'joueur',
        );
        final pendingVideo = Video(
          id: 'vid-pending-1',
          videoUrl: 'https://example.invalid/pending.mp4',
          caption: 'Action en match',
          uid: 'player-1',
          status: 'under_review',
          moderationStatus: 'pending',
          optimized: true,
        );
        final videoController = _SeededVideoController([pendingVideo]);

        Get.put<UserController>(TestUserController(users: [player]));
        Get.put<VideoController>(videoController);

        await pumpAdminTestApp(tester, const VideoReviewWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.cancel_outlined));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).last,
          'Image trop sombre',
        );
        await tester.pump();
        await tester.tap(find.text('Refuser et supprimer'));
        await tester.pumpAndSettle();

        expect(videoController.rejectedCalls, [
          {'videoId': 'vid-pending-1', 'reason': 'Image trop sombre'},
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
