import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/dashboard/user_management_widget.dart';
import 'package:show_talent/models/membership.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/services/managed_account_service.dart';
import 'package:show_talent/utils/admin_callable_action_catalog.dart';

import 'test_support/admin_test_helpers.dart';

void main() {
  group('Membership', () {
    test('reads the tiers the callable accepts and ignores the rest', () {
      expect(Membership.parseTier('adfoot'), MembershipTier.adfoot);
      expect(Membership.parseTier('external'), MembershipTier.external);
      expect(Membership.parseTier('externe'), MembershipTier.external);
      expect(Membership.parseTier('premium'), MembershipTier.none);
      expect(Membership.parseTier(null), MembershipTier.none);
    });

    test('a malformed map yields no entitlement instead of throwing', () {
      expect(Membership.fromMap('adfoot').tier, MembershipTier.none);
      expect(Membership.fromMap(<String, dynamic>{}).tier, MembershipTier.none);
    });

    test('an entitlement without a term never lapses', () {
      const membership = Membership(tier: MembershipTier.adfoot);
      final farFuture = DateTime(2100);

      expect(membership.isActiveAt(farFuture), isTrue);
      expect(membership.isLapsedAt(farFuture), isFalse);
    });

    test('an unrecorded account is not a lapsed one', () {
      final now = DateTime(2026, 8, 30);

      expect(Membership.none.isActiveAt(now), isFalse);
      expect(Membership.none.isLapsedAt(now), isFalse);
    });

    test('a past term is lapsed, not active', () {
      final membership = Membership(
        tier: MembershipTier.external,
        validUntil: DateTime(2026, 1, 1),
      );
      final now = DateTime(2026, 8, 30);

      expect(membership.isActiveAt(now), isFalse);
      expect(membership.isLapsedAt(now), isTrue);
    });
  });

  group('AppUser', () {
    test('reads the membership map written by the admin callable', () {
      final user = AppUser.fromMap(<String, dynamic>{
        'uid': 'player-1',
        'nom': 'Adama',
        'role': 'joueur',
        'membership': <String, dynamic>{
          'tier': 'adfoot',
          'startedAt': Timestamp.fromDate(DateTime(2026, 5, 4)),
          'validUntil': null,
          'reference': 'contrat 2026-014',
        },
      });

      expect(user.membership.tier, MembershipTier.adfoot);
      expect(user.membership.startedAt, DateTime(2026, 5, 4));
      expect(user.membership.validUntil, isNull);
      expect(user.membership.reference, 'contrat 2026-014');
    });

    test('the entitlement survives a toMap/fromMap round trip', () {
      final source = buildTestUser(
        uid: 'player-1',
        nom: 'Adama',
        email: 'adama@example.com',
        role: 'joueur',
        createdByAdmin: true,
        membership: Membership(
          tier: MembershipTier.external,
          validUntil: DateTime(2027, 3, 1),
          reference: 'recu 1287',
        ),
      );

      // fetchUserWithPrivateFields rebuilds the user from toMap(): an
      // entitlement dropped there would vanish from the review dialog.
      final rebuilt = AppUser.fromMap(source.toMap());

      expect(rebuilt.membership.tier, MembershipTier.external);
      expect(rebuilt.membership.validUntil, DateTime(2027, 3, 1));
      expect(rebuilt.membership.reference, 'recu 1287');
    });

    test('the entitlement never leaks into an embedded copy', () {
      final user = buildTestUser(
        uid: 'player-1',
        nom: 'Adama',
        email: 'adama@example.com',
        role: 'joueur',
        membership: const Membership(tier: MembershipTier.adfoot),
      );

      expect(user.toEmbeddedMap().containsKey('membership'), isFalse);
    });
  });

  group('ManagedAccountService.setManagedAccountMembership', () {
    ManagedAccountService buildService(List<Map<String, dynamic>> calls) {
      return ManagedAccountService(
        callableExecutor: (callableName, payload) async {
          calls.add({'callableName': callableName, 'payload': payload});
          return <String, dynamic>{'success': true};
        },
      );
    }

    test('sends the tier, the term and the reference', () async {
      final calls = <Map<String, dynamic>>[];
      final validUntil = DateTime.now().add(const Duration(days: 200));

      await buildService(calls).setManagedAccountMembership(
        uid: 'player-1',
        tier: MembershipTier.external,
        validUntil: validUntil,
        reference: '  recu 1287  ',
      );

      expect(calls, hasLength(1));
      expect(calls.single['callableName'], 'setManagedAccountMembership');
      expect(calls.single['payload'], {
        'uid': 'player-1',
        'tier': 'external',
        'validUntil': validUntil.toUtc().toIso8601String(),
        'reference': 'recu 1287',
      });
    });

    test('an agency player is recorded without a term', () async {
      final calls = <Map<String, dynamic>>[];

      await buildService(calls).setManagedAccountMembership(
        uid: 'player-1',
        tier: MembershipTier.adfoot,
      );

      expect(calls.single['payload'], {'uid': 'player-1', 'tier': 'adfoot'});
    });

    test('clearing sends nothing but the tier', () async {
      final calls = <Map<String, dynamic>>[];

      await buildService(calls).clearManagedAccountMembership(uid: 'player-1');

      expect(calls.single['payload'], {'uid': 'player-1', 'tier': 'none'});
    });

    test('a term in the past is refused before the call leaves', () async {
      final calls = <Map<String, dynamic>>[];

      expect(
        () => buildService(calls).setManagedAccountMembership(
          uid: 'player-1',
          tier: MembershipTier.adfoot,
          validUntil: DateTime(2020),
        ),
        throwsArgumentError,
      );
      expect(calls, isEmpty);
    });

    test('an empty uid is refused before the call leaves', () async {
      final calls = <Map<String, dynamic>>[];

      expect(
        () => buildService(calls).setManagedAccountMembership(
          uid: '   ',
          tier: MembershipTier.adfoot,
        ),
        throwsArgumentError,
      );
      expect(calls, isEmpty);
    });
  });

  group('catalogue des actions', () {
    test('the membership callable is listed and wired', () {
      expect(
        adminCallableActions.map((action) => action.callableName),
        contains('setManagedAccountMembership'),
      );
      expect(setManagedAccountMembershipAction.isConnectedInUi, isTrue);
      expect(
        connectedAdminCallableActions,
        contains(setManagedAccountMembershipAction),
      );
    });
  });

  group('UserManagementWidget', () {
    Future<void> openActionMenu(WidgetTester tester) async {
      final actionMenu = find.byType(PopupMenuButton<String>);
      await tester.ensureVisible(actionMenu);
      await tester.tap(actionMenu);
      await tester.pumpAndSettle();
    }

    testWidgets('a managed account can have its entitlement recorded',
        (tester) async {
      final calls = <Map<String, dynamic>>[];
      final service = ManagedAccountService(
        callableExecutor: (callableName, payload) async {
          calls.add({'callableName': callableName, 'payload': payload});
          return <String, dynamic>{'success': true};
        },
      );
      final controller = TestUserController(
        users: [
          buildTestUser(
            uid: 'player-1',
            nom: 'Adama',
            email: 'adama@example.com',
            role: 'joueur',
            createdByAdmin: true,
          ),
        ],
      );

      await pumpAdminTestApp(
        tester,
        UserManagementWidget(
          selectedRole: 'Tous',
          userController: controller,
          managedAccountService: service,
        ),
      );
      await tester.pumpAndSettle();

      await openActionMenu(tester);
      await tester.tap(find.text('Gérer les droits'));
      await tester.pumpAndSettle();

      final tierDropdown = find.byType(DropdownButtonFormField<MembershipTier>);
      expect(tierDropdown, findsOneWidget);
      await tester.tap(tierDropdown);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(Membership.tierLabelOf(MembershipTier.adfoot)).last,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single['callableName'], 'setManagedAccountMembership');
      expect(calls.single['payload'], {'uid': 'player-1', 'tier': 'adfoot'});
    });

    testWidgets('an unchanged entitlement is not written again',
        (tester) async {
      final calls = <Map<String, dynamic>>[];
      final service = ManagedAccountService(
        callableExecutor: (callableName, payload) async {
          calls.add({'callableName': callableName, 'payload': payload});
          return <String, dynamic>{'success': true};
        },
      );
      final controller = TestUserController(
        users: [
          buildTestUser(
            uid: 'player-1',
            nom: 'Adama',
            email: 'adama@example.com',
            role: 'joueur',
            createdByAdmin: true,
            membership: const Membership(tier: MembershipTier.adfoot),
          ),
        ],
      );

      await pumpAdminTestApp(
        tester,
        UserManagementWidget(
          selectedRole: 'Tous',
          userController: controller,
          managedAccountService: service,
        ),
      );
      await tester.pumpAndSettle();

      await openActionMenu(tester);
      await tester.tap(find.text('Gérer les droits'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('a portal-only account is never offered the action',
        (tester) async {
      final controller = TestUserController(
        users: [
          buildTestUser(
            uid: 'admin-1',
            nom: 'Admin Adfoot',
            email: 'admin@example.com',
            role: 'admin',
            createdByAdmin: true,
          ),
        ],
      );

      await pumpAdminTestApp(
        tester,
        UserManagementWidget(
          selectedRole: 'Tous',
          userController: controller,
          managedAccountService: ManagedAccountService(
            callableExecutor: (callableName, payload) async =>
                <String, dynamic>{'success': true},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openActionMenu(tester);

      expect(find.text('Gérer les droits'), findsNothing);
    });
  });
}
