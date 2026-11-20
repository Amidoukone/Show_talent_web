// Cross-repository check using the response captured from the demo emulators.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/models/admin_action_response.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/services/admin_document_service.dart';
import 'package:show_talent/widgets/club_enrollment_dialog.dart';

void main() {
  test(
    'the real backend verdict is interpreted as a successful portal action',
    () {
      final evidence =
          jsonDecode(
                File(
                  'build/audit-2026-11-20/backend-contract-reproductions.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final verdict = evidence['verdictResponse'] as Map<String, dynamic>;
      final response = AdminActionResponse.fromMap(
        Map<String, dynamic>.from(verdict['response'] as Map),
      );
      expect(verdict['storedStatus'], 'approved');
      expect(response.success, isTrue);
      expect(response.code, 'contract_status_proof_approved');
      expect(response.message, isNotEmpty);
    },
  );

  testWidgets('the portal allows a cascade retry after the right was removed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final club = AppUser.fromMap({
      'uid': 'audit-revoked-club',
      'nom': 'Club test',
      'role': 'club',
      'createdByAdmin': true,
      'clubEnrollmentRevocation': {'state': 'pending'},
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClubEnrollmentDialog(
            user: club,
            documentService: AdminDocumentService.visualQa(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Ce club n’a aucune habilitation à retirer.'),
      findsNothing,
    );
    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reprendre le retrait'),
    );
    expect(submit.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
