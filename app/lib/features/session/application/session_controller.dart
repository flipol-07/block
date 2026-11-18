import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers.dart';
import '../data/session_repository.dart';
import '../domain/focus_session.dart';
import '../domain/server_clock.dart';

class SessionViewState {
  const SessionViewState({
    this.session,
    this.loading = false,
    this.error,
    this.allowedWindow,
  });

  final FocusSession? session;
  final bool loading;
  final String? error;

  /// Ventana elegida para el modo ventana unica (solo Windows).
  final int? allowedWindow;
}

/// Mantiene la sesion activa y la hace cumplir con el bloqueador nativo.
class SessionController extends Notifier<SessionViewState> {
  final clock = ServerClock();
  StreamSubscription<void>? _changes;
  Timer? _endTimer;
  static const _cacheKey = 'last_session';

  @override
  SessionViewState build() {
    final repo = ref.watch(sessionRepositoryProvider);
    _changes = repo.changes.listen((_) => refresh());
    ref.onDispose(() {
      _changes?.cancel();
      _endTimer?.cancel();
    });
    Future.microtask(refresh);
    return const SessionViewState(loading: true);
  }

  SessionRepository get _repo => ref.read(sessionRepositoryProvider);

  int nowMs() => clock.nowMs();

  Future<void> refresh() => _run(_repo.fetch);

  Future<void> start({
    required int minutes,
    required bool singleWindow,
    int? allowedWindow,
  }) {
    state = SessionViewState(loading: true, allowedWindow: allowedWindow);
    return _run(() => _repo.start(minutes: minutes, singleWindow: singleWindow));
  }

  Future<void> emergencyExit(String reason) =>
      _run(() => _repo.emergencyExit(reason));

  Future<void> _run(Future<SessionSnapshot> Function() op) async {
    try {
      final snapshot = await op();
      clock.sync(snapshot.serverNowMs);
      await _apply(snapshot.session, error: null);
    } catch (e) {
      // Sin conexion: se sigue haciendo cumplir la ultima sesion conocida.
      await _apply(state.session ?? _cached(), error: 'Sin conexión: $e');
    }
  }

  Future<void> _apply(FocusSession? session, {required String? error}) async {
    final active = session != null && session.isActiveAt(clock.nowMs());
    final current = active ? session : null;
    state = SessionViewState(
      session: current,
      error: error,
      allowedWindow: active ? state.allowedWindow : null,
    );
    await _cache(current);
    _endTimer?.cancel();
    final blocker = ref.read(blockerProvider);
    if (current == null) {
      await blocker.clear();
      return;
    }
    _endTimer = Timer(
      Duration(milliseconds: current.remainingMs(clock.nowMs()) + 500),
      refresh,
    );
    final rules = ref.read(rulesRepositoryProvider).cached();
    await blocker.apply(
      sessionId: current.id,
      endsAtServerMs: current.endsAtMs,
      serverNowMs: clock.nowMs(),
      singleWindow: current.singleWindow,
      blockedApps: [
        for (final r in rules)
          if (r.enabled && r.kind == 'app') r.value,
      ],
      allowedWindow: state.allowedWindow,
    );
  }

  FocusSession? _cached() {
    final raw = ref.read(prefsProvider).getString(_cacheKey);
    if (raw == null) return null;
    final session = FocusSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    // Sin conexion, el reloj de pared es lo unico que queda; usar el desfase
    // guardado al menos corrige relojes mal puestos.
    clock.offsetMs = ref.read(prefsProvider).getInt('${_cacheKey}_offset') ?? 0;
    return session;
  }

  Future<void> _cache(FocusSession? session) async {
    final prefs = ref.read(prefsProvider);
    if (session == null) {
      await prefs.remove(_cacheKey);
      return;
    }
    await prefs.setString(_cacheKey, jsonEncode(session.toJson()));
    await prefs.setInt('${_cacheKey}_offset', clock.offsetMs);
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionViewState>(SessionController.new);
