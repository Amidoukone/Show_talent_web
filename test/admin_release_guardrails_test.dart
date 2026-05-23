import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('admin production release guardrails', () {
    test('package exposes repeatable production commands', () {
      final packageJson = jsonDecode(File('package.json').readAsStringSync())
          as Map<String, dynamic>;
      final scripts = Map<String, dynamic>.from(packageJson['scripts'] as Map);

      expect(
        scripts['production:check'],
        contains('check_admin_production_config.ps1'),
      );
      expect(scripts['contract:mobile'], contains('check_mobile_contract.ps1'));
      expect(scripts['build:web:production'], contains('APP_ENV=production'));
      expect(
        scripts['build:web:production'],
        contains('FIREBASE_PROJECT_ID=adfoot-production'),
      );
      expect(scripts['release:check'], contains('production:check'));
      expect(scripts['release:check'], contains('contract:mobile'));
      expect(scripts['release:check'], contains('test:release'));
      expect(scripts['test:release'],
          contains('managed_account_service_test.dart'));
      expect(scripts['test:release'],
          contains('user_management_widget_test.dart'));
    });

    test('production checks pin the shared backend', () {
      final script =
          File('scripts/check_admin_production_config.ps1').readAsStringSync();

      expect(script, contains('adfoot-production'));
      expect(script, contains('adfoot-production.firebasestorage.app'));
      expect(script, contains('europe-west1'));
    });
  });
}
