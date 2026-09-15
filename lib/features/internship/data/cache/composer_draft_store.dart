import 'dart:convert';

import '../../../../core/storage/prefs_store.dart';

/// Pre-creation composer draft. Local-only, keyed by internship + day.
/// Cleared on successful server create — the backend is authoritative
/// from that point (entries are server-immutable: no update endpoint).
class ComposerDraft {
  const ComposerDraft({
    this.title = '',
    this.description = '',
    this.updatedAt,
  });

  final String title;
  final String description;
  final DateTime? updatedAt;

  bool get isEmpty => title.isEmpty && description.isEmpty;

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory ComposerDraft.fromJson(Map<String, dynamic> json) =>
      ComposerDraft(
        title: (json['title'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        updatedAt: DateTime.tryParse(
            (json['updatedAt'] ?? '').toString()),
      );
}

String composerDraftKey(String internshipId, DateTime day) =>
    'steg.journal_composer.$internshipId.${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

abstract class ComposerDraftStore {
  Future<ComposerDraft?> load(String internshipId, DateTime day);
  Future<void> save(
      String internshipId, DateTime day, ComposerDraft draft);
  Future<void> clear(String internshipId, DateTime day);
}

/// SharedPreferences-backed (work descriptions are non-sensitive;
/// tokens must never pass through here).
class PrefsComposerDraftStore implements ComposerDraftStore {
  PrefsComposerDraftStore(this._prefs);

  final PrefsStore _prefs;

  @override
  Future<ComposerDraft?> load(String internshipId, DateTime day) async {
    final raw = _prefs.readRaw(composerDraftKey(internshipId, day));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final draft = ComposerDraft.fromJson(decoded);
      return draft.isEmpty ? null : draft;
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> save(
      String internshipId, DateTime day, ComposerDraft draft) {
    return _prefs.writeRaw(
        composerDraftKey(internshipId, day), jsonEncode(draft.toJson()));
  }

  @override
  Future<void> clear(String internshipId, DateTime day) =>
      _prefs.removeRaw(composerDraftKey(internshipId, day));
}

/// In-memory fake for tests.
class MemoryComposerDraftStore implements ComposerDraftStore {
  final _map = <String, ComposerDraft>{};

  String _k(String i, DateTime d) => composerDraftKey(i, d);

  @override
  Future<ComposerDraft?> load(String internshipId, DateTime day) async =>
      _map[_k(internshipId, day)];

  @override
  Future<void> save(
          String internshipId, DateTime day, ComposerDraft draft) async =>
      _map[_k(internshipId, day)] = draft;

  @override
  Future<void> clear(String internshipId, DateTime day) async =>
      _map.remove(_k(internshipId, day));
}
