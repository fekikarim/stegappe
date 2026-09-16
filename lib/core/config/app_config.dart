// Central application configuration.
//
// All values are overridable via `--dart-define` so no secret or
// environment-specific URL is hard-coded. Backend remains authoritative
// for business rules; values here are display/transport only.
class AppConfig {
  const AppConfig._();

  /// Base URL of the Spring Boot backend, e.g.
  /// `flutter run --dart-define=API_BASE_URL=https://api.steg.tn`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// WebSocket base for STOMP (`/ws`). Override with
  /// `--dart-define=WS_BASE_URL=ws://host:port` when the API and WS
  /// origins differ; otherwise derived from [apiBaseUrl].
  static const String _wsOverride = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: '',
  );

  static String get wsBaseUrl {
    if (_wsOverride.isNotEmpty) return _wsOverride;
    final base = apiBaseUrl;
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
