import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Contact intake admin guardrails', () {
    test('dashboard wires the contact intake supervision surface', () {
      final dashboard = File(
        'lib/dashboard/admin_dashboard_screen.dart',
      ).readAsStringSync();
      final bindings = File(
        'lib/config/app_page_bindings.dart',
      ).readAsStringSync();

      expect(dashboard, contains('ContactIntakeManagementWidget'));
      expect(dashboard, contains('Mise en relation'));
      expect(bindings, contains('ContactIntakeController'));
    });

    test('admin follow-up action stays centralized through the service', () {
      final controller = File(
        'lib/controller/contact_intake_controller.dart',
      ).readAsStringSync();
      final service = File(
        'lib/services/admin_content_service.dart',
      ).readAsStringSync();
      final widget = File(
        'lib/dashboard/contact_intake_management_widget.dart',
      ).readAsStringSync();

      expect(controller, contains('setContactIntakeFollowUp'));
      expect(controller, contains('deleteContactIntake({'));
      expect(controller, contains('deleteContactIntakeConversation'));
      expect(service, contains('adminSetContactIntakeFollowUp'));
      expect(service, contains("'adminDeleteContactIntake',"));
      expect(service, contains('adminDeleteContactIntakeConversation'));
      expect(widget, contains('Mettre à jour le suivi agence'));
      expect(widget, contains('AdminTable('));
      expect(widget, contains('Note requise'));
      // Le parcours de suivi est devenu une bande de compteurs cliquables
      // au lieu de cinq cartes empilées sous sept tuiles : les étapes
      // filtrent toujours la liste, c'est la seule chose qu'elles
      // faisaient.
      expect(widget, contains('_buildPipelineStrip('));
      expect(widget, contains('_pipelineStages'));
      expect(widget, contains("AdminColumn(label: 'Priorité'"));
      expect(widget, contains("AdminColumn(label: 'Retour utilisateur'"));
      expect(widget, contains('_buildParticipantSignalCell'));
      expect(widget, contains('_buildActionMenuCell'));
      expect(widget, contains('signaux forts'));
      expect(widget, contains('alertes'));
      expect(widget, contains('_nextStatus('));
      expect(widget, contains('Supprimer la mise en relation'));
      expect(widget, contains('Mise en relation supprimée'));
      expect(widget, contains('_deleteContactIntake(ContactIntake intake)'));
      expect(widget, contains('_deleteContactIntake(intake)'));
      expect(widget, contains('Icons.delete_outline_rounded'));
      // deleteContactIntakeConversation existait côté controller/service sans
      // être appelé depuis aucun widget -- le catalogue
      // (admin_callable_action_catalog.dart) la décrivait pourtant comme
      // câblée à l'UI. Verrouille que l'action est bien reliée à un bouton.
      expect(
        widget,
        contains('_deleteContactIntakeConversation(ContactIntake intake)'),
      );
      expect(widget, contains('_deleteContactIntakeConversation(intake)'));
      expect(widget, contains('Supprimer la conversation'));
    });
  });
}
