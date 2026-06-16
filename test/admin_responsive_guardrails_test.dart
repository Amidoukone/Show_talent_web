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
  testWidgets('statistics overview stays usable on a narrow viewport',
      (tester) async {
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

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AdminTheme.buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
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

  test('admin responsive surfaces keep shared production layout guardrails',
      () {
    final adminUi = File('lib/widgets/admin_ui.dart').readAsStringSync();
    final videosAdded =
        File('lib/dashboard/video_added_widget.dart').readAsStringSync();
    final videosReview =
        File('lib/dashboard/video_review_widget.dart').readAsStringSync();
    final videosReported =
        File('lib/dashboard/video_reported_widget.dart').readAsStringSync();
    final offers =
        File('lib/dashboard/offer_management_widget.dart').readAsStringSync();
    final events =
        File('lib/dashboard/event_management_widget.dart').readAsStringSync();
    final contactIntakes = File(
      'lib/dashboard/contact_intake_management_widget.dart',
    ).readAsStringSync();
    final statistics =
        File('lib/dashboard/statistiques_screen.dart').readAsStringSync();

    expect(adminUi, contains('class AdminFilterBar'));
    expect(adminUi, contains('class AdminLoadingState'));
    expect(adminUi, contains('class AdminFormColumn'));

    expect(videosAdded, contains('maxWidth: 640'));
    expect(videosAdded, contains('safePage'));
    expect(videosReview, contains('maxWidth: 640'));
    expect(videosReview, contains('safePage'));
    expect(videosReview, contains('AdminDataTableCard'));
    expect(videosReported, contains('maxWidth: 640'));
    expect(videosReported, contains('safePage'));

    expect(offers, contains('AdminFilterBar'));
    expect(offers, contains('AdminLoadingState'));
    expect(offers, contains('safePage'));
    expect(events, contains('AdminFilterBar'));
    expect(events, contains('AdminLoadingState'));
    expect(events, contains('safePage'));

    expect(contactIntakes, contains('AdminFilterBar'));
    expect(contactIntakes, contains('AdminLoadingState'));
    expect(contactIntakes, contains('_buildActionMenuCell'));
    expect(contactIntakes, contains('tableColumns'));
    expect(contactIntakes, contains("Text('Retour utilisateur')"));

    expect(statistics, contains('constraints.maxWidth < 280'));
    expect(statistics, contains('index < 0 || index >= labels.length'));
  });
}
