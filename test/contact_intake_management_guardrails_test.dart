import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Contact intake admin guardrails', () {
    test('dashboard wires the contact intake supervision surface', () {
      final dashboard =
          File('lib/dashboard/admin_dashboard_screen.dart').readAsStringSync();
      final bindings =
          File('lib/config/app_page_bindings.dart').readAsStringSync();

      expect(dashboard, contains('ContactIntakeManagementWidget'));
      expect(dashboard, contains('contactIntakeController'));
      expect(dashboard, contains('Mise en relation'));
      expect(bindings, contains('ContactIntakeController'));
    });

    test('admin follow-up action stays centralized through the service', () {
      final controller = File('lib/controller/contact_intake_controller.dart')
          .readAsStringSync();
      final service =
          File('lib/services/admin_content_service.dart').readAsStringSync();
      final widget = File('lib/dashboard/contact_intake_management_widget.dart')
          .readAsStringSync();

      expect(controller, contains('setContactIntakeFollowUp'));
      expect(controller, contains('deleteContactIntake({'));
      expect(controller, contains('deleteContactIntakeConversation'));
      expect(service, contains('adminSetContactIntakeFollowUp'));
      expect(service, contains("'adminDeleteContactIntake',"));
      expect(service, contains('adminDeleteContactIntakeConversation'));
      expect(widget, contains('Mettre à jour le suivi agence'));
      expect(widget, contains('AdminDataTableCard'));
      expect(widget, contains('Pipeline d’opportunités'));
      expect(widget, contains('Note requise'));
      expect(widget, contains('DataColumn(label: Text(\'Priorité\'))'));
      expect(
        widget,
        contains('DataColumn(label: Text(\'Signal utilisateurs\'))'),
      );
      expect(widget, contains('_buildParticipantSignalCell'));
      expect(widget, contains('Signaux forts'));
      expect(widget, contains('Alertes'));
      expect(widget, contains('_nextStatus('));
      expect(widget, contains('_PipelineStageCard'));
      expect(widget, contains('Supprimer la mise en relation'));
      expect(widget, contains('Mise en relation supprimée'));
      expect(widget, contains('_deleteContactIntake(ContactIntake intake)'));
      expect(widget, contains('_deleteContactIntake(intake)'));
      expect(widget, contains('Icons.delete_outline_rounded'));
    });
  });
}
