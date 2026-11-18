import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/session/application/session_controller.dart';
import '../config.dart';
import '../providers.dart';

/// Servidor HTTP en 127.0.0.1 que consulta la extension del navegador para
/// saber si hay sesion y que webs bloquear. Solo escucha en loopback y no
/// envia cabeceras CORS: una web cualquiera no puede leerlo, la extension si
/// (tiene permiso de host).
class LocalBridge {
  LocalBridge(this._container);

  final ProviderContainer _container;
  HttpServer? _server;

  Future<void> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, AppConfig.bridgePort);
    } on SocketException {
      return; // Otra instancia de Block ya lo esta sirviendo.
    }
    _server!.listen(_handle);
  }

  Map<String, dynamic> state() {
    final controller = _container.read(sessionControllerProvider.notifier);
    final session = _container.read(sessionControllerProvider).session;
    final now = controller.nowMs();
    final active = session != null && session.isActiveAt(now);
    final rules = _container.read(rulesRepositoryProvider).cached();
    return {
      'active': active,
      'remainingMs': active ? session.remainingMs(now) : 0,
      'sites': [
        for (final r in rules)
          if (r.enabled && r.kind == 'site') r.value,
      ],
    };
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    if (request.method == 'GET' && request.uri.path == '/state') {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(state()));
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    await response.close();
  }
}
