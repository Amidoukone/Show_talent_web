import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/config/app_environment.dart';

void main() {
  test('defaults remain production-safe', () {
    expect(AppEnvironmentConfig.environment, AppEnvironment.production);
    expect(AppEnvironmentConfig.environmentName, 'production');
    expect(AppEnvironmentConfig.useFirebaseEmulators, isFalse);
    expect(AppEnvironmentConfig.functionsRegion, 'europe-west1');
    expect(AppEnvironmentConfig.firebaseProjectId, isNotEmpty);
  });
}
