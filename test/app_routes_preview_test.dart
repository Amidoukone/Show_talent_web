import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/config/app_environment.dart';
import 'package:show_talent/config/app_routes.dart';

void main() {
  group('dashboard local preview routing', () {
    test('does not enable preview from URL in production', () {
      final preview = AppRoutes.resolveDashboardPreviewMode(
        environment: AppEnvironment.production,
        uri: Uri.parse(
          'http://localhost:8080/#/admin-dashboard?adminPreview=true',
        ),
      );

      expect(preview, isFalse);
    });

    test('enables preview from URL outside production', () {
      final preview = AppRoutes.resolveDashboardPreviewMode(
        environment: AppEnvironment.local,
        uri: Uri.parse(
          'http://localhost:8080/#/admin-dashboard?adminPreview=true',
        ),
      );

      expect(preview, isTrue);
    });

    test('opens requested dashboard tab outside production', () {
      final index = AppRoutes.resolveDashboardInitialIndex(
        environment: AppEnvironment.local,
        uri: Uri.parse(
          'http://localhost:8080/#/admin-dashboard?adminTab=managed-accounts',
        ),
      );

      expect(index, 1);
    });

    test('opens video review dashboard tab outside production', () {
      final index = AppRoutes.resolveDashboardInitialIndex(
        environment: AppEnvironment.local,
        uri: Uri.parse(
          'http://localhost:8080/#/admin-dashboard?adminTab=video-review',
        ),
      );

      expect(index, 2);
    });

    test('keeps dashboard tab query ignored in production', () {
      final index = AppRoutes.resolveDashboardInitialIndex(
        environment: AppEnvironment.production,
        uri: Uri.parse(
          'http://localhost:8080/#/admin-dashboard?adminTab=managed-accounts',
        ),
      );

      expect(index, 0);
    });
  });
}
