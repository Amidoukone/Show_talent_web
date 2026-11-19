// Le consentement du joueur sur une video deposee par son club.
//
// `adminSetVideoStatus` refuse d'approuver une video de club que le joueur
// n'a pas acceptee. Sans cet ecran, l'operateur butait sur un refus serveur
// qu'aucune surface n'expliquait, et concluait a une panne au premier depot
// de club. Ces tests verifient que l'ecran desarme EXACTEMENT ce que le
// serveur refuse, et qu'il dit pourquoi.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:show_talent/controller/user_controller.dart';
import 'package:show_talent/controller/video_controller.dart';
import 'package:show_talent/dashboard/video_review_widget.dart';
import 'package:show_talent/models/video.dart';
import 'package:show_talent/services/admin_content_service.dart';

import 'test_support/admin_test_helpers.dart';

/// Un controleur video qui n'ouvre ni flux Firestore ni ecoute Auth.
class _SeededVideoController extends VideoController {
  _SeededVideoController({List<Video> seeded = const <Video>[]})
    : super(adminContentService: AdminContentService.visualQa()) {
    videoList.assignAll(seeded);
    isLoading.value = false;
  }

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  void fetchVideos() {}
}

/// Une video de la file de validation, construite par la porte de production.
///
/// `Video.fromMap` plutot qu'un constructeur direct : la forme des cles est
/// precisement ce qui doit rester aligne sur `upload_session.ts`, et un test
/// qui contournerait le parsing ne verifierait rien de ce contrat.
Video _pendingVideo({
  required String id,
  required String uid,
  String? playerUid,
  bool consentRequired = false,
  String? consentDecision,
  DateTime? consentAt,
  String title = 'Action de jeu',
}) {
  return Video.fromMap(<String, dynamic>{
    'id': id,
    'uid': uid,
    'caption': title,
    'videoUrl': 'https://exemple.test/$id.mp4',
    'status': 'under_review',
    'moderationStatus': 'pending',
    'optimized': true,
    'playerUid': ?playerUid,
    if (consentRequired) 'playerConsentRequired': true,
    'playerConsentDecision': ?consentDecision,
    'playerConsentAt': ?(consentAt == null
        ? null
        : Timestamp.fromDate(consentAt)),
    if (consentDecision != null)
      'playerConsentDecidedAt': Timestamp.fromDate(DateTime(2026, 11, 17)),
  });
}

Future<void> _pumpReviewQueue(
  WidgetTester tester, {
  required List<Video> videos,
}) async {
  Get.reset();
  addTearDown(Get.reset);

  Get.put<UserController>(
    TestUserController(
      users: [
        buildTestUser(
          uid: 'club-1',
          nom: 'Académie Abidjan Nord',
          email: 'club@exemple.test',
          role: 'club',
          createdByAdmin: true,
        ),
        buildTestUser(
          uid: 'player-1',
          nom: 'Mamadou Diabaté',
          email: 'joueur@exemple.test',
          role: 'joueur',
        ),
      ],
    ),
  );
  Get.put<VideoController>(_SeededVideoController(seeded: videos));

  await pumpAdminTestApp(tester, const VideoReviewWidget());
  await tester.pump();
}

/// L'etat de l'action « Approuver » d'une ligne : desarmee ou non, et son
/// intitule, qui est l'endroit ou la raison doit apparaitre.
({bool enabled, String tooltip}) _approveAction(WidgetTester tester) {
  final icon = find.byIcon(Icons.check_circle_outline_rounded);
  final button = tester.widget<IconButton>(
    find.ancestor(of: icon, matching: find.byType(IconButton)),
  );
  final tooltip = tester.widget<Tooltip>(
    find.ancestor(of: icon, matching: find.byType(Tooltip)).first,
  );

  return (enabled: button.onPressed != null, tooltip: tooltip.message ?? '');
}

