import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/device_registry.dart';
import '../features/rules/rules_repository.dart';
import '../features/session/data/cloud_session_repository.dart';
import '../features/session/data/local_session_repository.dart';
import '../features/session/data/session_repository.dart';
import 'blocker/blocker.dart';
import 'config.dart';

/// Se sobrescriben en `main()` una vez inicializados.
final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());
final blockerProvider = Provider<Blocker>((_) => throw UnimplementedError());

final supabaseProvider = Provider<SupabaseClient?>(
  (_) => AppConfig.cloudEnabled ? Supabase.instance.client : null,
);

/// Usuario con sesion iniciada (null en modo local o sin login).
final currentUserProvider = StreamProvider<User?>((ref) async* {
  final client = ref.watch(supabaseProvider);
  if (client == null) {
    yield null;
    return;
  }
  yield client.auth.currentUser;
  await for (final change in client.auth.onAuthStateChange) {
    yield change.session?.user;
  }
});

/// El usuario eligio usar Block sin cuenta en este dispositivo.
final localModeProvider = NotifierProvider<LocalModeController, bool>(
  LocalModeController.new,
);

class LocalModeController extends Notifier<bool> {
  static const _key = 'local_mode';

  @override
  bool build() =>
      !AppConfig.cloudEnabled || (ref.read(prefsProvider).getBool(_key) ?? false);

  Future<void> set(bool value) async {
    await ref.read(prefsProvider).setBool(_key, value);
    state = !AppConfig.cloudEnabled || value;
  }
}

final deviceRegistryProvider =
    Provider((ref) => DeviceRegistry(ref.watch(prefsProvider)));

/// Cliente de nube solo si hay usuario y no se eligio el modo local.
final _activeCloudProvider = Provider<SupabaseClient?>((ref) {
  if (ref.watch(localModeProvider)) return null;
  final user = ref.watch(currentUserProvider).value;
  return user == null ? null : ref.watch(supabaseProvider);
});

/// Registra este dispositivo en la cuenta y, en Android, pasa sus
/// credenciales al servicio nativo para que consulte la sesion por su cuenta.
final deviceIdentityProvider = FutureProvider<DeviceIdentity?>((ref) async {
  final client = ref.watch(_activeCloudProvider);
  final blocker = ref.read(blockerProvider);
  if (client == null) {
    if (Platform.isAndroid) await blocker.clearSync();
    return null;
  }
  final identity = await ref.read(deviceRegistryProvider).ensureRegistered(client);
  if (Platform.isAndroid) {
    await blocker.configureSync(
      url: AppConfig.supabaseUrl,
      key: AppConfig.supabaseKey,
      deviceId: identity.id,
      secret: identity.secret,
    );
  }
  return identity;
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final client = ref.watch(_activeCloudProvider);
  final SessionRepository repo;
  if (client == null) {
    repo = LocalSessionRepository(ref.watch(prefsProvider));
  } else {
    final device = ref.watch(deviceIdentityProvider).value;
    repo = CloudSessionRepository(client, deviceId: device?.id);
  }
  ref.onDispose(repo.dispose);
  return repo;
});

final rulesRepositoryProvider = Provider((ref) =>
    RulesRepository(ref.watch(prefsProvider), ref.watch(_activeCloudProvider)));
