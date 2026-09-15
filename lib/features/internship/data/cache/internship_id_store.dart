import '../../../../core/storage/prefs_store.dart';

/// Persists the resolved internship id (non-sensitive reference, safe for
/// SharedPreferences — unlike tokens). Enables offline dashboard with a
/// stale-data indicator when the network is unavailable.
abstract class InternshipIdStore {
  Future<String?> read();
  Future<void> write(String id);
  Future<void> clear();
}

class PrefsInternshipIdStore implements InternshipIdStore {
  PrefsInternshipIdStore(this._prefs);

  final PrefsStore _prefs;
  static const _key = 'steg.internship_id.v1';

  // PrefsStore only exposes locale/theme; extend via its backing store
  // through a dedicated accessor to keep token separation obvious.
  @override
  Future<String?> read() => Future.value(_cached ?? _prefs.readRaw(_key));

  @override
  Future<void> write(String id) async {
    _cached = id;
    await _prefs.writeRaw(_key, id);
  }

  @override
  Future<void> clear() async {
    _cached = null;
    await _prefs.removeRaw(_key);
  }

  String? _cached;
}

/// In-memory fake for tests.
class MemoryInternshipIdStore implements InternshipIdStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String id) async => value = id;

  @override
  Future<void> clear() async => value = null;
}
