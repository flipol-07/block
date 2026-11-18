import 'package:block/features/session/domain/server_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('usa el reloj monotono tras sincronizar: cambiar la hora no adelanta', () {
    var wall = 1000000;
    var mono = 0;
    final clock = ServerClock(wallClock: () => wall, monotonic: () => mono);
    clock.sync(5000000); // el servidor va 4000 s por delante del dispositivo
    mono += 10000;
    wall += 3600 * 1000; // el usuario adelanta el reloj una hora
    expect(clock.nowMs(), 5010000);
  });

  test('sin sincronizar usa reloj de pared mas el desfase conocido', () {
    final clock = ServerClock(wallClock: () => 1000, monotonic: () => 0)
      ..offsetMs = 500;
    expect(clock.nowMs(), 1500);
  });
}
