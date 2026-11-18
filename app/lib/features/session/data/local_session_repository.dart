import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/focus_session.dart';
import 'session_repository.dart';

/// Sesiones guardadas solo en este dispositivo (sin cuenta).
class LocalSessionRepository implements SessionRepository {
  LocalSessionRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _sessionKey = 'local_session';
  static const _historyKey = 'local_history';

  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  Stream<void> get changes => const Stream.empty();

  @override
  Future<SessionSnapshot> fetch() async {
    final raw = _prefs.getString(_sessionKey);
    var session = raw == null
        ? null
        : FocusSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    if (session != null && !session.isActiveAt(_now)) {
      await _archive(session, 'completed', null, session.endsAtMs);
      session = null;
    }
    return SessionSnapshot(session: session, serverNowMs: _now);
  }

  @override
  Future<SessionSnapshot> start({
    required int minutes,
    required bool singleWindow,
  }) async {
    final current = await fetch();
    if (current.session != null) return current;
    final now = _now;
    final session = FocusSession(
      id: '${FocusSession.localPrefix}$now',
      startedAtMs: now,
      endsAtMs: now + minutes * 60000,
      singleWindow: singleWindow,
    );
    await _prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    return SessionSnapshot(session: session, serverNowMs: now);
  }

  @override
  Future<SessionSnapshot> emergencyExit(String reason) async {
    final current = await fetch();
    final session = current.session;
    if (session != null) {
      await _archive(session, 'emergency_exit', reason, _now);
    }
    return SessionSnapshot(session: null, serverNowMs: _now);
  }

  Future<void> _archive(
    FocusSession s,
    String status,
    String? reason,
    int endedAt,
  ) async {
    final entries = await history();
    entries.insert(
      0,
      HistoryEntry(
        startedAtMs: s.startedAtMs,
        minutes: (endedAt - s.startedAtMs) ~/ 60000,
        status: status,
        reason: reason,
      ),
    );
    await _prefs.setString(
      _historyKey,
      jsonEncode(entries.take(200).map((e) => e.toJson()).toList()),
    );
    await _prefs.remove(_sessionKey);
  }

  @override
  Future<List<HistoryEntry>> history() async {
    final raw = _prefs.getString(_historyKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  void dispose() {}
}
