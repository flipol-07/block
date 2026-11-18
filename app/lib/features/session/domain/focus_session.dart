/// Una sesion de concentracion. Las horas son del servidor (o del propio
/// dispositivo en modo local) y se guardan como milisegundos UTC.
class FocusSession {
  const FocusSession({
    required this.id,
    required this.startedAtMs,
    required this.endsAtMs,
    required this.singleWindow,
  });

  final String id;
  final int startedAtMs;
  final int endsAtMs;
  final bool singleWindow;

  static const localPrefix = 'local-';

  bool get isLocal => id.startsWith(localPrefix);

  int remainingMs(int nowMs) => (endsAtMs - nowMs).clamp(0, 1 << 52);

  bool isActiveAt(int nowMs) => endsAtMs > nowMs;

  int get totalMs => endsAtMs - startedAtMs;

  factory FocusSession.fromServer(Map<String, dynamic> json) => FocusSession(
        id: json['id'] as String,
        startedAtMs: parseServerTime(json['started_at']),
        endsAtMs: parseServerTime(json['ends_at']),
        singleWindow: json['single_window'] as bool? ?? false,
      );

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
        id: json['id'] as String,
        startedAtMs: json['startedAtMs'] as int,
        endsAtMs: json['endsAtMs'] as int,
        singleWindow: json['singleWindow'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAtMs': startedAtMs,
        'endsAtMs': endsAtMs,
        'singleWindow': singleWindow,
      };
}

/// Estado devuelto por el backend: la sesion activa (si hay) y la hora del
/// servidor en el momento de responder.
class SessionSnapshot {
  const SessionSnapshot({required this.session, required this.serverNowMs});

  final FocusSession? session;
  final int serverNowMs;

  factory SessionSnapshot.fromServer(Map<String, dynamic> json) {
    final session = json['session'];
    return SessionSnapshot(
      session: session == null
          ? null
          : FocusSession.fromServer(Map<String, dynamic>.from(session as Map)),
      serverNowMs: parseServerTime(json['server_now']),
    );
  }
}

int parseServerTime(Object? value) =>
    DateTime.parse(value as String).toUtc().millisecondsSinceEpoch;

/// Una sesion pasada, para el historial.
class HistoryEntry {
  const HistoryEntry({
    required this.startedAtMs,
    required this.minutes,
    required this.status,
    this.reason,
  });

  final int startedAtMs;
  final int minutes;

  /// `completed`, `emergency_exit` o `active`.
  final String status;
  final String? reason;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        startedAtMs: json['startedAtMs'] as int,
        minutes: json['minutes'] as int,
        status: json['status'] as String,
        reason: json['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'startedAtMs': startedAtMs,
        'minutes': minutes,
        'status': status,
        if (reason != null) 'reason': reason,
      };
}
