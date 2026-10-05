// Central application configuration.
//
// All values come from `--dart-define` — there is deliberately NO hard-coded
// development default (no loopback or emulator fallback address): a release
// bundle built without an explicit backend URL fails fast with an actionable
// message instead of silently calling a developer machine.
//
//   flutter run --dart-define=API_BASE_URL=https://api.steg.tn
class AppConfig {
  const AppConfig._();

  /// Base URL of the Spring Boot backend. REQUIRED at build time:
  /// `--dart-define=API_BASE_URL=https://api.steg.tn` (empty = unconfigured,
  /// refused by [ensureConfigured] at startup).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// WebSocket base for STOMP (`/ws`). Override with
  /// `--dart-define=WS_BASE_URL=ws://host:port` when the API and WS
  /// origins differ; otherwise derived from [apiBaseUrl].
  static const String _wsOverride = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: '',
  );

  /// True when [apiBaseUrl] was provided at build time.
  static bool get isBackendConfigured => apiBaseUrl.isNotEmpty;

  /// Fail-fast guard called from `main()`: a build without an explicit
  /// backend URL must never start and guess an address.
  static void ensureConfigured() {
    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL is not configured. Build/run the app with '
        '--dart-define=API_BASE_URL=<backend base URL> '
        '(e.g. https://api.steg.tn). No development default exists by design.',
      );
    }
  }

  /// Derived WS base. Empty when unconfigured — callers only reach this
  /// before [ensureConfigured] has run (tests, unusual embeds); an empty
  /// address simply fails the socket attempt, it never invents a dev host.
  static String get wsBaseUrl {
    if (_wsOverride.isNotEmpty) return _wsOverride;
    final base = apiBaseUrl;
    if (base.isEmpty) return '';
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://');
    }
    return base.replaceFirst('http://', 'ws://');
  }

  static const Duration networkTimeout = Duration(seconds: 20);
  static const Duration refreshTimeout = Duration(seconds: 15);

  /// Display-only currency label. Amounts are NEVER computed on-device;
  /// PaymentCalculation from the backend is authoritative.
  static const String currencyLabel = 'TND';
}
