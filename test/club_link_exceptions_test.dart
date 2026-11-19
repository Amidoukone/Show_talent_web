// Les garde-fous de la file des exceptions de rattachement.
//
// Trois situations gelent un rattachement en attendant une decision humaine,
// et aucune ne se debloque toute seule. Ces tests exercent l'appelant : la
// charge utile reellement envoyee, l'onglet reellement monte, et les trois
// vues reellement deduites d'un seul flux.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:show_talent/config/app_environment.dart';
import 'package:show_talent/config/app_routes.dart';
import 'package:show_talent/controller/club_link_controller.dart';
import 'package:show_talent/dashboard/club_link_exceptions_widget.dart';
import 'package:show_talent/models/player_club_link.dart';
import 'package:show_talent/services/admin_content_service.dart';
import 'package:show_talent/utils/admin_callable_action_catalog.dart';

import 'test_support/admin_test_helpers.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _MockHttpsCallable extends Mock implements HttpsCallable {}

class _MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<dynamic> {}

class _MockFirestore extends Mock implements FirebaseFirestore {}

/// Un controleur qui n'ouvre aucun flux Firestore.
class _SeededClubLinkController extends ClubLinkController {
  _SeededClubLinkController({
    List<PlayerClubLink> seeded = const <PlayerClubLink>[],
    bool more = false,
  }) : super(
         firestore: _MockFirestore(),
         adminContentService: AdminContentService.visualQa(),
       ) {
    openLinks.assignAll(seeded);
    hasMore.value = more;
    isLoading.value = false;
  }

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> refreshLinks() async {}
}

/// Un rattachement, construit par la porte de production.
///
/// `PlayerClubLink.fromMap` plutot qu'un constructeur direct : la forme des
/// cles est precisement ce qui doit rester aligne sur `club_links.ts`.
PlayerClubLink _link({
  required String id,
  required String playerUid,
  required String clubUid,
  String clubName = 'Académie Abidjan Nord',
  String status = PlayerClubLink.statusDeclared,
  DateTime? declaredAt,
  DateTime? contestedAt,
  String? contestReason,
  bool reviewRequired = false,
  String? reviewReason,
  DateTime? reviewRequestedAt,
  String? revocationReason,
  String? agreementRef = 'ACCORD-2026-011',
  Map<String, dynamic>? declaredFacts,
  Map<String, dynamic>? confirmedFacts,
  Map<String, dynamic>? corrections,
}) {
  return PlayerClubLink.fromMap(<String, dynamic>{
    'id': id,
    'playerUid': playerUid,
    'clubUid': clubUid,
    'clubName': clubName,
    'status': status,
    'declaredUnderAgreementRef': ?agreementRef,
    'declaredAt': Timestamp.fromDate(declaredAt ?? DateTime(2026, 10, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 11, 18)),
    'contestedAt': ?(contestedAt == null
        ? null
        : Timestamp.fromDate(contestedAt)),
    'contestReason': ?contestReason,
    if (reviewRequired) 'reviewRequired': true,
    'reviewReason': ?reviewReason,
    'reviewRequestedAt': ?(reviewRequestedAt == null
        ? null
        : Timestamp.fromDate(reviewRequestedAt)),
    'revocationReason': ?revocationReason,
    'declaredFacts': ?declaredFacts,
    'confirmedFacts': ?confirmedFacts,
    'corrections': ?corrections,
  });
}

