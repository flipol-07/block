import '../domain/focus_session.dart';

/// Origen de verdad de la sesion: el servidor (modo nube) o este dispositivo
/// (modo local). El controlador no sabe cual de los dos esta usando.
abstract class SessionRepository {
  Future<SessionSnapshot> fetch();

  Future<SessionSnapshot> start({
    required int minutes,
    required bool singleWindow,
  });

  Future<SessionSnapshot> emergencyExit(String reason);

  /// Avisos de que la sesion puede haber cambiado en otro dispositivo.
  Stream<void> get changes;

  Future<List<HistoryEntry>> history();

  void dispose() {}
}
