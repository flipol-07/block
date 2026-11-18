import 'dart:io';

import 'package:flutter/services.dart';

/// Ventana abierta en Windows que se puede elegir para el modo ventana unica.
class OpenWindow {
  const OpenWindow({required this.handle, required this.title, required this.exe});

  final int handle;
  final String title;
  final String exe;
}

/// Permisos que necesita el bloqueo en Android.
class AndroidPermissions {
  const AndroidPermissions({
    required this.accessibility,
    required this.deviceAdmin,
    required this.batteryUnrestricted,
  });

  final bool accessibility;
  final bool deviceAdmin;
  final bool batteryUnrestricted;

  bool get allGranted => accessibility && deviceAdmin && batteryUnrestricted;
}

/// Puente con el bloqueador nativo (Kotlin en Android, C++ en Windows).
///
/// Dart decide QUE bloquear y HASTA CUANDO; el codigo nativo lo hace cumplir.
/// En Android el bloqueo sigue funcionando aunque Flutter no este abierto.
class Blocker {
  Blocker({void Function(String route)? onRoute}) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'route' && onRoute != null) {
        onRoute(call.arguments as String);
      }
    });
  }

  static const _channel = MethodChannel('block/blocker');

  static bool get isAndroid => Platform.isAndroid;
  static bool get isWindows => Platform.isWindows;

  Future<void> apply({
    required String sessionId,
    required int endsAtServerMs,
    required int serverNowMs,
    required bool singleWindow,
    required List<String> blockedApps,
    int? allowedWindow,
  }) =>
      _channel.invokeMethod('applySession', {
        'sessionId': sessionId,
        'endsAtServerMs': endsAtServerMs,
        'serverNowMs': serverNowMs,
        'singleWindow': singleWindow,
        'blockedApps': blockedApps,
        'allowedWindow': allowedWindow ?? 0,
      });

  Future<void> clear() => _channel.invokeMethod('clearSession');

  // ------------------------------------------------------------- Android

  Future<AndroidPermissions> permissions() async {
    final m = Map<String, dynamic>.from(
        await _channel.invokeMethod('permissions') as Map);
    return AndroidPermissions(
      accessibility: m['accessibility'] as bool,
      deviceAdmin: m['deviceAdmin'] as bool,
      batteryUnrestricted: m['batteryUnrestricted'] as bool,
    );
  }

  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod('openAccessibilitySettings');
  Future<void> requestDeviceAdmin() => _channel.invokeMethod('requestDeviceAdmin');
  Future<void> requestBatteryExemption() =>
      _channel.invokeMethod('requestBatteryExemption');
  Future<void> openAppDetails() => _channel.invokeMethod('openAppDetails');

  /// Credenciales con las que el servicio nativo consulta la sesion activa.
  Future<void> configureSync({
    required String url,
    required String key,
    required String deviceId,
    required String secret,
  }) =>
      _channel.invokeMethod('configureSync', {
        'url': url,
        'key': key,
        'deviceId': deviceId,
        'secret': secret,
      });

  Future<void> clearSync() => _channel.invokeMethod('clearSync');

  /// Ruta con la que se abrio la app desde la pantalla de bloqueo.
  Future<String?> initialRoute() => _channel.invokeMethod<String>('initialRoute');

  // ------------------------------------------------------------- Windows

  Future<List<OpenWindow>> listWindows() async {
    final list = await _channel.invokeMethod<List>('listWindows') ?? [];
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return OpenWindow(
        handle: m['handle'] as int,
        title: m['title'] as String,
        exe: m['exe'] as String,
      );
    }).toList();
  }

  Future<void> setAutostart(bool enabled) =>
      _channel.invokeMethod('setAutostart', enabled);
}
