// Nouveau constat traité le 2026-11-06, demandé explicitement par
// l'utilisateur : deconnexion automatique apres 15 minutes d'inactivite,
// avec avertissement avant. Verrouille le minutage exact (avertissement a
// 14 min, limite a 15 min) et les trois issues possibles (timeout,
// "rester connecte", activite qui repousse l'avertissement).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:show_talent/services/inactivity_service.dart';

void main() {
  late int timeoutCount;

  Future<void> start(WidgetTester tester) async {
    timeoutCount = 0;
    await tester.pumpWidget(
      GetMaterialApp(home: const Scaffold(body: SizedBox.shrink())),
    );
    InactivityService.instance.start(
      onTimeout: () async {
        timeoutCount += 1;
      },
    );
  }

  tearDown(() {
    InactivityService.instance.stop();
  });

  testWidgets(
    'sans aucune activite, l avertissement apparait a 14 minutes et le timeout a 15',
    (tester) async {
      await start(tester);

      await tester.pump(
        InactivityService.idleTimeout - InactivityService.warningLeadTime,
      );
      await tester.pumpAndSettle();

      expect(find.text('Inactivité détectée'), findsOneWidget);
      expect(timeoutCount, 0);

      await tester.pump(InactivityService.warningLeadTime);
      await tester.pumpAndSettle();

      expect(timeoutCount, 1);
      expect(find.text('Inactivité détectée'), findsNothing);
    },
  );

  testWidgets(
    'rester connecte annule le compte a rebours et relance un cycle complet',
    (tester) async {
      await start(tester);

      await tester.pump(
        InactivityService.idleTimeout - InactivityService.warningLeadTime,
      );
      await tester.pumpAndSettle();
      expect(find.text('Rester connecté'), findsOneWidget);

      await tester.tap(find.text('Rester connecté'));
      await tester.pumpAndSettle();

      expect(timeoutCount, 0);
      expect(find.text('Inactivité détectée'), findsNothing);

      // Le cycle repart de zero : rien a 14 minutes pile apres le clic.
      await tester.pump(
        InactivityService.idleTimeout - InactivityService.warningLeadTime,
      );
      await tester.pumpAndSettle();
      expect(find.text('Inactivité détectée'), findsOneWidget);
    },
  );

  testWidgets('une activite avant le seuil repousse l avertissement', (
    tester,
  ) async {
    await start(tester);

    await tester.pump(const Duration(minutes: 13));
    InactivityService.instance.registerActivity();

    // Sans l'activite, l'avertissement serait du a la minute 14. Avec
    // elle, il ne doit apparaitre qu'a 14 minutes APRES le reset.
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.text('Inactivité détectée'), findsNothing);

    await tester.pump(const Duration(minutes: 13));
    await tester.pumpAndSettle();
    expect(find.text('Inactivité détectée'), findsOneWidget);
  });

  testWidgets('stop annule tout minuteur en cours sans effet', (tester) async {
    await start(tester);

    await tester.pump(const Duration(minutes: 5));
    InactivityService.instance.stop();

    await tester.pump(const Duration(minutes: 15));
    await tester.pumpAndSettle();

    expect(timeoutCount, 0);
    expect(find.text('Inactivité détectée'), findsNothing);
  });
}
