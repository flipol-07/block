import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Identidad de este dispositivo dentro de la cuenta.
class DeviceIdentity {
  const DeviceIdentity(this.id, this.secret);
  final String id;
  final String secret;
}

/// Registra el dispositivo una vez por cuenta y guarda su id y secreto.
class DeviceRegistry {
  DeviceRegistry(this._prefs);

  final SharedPreferences _prefs;

  String _key(String userId, String field) => 'device_${userId}_$field';

  DeviceIdentity? current(String userId) {
    final id = _prefs.getString(_key(userId, 'id'));
    final secret = _prefs.getString(_key(userId, 'secret'));
    return id == null || secret == null ? null : DeviceIdentity(id, secret);
  }

  Future<DeviceIdentity> ensureRegistered(SupabaseClient client) async {
    final userId = client.auth.currentUser!.id;
    final existing = current(userId);
    if (existing != null) return existing;
    final result = Map<String, dynamic>.from(await client.rpc(
      'register_device',
      params: {'p_platform': _platform, 'p_name': _name},
    ) as Map);
    final identity =
        DeviceIdentity(result['device_id'] as String, result['secret'] as String);
    await _prefs.setString(_key(userId, 'id'), identity.id);
    await _prefs.setString(_key(userId, 'secret'), identity.secret);
    return identity;
  }

  String get _platform => Platform.isAndroid ? 'android' : 'windows';

  String get _name {
    if (Platform.isAndroid) return 'Móvil Android';
    final host = Platform.localHostname;
    return host.isEmpty ? 'PC Windows' : host;
  }
}
