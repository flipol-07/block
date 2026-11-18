import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/focus_session.dart';
import 'session_repository.dart';

/// Sesiones en Supabase. Las horas las fija el servidor (RPC) y los cambios
/// llegan por Realtime, con un sondeo de respaldo por si el socket se cae.
class CloudSessionRepository implements SessionRepository {
  CloudSessionRepository(this._client, {required this.deviceId}) {
    _subscribe();
  }

  final SupabaseClient _client;
  final String? deviceId;
  final _changes = StreamController<void>.broadcast();
  RealtimeChannel? _channel;
  Timer? _fallback;

  @override
  Stream<void> get changes => _changes.stream;

  void _subscribe() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    _channel = _client
        .channel('focus_sessions:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'focus_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => _changes.add(null),
        )
        .subscribe();
    _fallback = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _changes.add(null),
    );
  }

  Future<SessionSnapshot> _rpc(String fn, [Map<String, dynamic>? params]) async {
    final result = await _client.rpc(fn, params: params);
    return SessionSnapshot.fromServer(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<SessionSnapshot> fetch() => _rpc('get_session_state');

  @override
  Future<SessionSnapshot> start({
    required int minutes,
    required bool singleWindow,
  }) =>
      _rpc('start_focus_session', {
        'p_minutes': minutes,
        'p_single_window': singleWindow,
        'p_device': deviceId,
      });

  @override
  Future<SessionSnapshot> emergencyExit(String reason) =>
      _rpc('emergency_exit', {'p_reason': reason});

  @override
  Future<List<HistoryEntry>> history() async {
    final rows = await _client
        .from('focus_history')
        .select('started_at, minutes, status, emergency_reason')
        .order('started_at', ascending: false)
        .limit(200);
    return rows
        .map((r) => HistoryEntry(
              startedAtMs: parseServerTime(r['started_at']),
              minutes: (r['minutes'] as num).toInt(),
              status: r['status'] as String,
              reason: r['emergency_reason'] as String?,
            ))
        .toList();
  }

  @override
  void dispose() {
    _fallback?.cancel();
    final channel = _channel;
    if (channel != null) _client.removeChannel(channel);
    _changes.close();
  }
}