void main() {
  group('modele video', () {
    test('les champs de consentement du depot mobile sont lus tels quels', () {
      final video = _pendingVideo(
        id: 'v1',
        uid: 'club-1',
        playerUid: 'player-1',
        consentRequired: true,
        consentDecision: 'accepted',
        consentAt: DateTime.utc(2026, 11, 17, 10),
      );

      expect(video.playerUid, 'player-1');
      expect(video.playerConsentRequired, isTrue);
      expect(video.playerConsentDecision, 'accepted');
      expect(video.playerConsentAt!.toUtc(), DateTime.utc(2026, 11, 17, 10));
      expect(video.playerConsentDecidedAt, isNotNull);
      expect(video.isClubUpload, isTrue);
    });

    test('la garde d approbation est le miroir exact de celle du serveur', () {
      // Serveur : `playerConsentRequired == true && playerConsentAt == null`
      // (functions/src/admin_content_actions.ts). Les deux doivent lire la
      // meme chose, sinon l'ecran propose une decision que le serveur refuse.
      final waiting = _pendingVideo(
        id: 'v1',
        uid: 'club-1',
        playerUid: 'player-1',
        consentRequired: true,
      );
      expect(waiting.approvalBlockedByPlayerConsent, isTrue);
      expect(waiting.awaitsPlayerConsent, isTrue);
      expect(waiting.playerRefusedPublication, isFalse);
      expect(waiting.playerConsentLabel, 'En attente du joueur');

      // Un refus laisse `playerConsentAt` nul, donc le serveur refuse
      // toujours : c'est le meme blocage, mais il ne se traite pas pareil.
      final refused = _pendingVideo(
        id: 'v2',
        uid: 'club-1',
        playerUid: 'player-1',
        consentRequired: true,
        consentDecision: 'refused',
      );
      expect(refused.approvalBlockedByPlayerConsent, isTrue);
      expect(refused.awaitsPlayerConsent, isFalse);
      expect(refused.playerRefusedPublication, isTrue);
      expect(refused.playerConsentLabel, 'Refusée par le joueur');

      final accepted = _pendingVideo(
        id: 'v3',
        uid: 'club-1',
        playerUid: 'player-1',
        consentRequired: true,
        consentDecision: 'accepted',
        consentAt: DateTime(2026, 11, 17),
      );
      expect(accepted.approvalBlockedByPlayerConsent, isFalse);
      expect(accepted.playerConsentLabel, 'Acceptée par le joueur');
    });

    test('une video que le joueur a deposee lui-meme n est jamais bloquee', () {
      // Son consentement est acquis par construction, et le lui demander
      // serait lui demander de consentir a son propre geste.
      final own = _pendingVideo(id: 'v1', uid: 'player-1');

      expect(own.playerConsentRequired, isFalse);
      expect(own.isClubUpload, isFalse);
      expect(own.approvalBlockedByPlayerConsent, isFalse);
      expect(own.playerConsentLabel, 'Sans objet');
    });

    test('un document sans aucun champ de consentement reste lisible', () {
      // Tous les documents anterieurs au lot en sont depourvus : ils doivent
      // se lire comme « pas de consentement requis », pas lever.
      final legacy = Video.fromMap(<String, dynamic>{
        'id': 'v0',
        'uid': 'player-1',
        'videoUrl': 'https://exemple.test/v0.mp4',
      });

      expect(legacy.playerUid, '');
      expect(legacy.playerConsentRequired, isFalse);
      expect(legacy.playerConsentAt, isNull);
      expect(legacy.approvalBlockedByPlayerConsent, isFalse);
    });
  });

  group('file de validation', () {
    testWidgets('un depot de club nomme le joueur montre et son club', (
      tester,
    ) async {
      await _pumpReviewQueue(
        tester,
        videos: [
          _pendingVideo(
            id: 'v1',
            uid: 'club-1',
            playerUid: 'player-1',
            consentRequired: true,
          ),
        ],
      );

      // Le joueur montre passe devant : c'est lui que la publication expose.
      expect(find.text('Mamadou Diabaté'), findsOneWidget);
      expect(find.text('Déposée par Académie Abidjan Nord'), findsOneWidget);
      expect(find.text('Accord attendu'), findsOneWidget);
    });

    testWidgets(
      'l approbation est desarmee tant que le joueur ne s est pas prononce',
      (tester) async {
        await _pumpReviewQueue(
          tester,
          videos: [
            _pendingVideo(
              id: 'v1',
              uid: 'club-1',
              playerUid: 'player-1',
              consentRequired: true,
            ),
          ],
        );

        final action = _approveAction(tester);
        expect(
          action.enabled,
          isFalse,
          reason: 'le serveur refuserait cette approbation',
        );
        expect(action.tooltip, contains('n’a pas encore accepté'));
      },
    );

    testWidgets('un refus du joueur se distingue d une attente', (
      tester,
    ) async {
      // Les deux bloquent l'approbation, et ne demandent pas la meme chose :
      // une attente se laisse murir, un refus se traite.
      await _pumpReviewQueue(
        tester,
        videos: [
          _pendingVideo(
            id: 'v1',
            uid: 'club-1',
            playerUid: 'player-1',
            consentRequired: true,
            consentDecision: 'refused',
          ),
        ],
      );

      expect(find.text('Refus du joueur'), findsOneWidget);

      final action = _approveAction(tester);
      expect(action.enabled, isFalse);
      expect(action.tooltip, contains('a refusé la publication'));
    });

    testWidgets('un accord donne rend la decision possible', (tester) async {
      await _pumpReviewQueue(
        tester,
        videos: [
          _pendingVideo(
            id: 'v1',
            uid: 'club-1',
            playerUid: 'player-1',
            consentRequired: true,
            consentDecision: 'accepted',
            consentAt: DateTime(2026, 11, 17),
          ),
        ],
      );

      expect(find.text('Prête à publier'), findsOneWidget);

      final action = _approveAction(tester);
      expect(action.enabled, isTrue);
      expect(action.tooltip, 'Approuver');
    });

    testWidgets('une video deposee par le joueur reste decidable', (
      tester,
    ) async {
      await _pumpReviewQueue(
        tester,
        videos: [_pendingVideo(id: 'v1', uid: 'player-1')],
      );

      expect(find.text('Prête à publier'), findsOneWidget);
      expect(find.textContaining('Déposée par'), findsNothing);
      expect(_approveAction(tester).enabled, isTrue);
    });

    testWidgets('« pretes a decider » exclut ce que le serveur refuserait', (
      tester,
    ) async {
      await _pumpReviewQueue(
        tester,
        videos: [
          _pendingVideo(id: 'v1', uid: 'player-1'),
          _pendingVideo(
            id: 'v2',
            uid: 'club-1',
            playerUid: 'player-1',
            consentRequired: true,
          ),
          _pendingVideo(
            id: 'v3',
            uid: 'club-1',
            playerUid: 'player-1',
            consentRequired: true,
            consentDecision: 'refused',
          ),
        ],
      );

      // Trois en attente, une seule decidable : compter les trois aurait
      // annonce un travail disponible qui n'existe pas.
      expect(find.text('prêtes à décider'), findsOneWidget);
      expect(find.text('accord attendu'), findsOneWidget);
      expect(find.text('refus du joueur'), findsOneWidget);

      final strip = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .toList();
      expect(strip, contains('3'));
      expect(strip, contains('1'));
    });
  });
}
