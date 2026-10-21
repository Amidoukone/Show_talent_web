import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:show_talent/controller/video_controller.dart';
import 'package:show_talent/dashboard/statistiques_screen.dart';
import 'package:show_talent/services/admin_content_service.dart';
import 'package:show_talent/theme/admin_theme.dart';

import 'test_support/admin_test_helpers.dart';

void main() {
  testWidgets('statistics overview stays usable on a narrow viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1100);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      Get.reset();
    });

    final userController = TestUserController(
      users: [
        buildTestUser(
          uid: 'player-1',
          nom: 'Player One',
          email: 'player@example.com',
          role: 'joueur',
          createdByAdmin: true,
        ),
        buildTestUser(
          uid: 'club-1',
          nom: 'Club One',
          email: 'club@example.com',
          role: 'club',
          createdByAdmin: true,
          authDisabled: true,
        ),
      ],
    );
    final videoController = VideoController(
      adminContentService: AdminContentService.visualQa(),
    );
    videoController.isLoading.value = false;

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AdminTheme.buildTheme(),
        home: Scaffold(
          // L'écran gère son propre défilement depuis la refonte : la
          // coquille lui donne une hauteur bornée et il scrolle dedans.
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StatisticsOverviewPanel(
              userController: userController,
              videoController: videoController,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Utilisateurs'), findsWidgets);
    expect(find.text('Activité globale'), findsOneWidget);
    expect(find.text('Signaux clés'), findsOneWidget);
  });

  test(
    'admin responsive surfaces keep shared production layout guardrails',
    () {
      final adminUi = File('lib/widgets/admin_ui.dart').readAsStringSync();
      final videosAdded = File(
        'lib/dashboard/video_added_widget.dart',
      ).readAsStringSync();
      final videosReview = File(
        'lib/dashboard/video_review_widget.dart',
      ).readAsStringSync();
      final videosReported = File(
        'lib/dashboard/video_reported_widget.dart',
      ).readAsStringSync();
      final offers = File(
        'lib/dashboard/offer_management_widget.dart',
      ).readAsStringSync();
      final events = File(
        'lib/dashboard/event_management_widget.dart',
      ).readAsStringSync();
      final contactIntakes = File(
        'lib/dashboard/contact_intake_management_widget.dart',
      ).readAsStringSync();
      final statistics = File(
        'lib/dashboard/statistiques_screen.dart',
      ).readAsStringSync();

      expect(adminUi, contains('class AdminToolbar'));
      expect(adminUi, contains('class AdminLoadingState'));
      expect(adminUi, contains('class AdminFormColumn'));

      // Les six écrans de liste partagent un seul gabarit : barre d'outils
      // fixe, tableau sur grand écran (fiches en disposition compacte),
      // pied de liste unique. Avant la refonte chacun réinventait sa mise
      // en page et empilait deux barres de pagination contradictoires.
      for (final screen in <String>[
        videosAdded,
        videosReview,
        videosReported,
        offers,
        events,
        contactIntakes,
      ]) {
        expect(screen, contains('AdminWorkspace('));
        expect(screen, contains('AdminToolbar('));
        expect(screen, contains('AdminListFooter('));
        expect(screen, contains('AdminLoadingState'));
        expect(screen, contains('compact'));
        expect(screen, contains('safePage'));
      }

      // Les écrans vidéo relèvent la hauteur de ligne pour loger une
      // vignette dense, au lieu des 122 px d'une vignette pleine taille.
      for (final screen in <String>[
        videosAdded,
        videosReview,
        videosReported,
      ]) {
        expect(screen, contains('rowHeight: 56'));
        expect(screen, contains('dense: true'));
      }

      expect(contactIntakes, contains('_buildActionMenuCell'));
      expect(
        contactIntakes,
        contains("AdminColumn(label: 'Retour utilisateur'"),
      );

      expect(statistics, contains('constraints.maxWidth < 280'));
      expect(statistics, contains('index < 0 || index >= labels.length'));
    },
  );
}
