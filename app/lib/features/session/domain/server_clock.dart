typedef MillisSource = int Function();

final Stopwatch _monotonic = Stopwatch()..start();

/// Hora del servidor vista desde este dispositivo.
///
/// Tras cada respuesta del servidor se ancla a un reloj monotono, asi que
/// cambiar la hora del sistema no adelanta el final de la sesion. Antes de la
/// primera sincronizacion usa el reloj de pared mas el ultimo desfase conocido.
class ServerClock {
  ServerClock({MillisSource? wallClock, MillisSource? monotonic})
      : _wall = wallClock ?? (() => DateTime.now().millisecondsSinceEpoch),
        _mono = monotonic ?? (() => _monotonic.elapsedMilliseconds);

  final MillisSource _wall;
  final MillisSource _mono;

  int? _anchorServer;
  int _anchorMono = 0;
  int offsetMs = 0;

  void sync(int serverNowMs) {
    _anchorServer = serverNowMs;
    _anchorMono = _mono();
    offsetMs = serverNowMs - _wall();
  }

  int nowMs() {
    final anchor = _anchorServer;
    if (anchor == null) return _wall() + offsetMs;
    return anchor + (_mono() - _anchorMono);
  }
}
