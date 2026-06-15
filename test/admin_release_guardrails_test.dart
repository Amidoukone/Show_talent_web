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
      expect(
        scripts['test:release'],
        contains('run_admin_release_tests.mjs'),
      );
      expect(
        scripts['create-admin:guided'],
        contains('create_admin_account.ps1'),
      );
      expect(
        scripts['create-admin:staging'],
        contains('-Environment staging'),
      );
      expect(
        scripts['create-admin:production'],
        contains('-Environment production'),
      );

      final releaseTestScript =
          File('scripts/run_admin_release_tests.mjs').readAsStringSync();
      expect(
        releaseTestScript,
        contains('managed_account_service_test.dart'),
      );
      expect(
        releaseTestScript,
        contains('user_management_widget_test.dart'),
      );
      expect(
        releaseTestScript,
        contains('test/app_environment_test.dart'),
      );
      expect(
        releaseTestScript,
        contains('test/admin_text_quality_guardrails_test.dart'),
      );
      expect(
        releaseTestScript,
        contains('test/admin_responsive_guardrails_test.dart'),
      );
      expect(
        releaseTestScript,
        contains('test/contact_intake_management_guardrails_test.dart'),
      );
      expect(releaseTestScript, contains('spawnSync'));
      expect(releaseTestScript, contains("shell: false"));
    });

    test('production checks pin the shared backend', () {
      final script =
          File('scripts/check_admin_production_config.ps1').readAsStringSync();

      expect(script, contains('adfoot-production'));
      expect(script, contains('adfoot-production.firebasestorage.app'));
      expect(script, contains('europe-west1'));
    });

    test('admin bootstrap script matches mobile-safe account contract', () {
      final script =
          File('scripts/create_admin_account.mjs').readAsStringSync();

      expect(script, contains("const DEFAULT_ADMIN_NAME = 'Admin Adfoot';"));
      expect(script, contains("parsed.type !== 'service_account'"));
      expect(script, contains('google-services.json'));
      expect(script, contains('ADMIN_CLAIM_KEYS'));
      expect(script, contains('sanitizeClaims'));
      expect(script, contains('emailVerified: true'));
      expect(script, contains('followersList'));
      expect(script, contains('followingsList'));
      expect(script, contains('profilePublic: false'));
      expect(script, contains('allowMessages: false'));
      expect(script, contains('createdByAdmin: false'));
      expect(script, contains('FieldValue.serverTimestamp()'));
      expect(script, contains("'update-password'"));
      expect(script, contains('emailVerificationRequired: false'));
      expect(script, contains('No email verification step is required'));
      expect(
          script, contains('passwordToUse: !existingUser || passwordUpdated'));
    });

    test('guided admin bootstrap keeps project and email verification explicit',
        () {
      final script =
          File('scripts/create_admin_account.ps1').readAsStringSync();

      expect(script, contains('adfoot-staging'));
      expect(script, contains('adfoot-production'));
      expect(script, contains('FIREBASE_SERVICE_ACCOUNT_KEY_PATH'));
      expect(script, contains('GOOGLE_APPLICATION_CREDENTIALS'));
      expect(script, contains('projectCandidateFiles'));
      expect(script, contains(r'*$ProjectId*.json'));
      expect(script, contains('Email verification required: false'));
      expect(script, contains('--projectId'));
      expect(script, contains('--serviceAccount'));
      expect(script, contains('--update-password'));
      expect(script, contains('Dry run only'));
      expect(script, contains('No Firebase Auth or Firestore change was made'));
    });
  });
}
