// Production-critical config gate: the app must refuse to start when the
// backend URL was never provided via --dart-define. The test suite compiles
// WITHOUT dart-defines, so AppConfig.apiBaseUrl is empty here — exactly the
// unconfigured-release situation this gate exists for.
import 'package:flutter_test/flutter_test.dart';
import 'package:stegappe/core/config/app_config.dart';

void main() {
  test('ensureConfigured throws an actionable error when API_BASE_URL is absent', () {
    expect(AppConfig.isBackendConfigured, isFalse);
    expect(
      AppConfig.ensureConfigured,
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        contains('API_BASE_URL'),
      )),
    );
  });

  test('wsBaseUrl degrades to an empty address instead of inventing a dev host', () {
    expect(AppConfig.wsBaseUrl, isEmpty);
  });
}
