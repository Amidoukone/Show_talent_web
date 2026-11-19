// L'etat d'habilitation lisible sans ouvrir la ligne.
//
// `user_management_widget` changeait deja l'intitule de l'action selon
// `clubEnrollment.active`, mais rien n'affichait l'etat ni son terme : reperer
// un club dont l'habilitation expire demandait d'ouvrir chaque ligne, ce
// qu'une liste existe precisement pour eviter.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/models/club_enrollment.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/theme/admin_theme.dart';
import 'package:show_talent/widgets/admin_account_status_chips.dart';

import 'test_support/admin_test_helpers.dart';

/// Un compte club porteur d'une habilitation, par la porte de production.
AppUser _club({
  DateTime? validUntil,
  String? agreementRef = 'ACCORD-2026-011',
  bool granted = true,
  Map<String, dynamic>? membership,
}) {
  return AppUser.fromMap(<String, dynamic>{
    'uid': 'club-1',
    'nom': 'Académie Abidjan Nord',
    'role': 'club',
    'emailVerified': true,
    'dateInscription': DateTime(2026, 1, 1),
    'dernierLogin': DateTime(2026, 11, 18),
    'membership': ?membership,
    'clubEnrollment': ?(granted
        ? <String, dynamic>{
            'grantedAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
            'validUntil': ?(validUntil == null
                ? null
                : Timestamp.fromDate(validUntil)),
            'agreementRef': ?agreementRef,
          }
        : null),
  });
}

/// Les couleurs des fragments de la ligne secondaire, dans l'ordre.
List<Color?> _secondaryColors(WidgetTester tester) {
  final rich = tester.widget<Text>(
    find.byWidgetPredicate(
      (widget) => widget is Text && widget.textSpan != null,
    ),
  );
  final colors = <Color?>[];
  rich.textSpan!.visitChildren((span) {
    if (span is TextSpan && (span.text ?? '').trim().isNotEmpty) {
      colors.add(span.style?.color);
    }
    return true;
  });
  return colors;
}

Future<void> _pumpChips(WidgetTester tester, AppUser user) async {
  await pumpAdminTestApp(
    tester,
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 220, child: AdminAccountStatusChips(user: user)),
    ),
  );
  await tester.pump();
}

void main() {
  group('modele d habilitation', () {
    test('une echeance proche est signalee, une echeance lointaine non', () {
      final now = DateTime(2026, 11, 19);

      final soon = ClubEnrollment(
        granted: true,
        validUntil: now.add(const Duration(days: 10)),
      );
      final later = ClubEnrollment(
        granted: true,
        validUntil: now.add(const Duration(days: 200)),
      );

      expect(soon.expiresSoon(now: now), isTrue);
      expect(later.expiresSoon(now: now), isFalse);
    });

    test('une habilitation echue n est pas « bientot echue »', () {
      // Les deux etats ne demandent pas la meme chose : l'un un
      // renouvellement a preparer, l'autre un renouvellement en retard. Les
      // confondre ferait disparaitre l'urgence derriere une alerte douce.
      final now = DateTime(2026, 11, 19);
      final expired = ClubEnrollment(
        granted: true,
        validUntil: now.subtract(const Duration(days: 1)),
      );

      expect(expired.expired, isTrue);
      expect(expired.expiresSoon(now: now), isFalse);
      expect(expired.statusLabel, 'Habilitation échue');
    });

    test('un club jamais habilite ne declenche aucune alerte', () {
      expect(ClubEnrollment.absent.granted, isFalse);
      expect(ClubEnrollment.absent.expired, isFalse);
      expect(ClubEnrollment.absent.expiresSoon(), isFalse);
      expect(ClubEnrollment.absent.statusLabel, 'Non habilité');
    });

    test('un terme illisible vaut echu, comme sur le serveur', () {
      // Un document a moitie ecrit ne doit pas valoir autorisation.
      const halfWritten = ClubEnrollment(granted: true);

      expect(halfWritten.expired, isTrue);
      expect(halfWritten.active, isFalse);
      expect(halfWritten.expiresSoon(), isFalse);
    });
  });

  group('repere de statut', () {
    testWidgets('le terme est lisible sans ouvrir la ligne', (tester) async {
      final validUntil = DateTime.now().add(const Duration(days: 300));

      await _pumpChips(tester, _club(validUntil: validUntil));

      expect(find.text('Actif'), findsOneWidget);
      expect(
        find.textContaining('Habilité jusqu’au'),
        findsOneWidget,
        reason: 'le terme est ce qu on vient lire, pas seulement l etat',
      );
      expect(_secondaryColors(tester), [AdminTheme.textSecondary]);
    });

    testWidgets('une echeance proche passe en avertissement', (tester) async {
      final validUntil = DateTime.now().add(const Duration(days: 9));

      await _pumpChips(tester, _club(validUntil: validUntil));

      expect(_secondaryColors(tester), [AdminTheme.warning]);
    });

    testWidgets('une habilitation echue le dit en clair', (tester) async {
      final validUntil = DateTime.now().subtract(const Duration(days: 2));

      await _pumpChips(tester, _club(validUntil: validUntil));

      expect(find.text('Habilitation échue'), findsOneWidget);
      expect(_secondaryColors(tester), [AdminTheme.warning]);
    });

    testWidgets('un club jamais habilite n affiche aucun second plan', (
      tester,
    ) async {
      // La tres grande majorite des comptes clubs sont dans ce cas : le dire
      // sur chaque ligne ne renseignerait personne.
      await _pumpChips(tester, _club(granted: false));

      expect(find.text('Actif'), findsOneWidget);
      expect(find.textContaining('Habilité'), findsNothing);
      expect(find.textContaining('Non habilité'), findsNothing);
    });

    testWidgets('abonnement et habilitation tiennent sur une seule ligne', (
      tester,
    ) async {
      // La ligne du tableau fait AdminTheme.tableRowHeight : un troisieme
      // niveau de texte en deborderait sans rien signaler.
      await _pumpChips(
        tester,
        _club(
          validUntil: DateTime.now().add(const Duration(days: 300)),
          membership: <String, dynamic>{
            'tier': 'external',
            'startedAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
            'validUntil': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 300)),
            ),
          },
        ),
      );

      final rich = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.textSpan != null,
        ),
      );
      expect(rich.maxLines, 1);
      expect(rich.overflow, TextOverflow.ellipsis);
      expect(rich.textSpan!.toPlainText(), contains(' · '));
      expect(rich.textSpan!.toPlainText(), contains('Habilité jusqu’au'));

      expect(tester.takeException(), isNull);
    });
  });
}