Future<void> _pumpExceptions(
  WidgetTester tester, {
  required List<PlayerClubLink> links,
  bool more = false,
}) async {
  final controller = _SeededClubLinkController(seeded: links, more: more);
  addTearDown(controller.onClose);

  await pumpAdminTestApp(
    tester,
    ClubLinkExceptionsWidget(
      controller: controller,
      userController: TestUserController(
        users: [
          buildTestUser(
            uid: 'player-1',
            nom: 'Mamadou Diabaté',
            email: 'joueur@exemple.test',
            role: 'joueur',
          ),
          buildTestUser(
            uid: 'club-1',
            nom: 'Académie Abidjan Nord',
            email: 'club@exemple.test',
            role: 'club',
          ),
        ],
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('modele de rattachement', () {
    test('les noms de champs du depot mobile sont lus tels quels', () {
      final link = _link(
        id: 'l1',
        playerUid: 'player-1',
        clubUid: 'club-1',
        status: PlayerClubLink.statusContested,
        contestedAt: DateTime.utc(2026, 11, 10, 8),
        contestReason: 'Je ne suis plus dans ce club.',
        declaredFacts: <String, dynamic>{
          'positionCodes': ['ST'],
          'nationalities': ['CI'],
          'strongFoot': 'right',
          'currentClubLevel': 'academy',
          'heightCm': 180,
          'weightKg': 74,
        },
      );

      expect(link.id, 'l1');
      expect(link.clubName, 'Académie Abidjan Nord');
      expect(link.status, PlayerClubLink.statusContested);
      expect(link.isContested, isTrue);
      expect(link.isOpen, isTrue);
      expect(link.contestReason, 'Je ne suis plus dans ce club.');
      expect(link.declaredUnderAgreementRef, 'ACCORD-2026-011');
      expect(link.contestedAt!.toUtc(), DateTime.utc(2026, 11, 10, 8));
      expect(link.declaredFacts['heightCm'], 180);
      expect(link.statusLabel, 'Contesté');
    });

    test('un etat inconnu est montre tel quel, pas traduit au hasard', () {
      final link = _link(
        id: 'l1',
        playerUid: 'p',
        clubUid: 'c',
        status: 'escalated',
      );

      expect(link.statusLabel, 'escalated');
      expect(link.isOpen, isFalse);
    });

    test('un reexamen reconnait la revocation d habilitation', () {
      final link = _link(
        id: 'l1',
        playerUid: 'player-1',
        clubUid: 'club-1',
        status: PlayerClubLink.statusConfirmed,
        reviewRequired: true,
        reviewReason: PlayerClubLink.reasonEnrollmentRevoked,
        revocationReason: 'Accord non renouvelé',
      );

      expect(link.reviewRequired, isTrue);
      expect(link.reviewFollowsRevocation, isTrue);
      expect(link.revocationReason, 'Accord non renouvelé');
    });

    group('date de l exception', () {
      test('une contestation est datee de la contestation', () {
        final link = _link(
          id: 'l1',
          playerUid: 'p',
          clubUid: 'c',
          status: PlayerClubLink.statusContested,
          declaredAt: DateTime(2026, 5, 1),
          contestedAt: DateTime(2026, 11, 10),
        );

        expect(link.exceptionRaisedAt, DateTime(2026, 11, 10));
      });

      test(
        'un reexamen est date de la demande, pas de la derniere ecriture',
        () {
          // `updatedAt` bouge a chaque passage de la cascade de revocation, y
          // compris sur des dossiers que personne n'a touches : trier dessus
          // ferait remonter des dossiers anciens comme s'ils venaient d'arriver.
          final link = _link(
            id: 'l1',
            playerUid: 'p',
            clubUid: 'c',
            status: PlayerClubLink.statusConfirmed,
            declaredAt: DateTime(2026, 2, 1),
            reviewRequired: true,
            reviewRequestedAt: DateTime(2026, 9, 3),
          );

          expect(link.exceptionRaisedAt, DateTime(2026, 9, 3));
        },
      );

      test('une declaration simple est datee de la declaration', () {
        final link = _link(
          id: 'l1',
          playerUid: 'p',
          clubUid: 'c',
          declaredAt: DateTime(2026, 7, 7),
        );

        expect(link.exceptionRaisedAt, DateTime(2026, 7, 7));
      });
    });

    group('faits declares', () {
      test('les codes partages sont rendus en francais', () {
        final described = describeClubLinkFacts(<String, dynamic>{
          'positionCodes': ['ST'],
          'nationalities': ['CI'],
          'strongFoot': 'right',
          'currentClubLevel': 'academy',
          'heightCm': 180,
          'weightKg': 74,
        });

        // Un operateur ne doit pas avoir a connaitre « ST », « CI » et
        // « academy » pour arbitrer un litige.
        expect(described, contains('Postes : '));
        expect(described, contains('Taille : 180 cm'));
        expect(described, contains('Poids : 74 kg'));
        expect(described, isNot(contains('academy')));
        expect(described, isNot(contains('positionCodes')));
      });

      test('une cle inconnue s affiche plutot que de disparaitre', () {
        // Les six cles retenues sont celles de `sanitizeDeclaredFacts` : une
        // cle inconnue vient d'une ecriture qui a contourne le callable, et la
        // passer sous silence serait exactement le defaut a eviter.
        final described = describeClubLinkFacts(<String, dynamic>{
          'champInconnu': 'valeur',
        });

        expect(described, contains('champInconnu : valeur'));
      });

      test('une carte vide ne produit rien', () {
        expect(describeClubLinkFacts(const <String, dynamic>{}), '');
      });
    });
  });

  group('detection des doublons', () {
    test('deux rattachements ouverts sur le meme joueur sont reperes', () {
      // Aucune requete Firestore ne sait exprimer « deux documents partagent
      // une valeur » : cela se voit en lisant la collection.
      final controller = _SeededClubLinkController(
        seeded: [
          _link(id: 'l1', playerUid: 'player-1', clubUid: 'club-1'),
          _link(id: 'l2', playerUid: 'player-1', clubUid: 'club-2'),
          _link(id: 'l3', playerUid: 'player-2', clubUid: 'club-1'),
          _link(id: 'l4', playerUid: '', clubUid: 'club-3'),
        ],
      );
      addTearDown(controller.onClose);

      expect(controller.duplicatedPlayerUids, {'player-1'});
    });

    test('aucun doublon quand chaque joueur n a qu un rattachement', () {
      final controller = _SeededClubLinkController(
        seeded: [
          _link(id: 'l1', playerUid: 'player-1', clubUid: 'club-1'),
          _link(id: 'l2', playerUid: 'player-2', clubUid: 'club-2'),
        ],
      );
      addTearDown(controller.onClose);

      expect(controller.duplicatedPlayerUids, isEmpty);
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
        'code': 'club_link_ended',
        'message': 'Rattachement clos et conserve en historique.',
      });
      when(() => callable.call(any())).thenAnswer((_) async => result);
    });

    test('la cloture envoie le seul identifiant du rattachement', () async {
      final response = await service.endClubLink(linkId: ' link-1 ');

      expect(response.success, isTrue);
      verify(() => functions.httpsCallable('endClubLink')).called(1);
      verify(
        () => callable.call(<String, dynamic>{'linkId': 'link-1'}),
      ).called(1);
    });

    test('un identifiant vide ne part jamais sur le reseau', () async {
      final response = await service.endClubLink(linkId: '   ');

      expect(response.success, isFalse);
      expect(response.code, 'invalid_link_id');
      verifyNever(() => callable.call(any()));
    });
  });

  group('accessibilite de la surface', () {
    test('le catalogue porte l entree, raccordee a une interface', () {
      final entry = adminCallableActions.firstWhere(
        (action) => action.callableName == 'endClubLink',
      );

      expect(entry.isAvailableInBackend, isTrue);
      expect(entry.isConnectedInUi, isTrue);
      expect(entry.uiSurfaces, contains('ClubLinkExceptionsWidget'));
    });

    test('l onglet est monte a la position que les liens profonds visent', () {
      // Meme raison que pour la surface des pieces : la position EST le
      // contrat, les deux listes etant indexees dessus.
      expect(dashboardItemIndex('Rattachements'), 10);
      expect(dashboardScreenIndex('ClubLinkExceptionsWidget'), 10);
      expect(dashboardGroupIndices('Modération'), contains(10));

      // Et l'onglet precedent n'a pas bouge : un ajout se fait en fin de
      // liste, jamais au milieu.
      expect(dashboardItemIndex('Statuts contractuels'), 9);
    });

    test('le lien profond resout vers le dernier onglet', () {
      for (final slug in const <String>['club-links', 'rattachements']) {
        expect(
          AppRoutes.resolveDashboardInitialIndex(
            environment: AppEnvironment.local,
            uri: Uri.parse('http://localhost:8080/#/admin-dashboard?tab=$slug'),
          ),
          10,
          reason: 'le lien profond « $slug » doit ouvrir la file',
        );
      }
    });

    test('le controleur est enregistre par la liaison du tableau de bord', () {
      expect(
        File('lib/config/app_page_bindings.dart').readAsStringSync(),
        contains('ClubLinkController'),
      );
    });
  });

  group('ecran des exceptions', () {
    testWidgets('une contestation est listee avec son motif', (tester) async {
      await _pumpExceptions(
        tester,
        links: [
          _link(
            id: 'l1',
            playerUid: 'player-1',
            clubUid: 'club-1',
            status: PlayerClubLink.statusContested,
            contestedAt: DateTime.now().subtract(const Duration(days: 4)),
            contestReason: 'Je ne suis plus dans ce club.',
          ),
        ],
      );

      expect(find.text('Mamadou Diabaté'), findsOneWidget);
      expect(find.text('Académie Abidjan Nord'), findsOneWidget);
      expect(find.text('Contestation'), findsOneWidget);
      expect(find.text('Contesté'), findsOneWidget);
      expect(find.text('4 j'), findsOneWidget);
    });

    testWidgets('un rattachement sans exception ne remplit pas la file', (
      tester,
    ) async {
      // La vue par defaut est celle des exceptions : une declaration qui suit
      // son cours n'y a pas sa place, sinon la file cesse d'etre une file.
      await _pumpExceptions(
        tester,
        links: [
          _link(id: 'l1', playerUid: 'player-1', clubUid: 'club-1'),
          _link(
            id: 'l2',
            playerUid: 'player-2',
            clubUid: 'club-1',
            status: PlayerClubLink.statusConfirmed,
          ),
        ],
      );

      expect(find.text('Aucune exception à trancher'), findsOneWidget);
    });

    testWidgets('un doublon apparait sur les deux rattachements', (
      tester,
    ) async {
      await _pumpExceptions(
        tester,
        links: [
          _link(
            id: 'l1',
            playerUid: 'player-1',
            clubUid: 'club-1',
            clubName: 'Académie Abidjan Nord',
          ),
          _link(
            id: 'l2',
            playerUid: 'player-1',
            clubUid: 'club-2',
            clubName: 'Stade de Bouaké',
          ),
        ],
      );

      expect(find.text('Doublon'), findsNWidgets(2));
      expect(find.text('Académie Abidjan Nord'), findsOneWidget);
      expect(find.text('Stade de Bouaké'), findsOneWidget);
    });

    testWidgets('la fiche d un doublon montre l autre rattachement', (
      tester,
    ) async {
      // Un doublon ne se tranche pas autrement : l'operateur a besoin de voir
      // les deux declarations pour decider laquelle est de trop.
      await _pumpExceptions(
        tester,
        links: [
          _link(id: 'l1', playerUid: 'player-1', clubUid: 'club-1'),
          _link(
            id: 'l2',
            playerUid: 'player-1',
            clubUid: 'club-2',
            clubName: 'Stade de Bouaké',
          ),
        ],
      );

      await tester.tap(find.text('Doublon').first);
      await tester.pumpAndSettle();

      // `AdminDetailSection` met son intitule en capitales.
      expect(find.text('DOUBLON : 1 AUTRE(S) RATTACHEMENT(S)'), findsOneWidget);
      // Et il nomme l'autre club, qui est ce que l'operateur vient lire.
      expect(find.text('Stade de Bouaké'), findsOneWidget);
    });

    testWidgets('une fenetre incomplete le dit avant de conclure', (
      tester,
    ) async {
      // Tant que la fenetre n'est pas complete, deux rattachements d'un meme
      // joueur peuvent tomber dans deux pages et le compteur sous-estime.
      await _pumpExceptions(
        tester,
        links: [
          _link(
            id: 'l1',
            playerUid: 'player-1',
            clubUid: 'club-1',
            status: PlayerClubLink.statusContested,
            contestedAt: DateTime.now(),
          ),
        ],
        more: true,
      );

      expect(find.text('Détection des doublons partielle'), findsOneWidget);
    });

    testWidgets('la cloture demande confirmation et dit ce qu elle change', (
      tester,
    ) async {
      await _pumpExceptions(
        tester,
        links: [
          _link(
            id: 'l1',
            playerUid: 'player-1',
            clubUid: 'club-1',
            status: PlayerClubLink.statusContested,
            contestedAt: DateTime.now(),
          ),
        ],
      );

      await tester.tap(find.byIcon(Icons.link_off_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Clore le rattachement'), findsOneWidget);
      expect(
        find.textContaining('Ses faits sportifs lui restent'),
        findsOneWidget,
      );
      expect(
        find.textContaining('seul le joueur peut confirmer le sien'),
        findsOneWidget,
      );

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Contestation'), findsOneWidget);
    });
  });
}
