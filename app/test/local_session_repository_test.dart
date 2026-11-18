import 'package:block/features/session/data/local_session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late LocalSessionRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = LocalSessionRepository(await SharedPreferences.getInstance());
  });

  test('empezar crea una sesion activa y no duplica', () async {
    final a = await repo.start(minutes: 25, singleWindow: true);
    final b = await repo.start(minutes: 90, singleWindow: false);
    expect(a.session, isNotNull);
    expect(b.session!.id, a.session!.id);
    expect(a.session!.endsAtMs - a.session!.startedAtMs, 25 * 60000);
  });

  test('la salida de emergencia cierra la sesion y queda en el historial', () async {
    await repo.start(minutes: 25, singleWindow: false);
    final after = await repo.emergencyExit('Urgencia real');
    expect(after.session, isNull);
    final history = await repo.history();
    expect(history.single.status, 'emergency_exit');
    expect(history.single.reason, 'Urgencia real');
  });
}
